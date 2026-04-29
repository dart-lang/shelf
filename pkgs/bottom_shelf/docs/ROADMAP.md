# `bottom_shelf` Roadmap & Execution Plan

## CONTRACT FOR THE AGENT
1. Discuss the plan for each bullet before beginning.
2. Create a separate plan document for each roadmap bullet.
3. While implementing pay special attention to correctness and PERFORMANCE! Do not introduce accidental performance regressions. Consider adding a benchmark to validate before/after the change.
4. Make sure we have a plan to TEST each change (and double check that there isn't already a skipped test for the scenario).
5. Make sure that the entire `package:bottom_shelf` is formatted and analyzer clean and tests all pass before declaring completion.
6. When complete verify with the HUMAN that you are done and ask to delete the temporary sub-planning document and update the bullet below. (With any interesting implementation notes).

This document consolidates the tasks and goals identified in `todo.md`, `review_review.md`, and `test_complete_bottom_shelf.md` into a cohesive execution plan.

## Phase 1: Core Correctness & Review Feedback
*Focus: Fix the fundamental issues identified in the code review and basic tests.*

- [x] **Implement Real Body Streaming (Request)**
  - *Status*: Complete.
  - *Implementation Notes*: Replaced `Stream.value` with `FixedLengthBodyController` to support multi-chunk request bodies. Refactored `RawShelfServer` to include a state-driven loop that transitions between header parsing and body streaming.
  - *Verification*: Added a 1MB stress test in `test/body_test.dart` and verified throughput of ~222 MB/s with `benchmark/body_streaming_bench.dart`.
- [x] **Support Chunked Encoding for Responses**
  - *Status*: Complete.
  - *Implementation Notes*: `RawShelfResponseSerializer` now uses `await for` to stream response chunks. It automatically adds `Transfer-Encoding: chunked` if the content length is unknown, avoiding full body buffering.
  - *Verification*: Added `Chunked response encoding` and `Fixed-length response encoding` tests to `test/protocol_test.dart`.
- [x] **Fix Socket Hijacking Data Loss**
  - *Status*: Complete.
  - *Implementation Notes*: Implemented a `hijackController` to manually proxy socket events to the hijacked channel. This ensures that any data already in the parser buffer or arriving during the hijack is preserved.
  - *Verification*: Added `Hijacking with buffered data` test to `test/connection_test.dart`.
- [x] **Properly Drain Body Streams**
  - *Status*: Complete.
  - *Implementation Notes*: Added logic to `RawShelfServer` to ensure `readyForNextRequest` only completes after the request body has been fully consumed or drained. `FixedLengthBodyController` handles silent draining if the handler ignores the body.
  - *Verification*: Added `Large unconsumed body in keep-alive` test to `test/body_test.dart`.

## Phase 2: Protocol Compliance & Security
*Focus: Implement security fixes and protocol compliance rules derived from Dart SDK history and RFCs.*

- [x] **Header Injection Sanitization**
  - *Status*: Complete.
  - *Implementation Notes*: Added strict validation to `RawHttpParser` to reject NUL, CR, and LF in URLs, methods, and header keys/values (per RFC 9112 and SDK Issue 56636). Hardened `RawShelfServer` error handling to ensure clean socket destruction on parser errors.
  - *Verification*: Added `NUL in headers` and updated `Malformed request` tests in `test/robustness_test.dart`.
- [x] **Request Smuggling Prevention**
  - *Status*: Complete.
  - *Implementation Notes*: Added `hasConflictingBodyHeaders` to `TypedHeaders` to check for the presence of both `Content-Length` and `Transfer-Encoding`. If both are present, `RawShelfServer` rejects the request with a 400 Bad Request and immediately destroys the socket (RFC 9112 section 6.1).
  - *Verification*: Added `Conflicting body headers (Request Smuggling Prevention)` test to `test/robustness_test.dart`.
- [x] **Chunked Encoding Robustness**
  - *Status*: Complete.
  - *Implementation Notes*: Implemented `ChunkedBodyController` containing a state machine that robustly decodes HTTP chunked body encoding (RFC 9112) including hex sizes, chunk data, and trailing headers. Integrated this into `RawShelfServer` by checking `TypedHeaders.isChunked`. Added `takeBufferedData` to seamlessly support `hijack` even when chunks are parsed.
  - *Verification*: Enabled `chunked requests are un-chunked` test in `test/shelf_compliance_test.dart` and added `Split chunked request encoding` test to `test/protocol_test.dart`.
- [x] **Host Header Validation**
  - *Status*: Complete.
  - *Implementation Notes*: Verified that `Uri.parse` seamlessly handles IPv6 format in the `Host` header (e.g. `[::1]:8080`). No implementation changes were required in `RawShelfServer`.
  - *Verification*: Added `Request with IPv6 Host header` test to `test/protocol_test.dart` to lock in this behavior.

## Phase 3: Robustness & DoS Mitigation
*Focus: Stress testing and resource limits.*

- [x] **Slowloris Mitigation**
  - *Status*: Complete.
  - *Implementation Notes*: Added `headerTimeout` to `RawShelfServer.serve()`. A `Timer` is started on connection and restarted between keep-alive requests. If headers aren't fully parsed within the duration, the server immediately destroys the socket.
  - *Verification*: Added `Slowloris Mitigation (Header Timeout)` test to `test/robustness_test.dart`.
- [x] **Socket Fragmentation Test**
  - *Status*: Complete.
  - *Implementation Notes*: Successfully verified that the internal state machines (`RawHttpParser`, `ChunkedBodyController`, `FixedLengthBodyController`) correctly process highly fragmented network traffic. The server successfully decodes chunked requests arriving 1 byte at a time.
  - *Verification*: Added `Socket fragmentation (1 byte chunks)` test to `test/robustness_test.dart`.

## Phase 4: Code Quality & Polish
*Focus: Library hygiene.*

- [x] **Replace `print` with Logging**
  - *Status*: Complete.
  - *Implementation Notes*: Added `package:logging` dependency. Replaced raw `print` statements in `RawShelfServer`'s error handlers with `Logger('bottom_shelf.RawShelfServer').severe()`. This prevents standard output pollution and allows consumers to configure or filter internal server logs.
  - *Verification*: Updated `RawShelfServer error in handler leads to socket destruction` in `test/bottom_shelf_test.dart` to assert against `Logger.root` records instead of stdout prints.
