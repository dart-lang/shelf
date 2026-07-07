# `bottom_shelf` Roadmap & Execution Plan

## CONTRACT FOR THE AGENT
1. Discuss the plan for each bullet before beginning.
2. Create a separate plan document for each roadmap bullet.
3. While implementing pay special attention to correctness and PERFORMANCE! Do not introduce accidental performance regressions. Consider adding a benchmark to validate before/after the change.
4. Make sure we have a plan to TEST each change (and double check that there isn't already a skipped test for the scenario).
5. Make sure that the entire `package:bottom_shelf` is formatted and analyzer clean and tests all pass before declaring completion.
6. When complete verify with the HUMAN that you are done and ask to delete the temporary sub-planning document and update the bullet below. (With any interesting implementation notes).

Benchmark discipline: measure with the harness described in
`docs/BENCHMARKS.md` (AOT, CPU-pinned, interleaved trials, external load
generator). Do not quote `benchmark/stress_tester.dart` numbers until it is
fixed (see Phase 6).

## Completed: Phases 1–4 (see git history for details)

- [x] **Phase 1 — Core correctness**: real request body streaming
      (`FixedLengthBodyController`), chunked response encoding, hijack data
      preservation, keep-alive body draining.
- [x] **Phase 2 — Protocol compliance & security (request side)**: NUL/CR/LF
      rejection in request URLs/methods/headers, CL+TE smuggling rejection,
      chunked-decoding state machine with trailers, IPv6 Host handling.
      *Note: this covered the request-parsing side only — see Phase 5 for the
      response-serialization side.*
- [x] **Phase 3 — Robustness & DoS**: slowloris header timeout,
      1-byte-fragmentation resilience.
- [x] **Phase 4 — Polish**: `package:logging` instead of `print`.

---

## Phase 5: Correctness & Security follow-ups
*From the 2026-07-06 hot-path review. These outrank all performance work.*

- [ ] **Cross-request header data leak via parser buffer reuse** (CRITICAL)
  - `HeaderByteSlice`s point into the reused parser buffer
    (`raw_http_parser.dart:35`); `_parser.reset()` runs right after the
    response is written (`http_connection.dart:447`) and the next request
    overwrites the buffer. A handler that retains the `Request` past response
    completion (post-response logging, `unawaited` analytics) and then lazily
    reads an un-hydrated header reads **another request's bytes**.
  - Fix direction: force-hydrate outstanding `LazyByteHeaderMap`s on reset,
    or poison the slices; add a test that retains a Request across a
    keep-alive boundary.
- [ ] **Response header injection / response splitting** (CRITICAL)
  - The serializer writes header names/values verbatim
    (`raw_shelf_response_serializer.dart:67`) with no CRLF or character
    validation. `shelf_io` inherits dart:io's `HttpHeaders` validation;
    `bottom_shelf` has none. A handler echoing untrusted input into any
    response header yields full response splitting on a keep-alive connection.
  - Natural home for the fix: the byte-oriented serializer rewrite (Phase 6),
    which must reject `\r`/`\n`/non-Latin-1 in names and values.
- [ ] **Response-side Content-Length vs body mismatch desync**
  - Nothing verifies streamed body length against the declared
    `Content-Length` (serializer). A mismatch shifts the framing of every
    subsequent response on the connection. Count bytes; destroy the
    connection on mismatch (dart:io behavior).
- [ ] **Interleaved error-bytes race**
  - If a handler responds before fully reading a malformed chunked body, the
    catch at `http_connection.dart:395` can splice a `400` into the middle of
    an in-flight response. Check whether a response write is in progress and
    destroy instead.
- [ ] **`Connection` header parsed as exact token, not a list**
  - `typed_headers.dart:38-47` matches `== 'close'` / `== 'keep-alive'`
    exactly; `Connection: close, foo` keeps the connection alive against
    RFC 9112 §9.6.
- [ ] **204/304 must not get `Transfer-Encoding: chunked`**
  - Serializer adds TE:chunked to unknown-length bodies regardless of status;
    204/304 must not carry a body or TE header.
- [ ] **Unread stream body leaks when handler sets `content-length: 0`**
  - The zero-length fast path never listens to or cancels a stream body.
    Resource leak only.
- [ ] **Method token not validated**
  - Parser accepts any bytes except NUL/CR/LF/SP in the method; `G@T /`
    reaches the handler. dart:io rejects. Low priority, spec laxity.

## Phase 6: Measured performance work
*Baseline (2026-07-06, see `docs/BENCHMARKS.md`): ~53k RPS vs shelf_io's
~15.6k (3.4x) and raw dart:io's ~18k (2.9x). Each item below: benchmark
before/after with the BENCHMARKS.md harness; ranked by expected impact.*

- [ ] **Kill the double `Uri.parse`** — `http_connection.dart:241,246`: the
      first parse is always thrown away for origin-form requests. Check
      `startsWith('/')` first; consider a small bounded `host+path → Uri`
      cache (immutable, safe to share; must cap size and key length).
- [ ] **Byte-oriented serializer rewrite** —
      `raw_shelf_response_serializer.dart:48-97`: const status-line bytes,
      ASCII scratch buffer instead of StringBuffer→toString→utf8.encode,
      capture content-length during the existing `headersAll` iteration
      instead of `response.contentLength` (which hydrates shelf's entire
      `singleValues` map per response), cache the Date header as bytes.
      **Must add header validation (Phase 5 item 2) as part of this.**
- [ ] **Fuse the ~8 per-request header scans into one pass** and replace
      `TypedHeaders._cache` (a per-request `Map`) with plain fields
      (`int? contentLength; bool isChunked; ...`). Security note: preserve
      duplicate-counting semantics exactly (all Content-Length occurrences,
      every TE header) — no first-match short-circuits.
- [ ] **Set `TCP_NODELAY` on accepted sockets** — one line, never set today;
      Nagle+delayed-ACK can dominate measured latency.
- [ ] **Parser: bulk `setRange` copy + line scanning** instead of
      byte-at-a-time state machine (`raw_http_parser.dart:63-209`). Highest
      CPU win, highest risk: every smuggling defense (bare-LF, CR-without-LF,
      obs-fold, whitespace-before-colon) must be re-proven. Do LAST, with the
      fuzz suite.
- [ ] **Micro-fixes** (each trivial): method match without sublistView
      (`raw_http_parser.dart:90`); const `'1.1'` version fast path (:129-138);
      static identity function (`typed_headers.dart:31`); skip empty
      `sublistView` (`http_connection.dart:257`); skip `await` when
      `bodyDone.isCompleted` (:450); cache `ErrorResponse.bytes`
      (`exceptions.dart:22`); cache `_HttpConnectionInfo` per connection
      (:368); index loop instead of `codeUnits.every` (:185).
- [ ] **Fix or replace `benchmark/stress_tester.dart`** — it counts socket
      data events as responses (:69) and divides by integer seconds (:52).
      Either parse responses properly or delete it in favor of the
      BENCHMARKS.md harness.
- [ ] **Header-slice object churn** — 3 objects per header line
      (`raw_http_parser.dart:166,199,200`); consider flattening slices into
      parallel int arrays. Measure first; pairs with the parser rewrite.

## Phase 7: API & compliance hygiene
*Carried over from the old TODO.md.*

- [ ] Figure out the library exports — should we just have a `serve` API and
      hide the `RawShelfServer` instance?
- [ ] Update the compliance exception bits to be explicit about HOW we expect
      to fail (document the decided failure mode, not just that we fail).
- [ ] Prune the skipped results out of the compliance results — too much
      noise.
- [ ] Revisit `COMP-POST-CL-UNDERSEND` failure vs body-timeout behavior
      (currently skipped: passing compliance breaks robustness tests that
      expect silent socket closure on timeout).

## Phase 8: `pkg:shelf` fast-path track (upstream)
*Changes to `pkgs/shelf` that remove the remaining adapter tax. All four ship
in a minor release (additive or semantics-only). Sequencing: prototype here
first (shelf is already a path dependency), measure with the BENCHMARKS.md
harness, then PR the internal fixes directly and open ONE design issue for
the additive API — with numbers, not estimates.*

- [ ] **Internal fixes, PR-able without an issue**: `contentLength`/`mimeType`
      via `headersAll` instead of hydrating `singleValues`
      (`headers.dart:15-19`); `change()` as a real field copy instead of
      re-validating through `Request._` (regression-test against
      dart-lang/shelf#142 and #12 edge cases); lazy `Request.url`;
      sync-preserving combinators (drop `Future.sync` wrapping in
      `createMiddleware`/`Pipeline`/`Cascade`; sync-throwing handlers then
      throw synchronously — combinators and adapters need try/catch, cf.
      dart-lang/shelf#33).
- [ ] **Additive adapter API (one design issue, after prototype)**:
      `Request.adapter(...)` trusted constructor (skips the
      `handlerPath + url == requestedUri.path` validation — but note
      dart-lang/shelf#369/#414: that check fires on CONNECT garbage, so
      shelf_io must sanitize request targets before adopting);
      `Body.bufferedBytes` for synchronous single-write responses; export
      `Headers` so `lazy_byte_header_map.dart` can drop its
      `package:shelf/src/` imports.
- [ ] **Deferred to a shelf major** (smallest wins, real breakage): context
      map retained by reference; `Stream<Uint8List>` as `read()`'s static
      type (runtime already emits `Uint8List` since shelf 1.1.1, cf.
      dart-lang/shelf#189).
- [ ] After anything ships: comment on dart-lang/shelf#451 with measured
      numbers.
