# Phase 3: Socket Fragmentation Test

## Problem
In standard operation, `RawShelfServer` and its underlying `RawHttpParser` read incoming HTTP requests from the socket in chunks (as determined by the OS and Dart's `Socket.listen`). However, networking conditions can cause data to be fragmented across multiple TCP packets. A robust parser must maintain state and correctly reconstruct the request even if it arrives one byte at a time.

## Proposed Solution
We need to introduce a "stress test" that artificially fragments a complete HTTP request (including headers and body) and feeds it to the server byte-by-byte. This will ensure that all state machines (`RawHttpParser`, `FixedLengthBodyController`, and `ChunkedBodyController`) handle fragmentation correctly without data loss or corruption.

## Plan
1.  **Add Byte-by-Byte Test:** In `test/protocol_test.dart` (or `test/robustness_test.dart`), create a test named `Socket fragmentation (1 byte chunks)`.
2.  **Implementation:**
    - Spin up the `RawShelfServer`.
    - Connect a `Socket`.
    - Create a realistic request payload (e.g., `POST` with headers, a small body, and chunked encoding).
    - Convert the payload to a `Uint8List`.
    - Loop over the `Uint8List` and call `socket.add([byte])` for each byte, optionally adding a tiny `Future.delayed(Duration.zero)` to ensure the event loop processes the chunks separately.
    - Verify that the server correctly parses the request, executes the handler, and returns a `200 OK`.
3.  **No Server Changes Expected:** Assuming the parsing logic was built correctly earlier in the roadmap, no changes to `RawShelfServer` should be required. This is purely a validation step.

## Verification
- Run `dart test test/robustness_test.dart` to verify the new test passes.