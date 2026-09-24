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

- [x] **Cross-request header data leak via parser buffer reuse** (CRITICAL)
      — FIXED by poisoning. A `SliceBufferToken` is shared by all slices of
      one request and invalidated in `_parser.reset()`; `asString`/`matches`/
      `matchesKey` throw `StateError` if read afterwards, so a retained
      Request that lazily reads an un-hydrated header fails loudly instead of
      returning the next request's bytes. Chosen over force-hydration to keep
      the lazy-header fast path (no string allocation for un-read headers).
      Tests in `test/slice_invalidation_test.dart`. Throughput impact within
      noise (~1%).
- [x] **Response header injection / response splitting** (CRITICAL) — FIXED
      as part of the byte-oriented serializer rewrite: header names must be
      RFC 9110 tokens, values reject NUL/CR/LF and non-Latin-1; violations
      throw before any bytes reach the socket, so the connection error path
      returns a clean 500. Tests in
      `test/response_header_validation_test.dart`.
- [x] **Response-side Content-Length vs body mismatch desync**
  - Verified streamed body length against the declared `Content-Length` in
    `RawShelfResponseSerializer.writeResponse`. Throws `StateError` on
    mid-stream overflow (`bodyBytesWritten > contentLength`) or end-of-stream
    underflow (`bodyBytesWritten != contentLength`), which `_HttpConnection`
    catches and closes/destroys the socket (matching `dart:io` behavior).
- [x] **Interleaved error-bytes race**
  - Tracked `_responseWriting` (set right before `writeResponse`) and
    `_responseSent` (set via `onHeadersSent` as soon as response headers hit
    the socket, and reset when transitioning to the next keep-alive request).
    `_processData` only writes `400 Bad Request` error bytes if
    `!_responseWriting && !_responseSent`; otherwise it destroys the socket.
- [x] **`Connection` header parsed as exact token, not a list**
  - `HeaderByteSlice.scanConnectionToken` scans comma-separated tokens
    case-insensitively with OWS trimming (RFC 9110 §7.6.1) directly on the byte
    slice (zero String allocation), where `close` (`2`) always overrides
    `keep-alive` (`1`) across single or multiple `Connection` headers.
- [x] **204/304 must not get `Transfer-Encoding: chunked`**
  - `RawShelfResponseSerializer.writeResponse` treats `1xx`, `204`, and `304`
    as bodyless (`isChunked = !hasContentLength && !isBodylessStatus`), omits
    `Content-Length` on `1xx`/`204` (`COMP-NO-CL-IN-204`), and never emits
    `Transfer-Encoding: chunked` or `0\r\n\r\n`.
- [x] **Unread stream body leaks when handler sets `content-length: 0`**
  - `writeResponse` cancels `response.read().listen(null).cancel()` for `HEAD`,
    `contentLength == 0`, and bodyless statuses (`1xx`, `204`, `304`).
- [x] **Method token not validated**
  - `RawHttpParser` enforces `isTchar(byte)` on method bytes (RFC 9110 §9.1),
    rejects empty methods, enforces strict `HTTP/1.x` version grammar, trims
    both leading and trailing `SP`/`HTAB` OWS on header values, and rejects
    leading-zero multi-digit `Content-Length` values (`00`, `05`, `0200`).

- [x] **Unhandled peer reset on the response-write path crashes the isolate**
  - The read path guards resets (`start()`: `socket.listen(onError: _destroy)`),
    but the write path does not: `_flushCloseDestroy` calls
    `socket.flush().then(...)` with no `.catchError`. A client RST during the
    response flush/write surfaces as an unhandled
    `SocketException: Connection reset by peer (errno 104)` and — single
    isolate — takes the whole server down. Repro (via gcp-http-bench, real
    two-VM NIC): a wrk connection-count sweep sends an RST when it recycles the
    pool between steps, killing the server at `/plaintext` @ 16 conns; `ab -k`
    on loopback never hit it. Fix: catch ECONNRESET/EPIPE on flush/write/close
    and `_destroy()` that connection (dart:io `HttpServer` behavior), or route
    it through the existing `onConnectionError`/`onAsyncError` hooks so a benign
    disconnect is non-fatal by default.

## Phase 6: Measured performance work
*Baseline (2026-07-06, see `docs/BENCHMARKS.md`): ~53k RPS vs shelf_io's
~15.6k (3.4x) and raw dart:io's ~18k (2.9x). RE-RANKED 2026-07-07 by the
profiling investigation (`docs/PROFILE_2026_07.md`): ~60% of CPU is socket
syscalls (irreducible); the addressable wins are async/stream machinery and
string/map churn, NOT the parser (1.9% self time). Prototype patches with
measured deltas live in `docs/prototypes/`.*

