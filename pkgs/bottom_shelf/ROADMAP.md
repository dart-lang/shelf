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

- [ ] **Implement Real Body Streaming (Request)**
  - *Source*: `todo.md` (Line 92), `review_review.md` (#1)
  - *Goal*: Support requests where the body spans multiple TCP chunks. Avoid `Stream.value` for the body.
- [ ] **Support Chunked Encoding for Responses**
  - *Source*: `todo.md` (Line 17), `review_review.md` (#2)
  - *Goal*: Avoid buffering the entire body to calculate `Content-Length`. Stream response bytes in chunks.
- [ ] **Fix Socket Hijacking Data Loss**
  - *Source*: `review_review.md` (#3)
  - *Goal*: Ensure any remaining data in the parser buffer is passed to the hijacked stream channel.
- [ ] **Properly Drain Body Streams**
  - *Source*: `review_review.md` (#4)
  - *Goal*: Ensure that if a handler doesn't consume the body, the server drains it automatically to allow the next request on a keep-alive connection.

## Phase 2: Protocol Compliance & Security
*Focus: Implement security fixes and protocol compliance rules derived from Dart SDK history and RFCs.*

- [ ] **Header Injection Sanitization**
  - *Source*: `test_complete_bottom_shelf.md` (Section 1.1)
  - *Goal*: Reject requests with invalid characters (NUL, LF, CR) in header values.
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
