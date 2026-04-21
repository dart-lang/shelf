# Phase 2: Chunked Encoding Robustness

## Problem
Currently, `RawShelfServer` only supports request bodies that have a known `Content-Length`. If a client sends a request with `Transfer-Encoding: chunked` (and no `Content-Length`, since we now reject requests with both), the server treats the body as empty. The actual chunked body data remains on the socket, which will corrupt the next request in a keep-alive connection, and the handler doesn't get the body data.

## Proposed Solution
Implement a state-machine based `ChunkedDecoder` that processes incoming byte chunks according to RFC 9112 section 7.1.

1.  **State Machine:** The decoder needs to handle:
    - Chunk Size (hexadecimal string)
    - Chunk Extensions (can be ignored/discarded for now)
    - Chunk Data (exactly 'chunk size' bytes)
    - Chunk CRLF (after data)
    - Trailers (can be ignored, just read until final CRLF)
2.  **`ChunkedBodyController`:** Similar to `FixedLengthBodyController`, this class will wrap a `StreamController<Uint8List>` and use the state machine to decode chunks. It will push decoded body data to the stream.
3.  **Integration:** In `RawShelfServer._handleConnection`:
    - Add `bool get isChunked` to `TypedHeaders`.
    - If `typedHeaders.isChunked`, create a `ChunkedBodyController` instead of `FixedLengthBodyController`.
    - Route incoming socket data through this controller until `isDone` is true.

## Plan
1.  **Update `TypedHeaders`:**
    - Add `bool get isChunked` that returns `true` if `Transfer-Encoding` contains `chunked`.
2.  **Create `ChunkedBodyController` in `lib/src/body_stream.dart`:**
    - Implement the chunked parsing logic.
    - Return any remaining data (pipelined next request) when the final `0\r\n\r\n` is encountered.
    - Call `_onDone()` when finished.
3.  **Update `RawShelfServer`:**
    - Wire up the new controller if `isChunked` is true.
4.  **Testing:**
    - Enable the skipped `'chunked requests are un-chunked'` test in `test/shelf_compliance_test.dart`.
    - Add specific split-chunk tests to `test/protocol_test.dart` to ensure robustness when chunk boundaries don't align with TCP packet boundaries.

## Performance Considerations
- The `ChunkedDecoder` should parse the hex size without allocating Strings if possible (parse bytes directly).
- It should use `Uint8List.sublistView` to yield body data without copying.