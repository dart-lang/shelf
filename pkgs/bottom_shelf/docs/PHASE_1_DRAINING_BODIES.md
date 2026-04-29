# Phase 1: Properly Drain Body Streams

## Problem
If an HTTP handler does not read the request body, the remaining body bytes stay in the socket/buffer, which interferes with the parsing of the next request in a keep-alive connection.

## Proposed Solution
1.  **Automatic Draining:**
    - After the handler completes and the response is serialized, the server must check if the request body was fully consumed.
    - If not, the server must consume and discard the remaining bytes before signaling readiness for the next request.
2.  **State Management:**
    - Update `RawShelfServer` to wait for the body to be "done" before completing the `readyForNextRequest` completer.
    - If the handler returns without reading the body, the server's own logic should continue to process incoming body chunks into a "black hole" until the `Content-Length` is reached.

## Plan
1.  **Modify `RawShelfServer._handleConnection`:**
    - Ensure that `readyForNextRequest.complete()` only happens AFTER both the response is sent AND the body is fully consumed (or drained).
    - If a handler finishes and `bodyController != null`, the server must continue to pump data through `bodyController` (which is already happening in the listener loop) until it finishes.
2.  **Ensure non-blocking:** The server should not block the response while draining the body, but it MUST block the *next* request.
3.  **Refine `FixedLengthBodyController`:** Ensure it doesn't buffer data if there are no listeners, or provide a way to "silently consume".

## Verification & Testing
1.  **Manual Test:**
    - Send Request A with a 100-byte body.
    - Handler for A returns "OK" without reading the body.
    - Send Request B on the same connection.
    - Verify Request B is received and handled correctly.

## Performance Considerations
- Draining involves reading bytes from the socket and discarding them. This is necessary for protocol correctness.
