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
- [ ] **Request Smuggling Prevention**
  - *Source*: `test_complete_bottom_shelf.md` (Section 1.2)
  - *Goal*: Correctly handle or reject requests with both `Content-Length` and `Transfer-Encoding`.
- [ ] **Chunked Encoding Robustness**
  - *Source*: `test_complete_bottom_shelf.md` (Section 2.1)
  - *Goal*: Support chunk extensions and trailers if needed, and handle split chunks.
- [ ] **Host Header Validation**
  - *Source*: `test_complete_bottom_shelf.md` (Section 2.2)
  - *Goal*: Correctly parse IPv6 addresses in the `Host` header.

## Phase 3: Robustness & DoS Mitigation
*Focus: Stress testing and resource limits.*

- [ ] **Slowloris Mitigation**
  - *Source*: `test_complete_bottom_shelf.md` (Section 3.1)
  - *Goal*: Add timeouts for completing headers.
- [ ] **Socket Fragmentation Test**
  - *Source*: `test_complete_bottom_shelf.md` (Section 3.3)
  - *Goal*: Ensure the parser works when receiving data 1 byte at a time.

## Phase 4: Code Quality & Polish
*Focus: Library hygiene.*

- [ ] **Replace `print` with Logging**
  - *Source*: `review_review.md` (#5)
  - *Goal*: Use `package:logging` or a similar mechanism for error reporting.