- [x] **Byte-oriented serializer rewrite — measured +7.3% as prototype**:
      const status-line bytes, ASCII scratch buffer instead of
      StringBuffer→toString→utf8.encode, content-length captured during the
      existing `headersAll` iteration instead of `response.contentLength`
      (which hydrates shelf's entire `singleValues` map per response), Date
      header cached as bytes. Landed WITH header validation (Phase 5
      item 2). Re-measure with validation included.
- [x] **Drop the per-response `await socket.flush()` — measured +6%**:
      the flush added an event-loop round trip before the next pipelined
      request was accepted. Backpressure decision resolved with a byte-count
      guard: `writeResponse` returns bytes written, the connection
      accumulates them, and flushes only once `$Limit.flushThreshold`
      (256 KB) has queued — bounding a fast-handler/slow-client buffer to
      ~threshold + one response. Unflushed bytes are still delivered by the
      event loop (dart:io drains `socket.add` asynchronously); the guard
      only bounds memory. Landed.
- [x] **Fuse the ~8 per-request header scans into one pass — measured
      +2.9%**: single scan in the TypedHeaders constructor replaces
      separate walks + the per-request `_cache` map, using zero-allocation
      `HeaderByteSlice` byte methods (`parseContentLength`,
      `scanConnectionToken`, `containsTokenIgnoreCase`) instead of allocating
      temporary `String`/`.toLowerCase()` instances. Duplicate-counting
      semantics preserved (verified by smuggling/robustness tests). Landed.
- [x] **Set `TCP_NODELAY` on accepted sockets** — landed in `e7e8621`.
      No effect on loopback benchmarks; matters on real networks.
- [x] **Micro-fixes** (method byte-match including `HEAD` and `OPTIONS`,
      const '1.1'/'1.0', static identity fn, shared empty Uint8List, sync
      handler fast path, bodyDone.isCompleted, ErrorResponse.bytes cache,
      per-connection _HttpConnectionInfo, index loop for CL digits) — landed
      in `e7e8621` + Stage 2. *Measured: no RPS change, −3% GC scavenges.
      Kept on code-quality grounds.*
- [x] **Kill the double `Uri.parse`** — landed in `e7e8621` (origin-form
      fast path). *No measurable RPS effect on its own.* A bounded
      `host+path → Uri` cache remains unexplored.
- [x] **Routed-dispatch throughput gap vs raw dart:io — RESOLVED: it's
      `shelf_router`, not the adapter.** gcp-http-bench (two-VM NIC, single
      isolate, 5 interleaved trials, `c2d-standard-4`, COLLOCATED) measured
      bottom_shelf tying raw dart:io on `/plaintext`/`/json` at saturation
      (~22–23k RPS) but trailing on the routed `/user/<id>` (~19k vs ~22k, a
      repeatable ~15% gap, error bars non-overlapping from 8 connections up).
      Isolated 2026-07-11 with an in-process router micro-benchmark (no adapter,
      no sockets): shelf_router's PARAMETERIZED route costs +29% over its own
      STATIC route (6261 vs 4857 ns/op) and ~2x a hand-written manual dispatch
      (2982 ns/op) on the same `/user/42`. The adapter does identical work for
      `/json` and `/user/<id>` on one server, so a static→parameterized penalty
      can only come from the routing layer — bottom_shelf is not at fault (it
      still beats shelf_io ~1.7x on that endpoint; both pay the shelf_router
      tax). The cost is shelf_router's per-hit `RegExp.firstMatch` + params-map
      alloc + `request.change(context: {...})` (a fresh Request + merged context
      map on every routed request, static routes included) + dynamic handler
      invocation — an optimization target in `shelf_router`, outside
      bottom_shelf's scope. NB the absolute ~24k ceiling is still single-core
      and not yet proven server- vs client/NIC-bound. Data: gcp-http-bench
      `results/phase3-three-way.md`.
- [x] **Fix or replace `benchmark/stress_tester.dart`** — updated to parse
      complete HTTP responses (`\r\n\r\n` + `Content-Length`) before counting
      completions and divide by `stopwatch.elapsedMicroseconds / 1e6`, and
      aligned `benchmark/{raw_bench_server,shelf_io_bench_server,dart_io_bench_server}.dart`
      to serve `/`, `/plaintext`, `/json`, and `/user/<id>`.
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
