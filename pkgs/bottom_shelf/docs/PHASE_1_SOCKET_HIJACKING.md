# Phase 1: Fix Socket Hijacking Data Loss

## Problem
When a handler calls `onHijack`, the current implementation provides a `StreamChannel` with an empty stream and doesn't cancel the server's own socket listener. Any data already read from the socket but not yet processed (in `currentData` or `bodyController`) is lost to the hijacker.

## Proposed Solution
1.  **Capture Subscription:** Store the `StreamSubscription<Uint8List>` in `_handleConnection` so it can be cancelled upon hijacking.
2.  **Preserve Buffered Data:**
    - Any data in `currentData` (from the current `socket.listen` event) must be prepended to the stream provided to the hijacker.
    - If a `bodyController` was active, its state must be accounted for (though typically hijacking happens for protocols like WebSocket where the body is the upgraded stream).
3.  **Correct StreamChannel:**
    - The stream side of the `StreamChannel` should consist of: `[bufferedData] + socket.stream`.
    - The sink side remains the `socket`.

## Plan
1.  **Modify `RawShelfServer._handleConnection`:**
    - Track `subscription` in a local variable.
    - Implement a `hijacked` flag to stop the server's processing loop.
2.  **Refine `onHijack` callback:**
    - Cancel `subscription`.
    - Create a new `Stream` that starts with `currentData` and continues with the raw `socket`.
    - Provide this new `StreamChannel` to the callback.
3.  **Update `FixedLengthBodyController`:** Ensure it can be cleanly detached if a hijack occurs during body streaming (though rare).

## Verification & Testing
1.  **Manual Test (WebSocket-like):**
    - Send a request with `Connection: Upgrade`.
    - Send some "extra" data immediately after the headers in the same TCP chunk.
    - Verify the hijacker receives the extra data.
2.  **Regression:** Ensure standard request/response flow is unaffected.

## Performance Considerations
- Use `StreamGroup` or `StreamController` to merge the buffered data and the socket stream efficiently.
- Ensure no unnecessary buffering of the socket stream.
