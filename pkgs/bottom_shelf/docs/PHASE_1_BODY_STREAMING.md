# Phase 1: Implement Real Body Streaming (Request)

## Problem
Currently, `RawShelfServer` only supports request bodies that fit within the same TCP chunk as the HTTP headers. It uses `Stream.value(remainingInChunk)` which fails for bodies spanning multiple chunks. Additionally, `FixedLengthBodyStream` is incomplete and doesn't correctly integrate with the server's socket listener loop.

## Proposed Solution
1.  **Introduce a `BodyManager` or similar abstraction:** This will handle the hand-off between the header parser and the body stream.
2.  **Refactor `RawShelfServer._handleConnection`:**
    - The main socket listener should remain the primary entry point.
    - When headers are complete, if `Content-Length > 0`, the listener should enter a "Body Mode".
    - In "Body Mode", incoming data chunks are pushed into a `StreamController` that powers the `shelf.Request` body.
    - The `BodyMode` must track `consumedBytes` and transition back to "Header Mode" once `Content-Length` is reached.
3.  **Support Pipelining:** If a chunk contains the end of a body and the start of a new request, it must be handled correctly.
4.  **Zero-Copy:** Use `Uint8List.sublistView` to avoid copying data from the socket buffers.

## Plan
1.  **Draft a new `BodyStreamController`:** A helper that manages the `StreamController` for the request body and signals when the body is complete.
2.  **Modify `RawShelfServer` state machine:**
    - Add a state to track whether we are currently streaming a body.
    - Update the `socket.listen` callback to dispatch data to either the parser or the body controller.
3.  **Correctly handle `Content-Length: 0`:** (No change needed, but verify).
4.  **Update `FixedLengthBodyStream` or replace it:** It likely needs to be a `StreamController` wrapper that the server pushes data into.

## Verification & Testing
1.  **Manual Test:** A test that sends a 1MB body in 1KB chunks.
2.  **Regression:** Ensure `protocol_test.dart` still passes.
3.  **Benchmark:** Measure throughput for large body uploads before and after.

## Performance Considerations
- Avoid creating new `Uint8List` objects; use `sublistView`.
- Ensure `StreamController` is created with `sync: true` if appropriate to reduce latency, but be careful with stack depth.
