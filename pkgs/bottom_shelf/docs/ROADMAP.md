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
~15.6k (3.4x) and raw dart:io's ~18k (2.9x). RE-RANKED 2026-07-07 by the
profiling investigation (`docs/PROFILE_2026_07.md`): ~60% of CPU is socket
syscalls (irreducible); the addressable wins are async/stream machinery and
string/map churn, NOT the parser (1.9% self time). Prototype patches with
measured deltas live in `docs/prototypes/`.*

- [ ] **Byte-oriented serializer rewrite — measured +7.3%**
      (`docs/prototypes/p1_serializer.patch`): const status-line bytes,
      ASCII scratch buffer instead of StringBuffer→toString→utf8.encode,
      capture content-length during the existing `headersAll` iteration
      instead of `response.contentLength` (which hydrates shelf's entire
      `singleValues` map per response), cache the Date header as bytes.
      **Productionize together with response-header validation (Phase 5
      item 2)** — the byte writer is the right place for it; re-measure
      with validation included.
- [ ] **Drop/rework the per-response `await socket.flush()` — measured
      +5.6%** (`docs/prototypes/p3_noflush.patch`): the flush adds an
      event-loop round trip before the next pipelined request is accepted.
      BLOCKED on a backpressure decision: without it a slow client + fast
      handler can grow the socket buffer unboundedly (flush every N
      responses? byte-count guard in the connection?).
- [ ] **Fuse the ~8 per-request header scans into one pass — measured
      +2.9%** (`docs/prototypes/p2_fusedscan.patch`): single scan in the
      TypedHeaders constructor replaces separate walks + the per-request
      `_cache` map. Duplicate-counting semantics preserved (verified by
      smuggling/robustness tests). Safe to land as-is.
- [x] **Set `TCP_NODELAY` on accepted sockets** — landed in `e7e8621`.
      No effect on loopback benchmarks; matters on real networks.
- [x] **Micro-fixes** (method byte-match, const '1.1', static identity fn,
      shared empty Uint8List, sync handler fast path, bodyDone.isCompleted,
      ErrorResponse.bytes cache, per-connection _HttpConnectionInfo, index
      loop for CL digits) — landed in `e7e8621`. *Measured: no RPS change,
      −3% GC scavenges. Kept on code-quality grounds.*
- [x] **Kill the double `Uri.parse`** — landed in `e7e8621` (origin-form
      fast path). *No measurable RPS effect on its own.* A bounded
      `host+path → Uri` cache remains unexplored.
- [ ] **Fix or replace `benchmark/stress_tester.dart`** — it counts socket
      data events as responses (:69) and divides by integer seconds (:52).
      Either parse responses properly or delete it in favor of the
      BENCHMARKS.md harness.
- [ ] **DEMOTED: parser bulk-copy/line-scan rewrite and header-slice
      flattening** — the profile shows `RawHttpParser.process` at only
      ~1.9% self time; the theoretical win cannot exceed that. Highest
      risk (smuggling defenses must be re-proven), lowest measured
      opportunity. Only revisit after everything above lands.

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

*2026-07-07: THE NUMBERS EXIST — see `docs/PROFILE_2026_07.md`. Measured on
this branch: request-side changes (lazy url/handlerPath, no constructor
validation, no context copy; `docs/prototypes/p4_shelf_request.patch`)
**+4.4%**; `Body.bufferedBytes` sync path
(`docs/prototypes/p5_syncbody.patch`) **+10.2%**; combined **+14.6%** on
top of bottom_shelf's own wins. Key design lesson from the P4 prototype's
one failing test: shelf's constructor validation is load-bearing for
malformed percent-encoding (the dart-lang/shelf#369 class) — a trusted
`Request.adapter` requires the adapter to own that rejection, e.g. by
mapping `FormatException` to 400 at dispatch (free on the happy path).*

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
