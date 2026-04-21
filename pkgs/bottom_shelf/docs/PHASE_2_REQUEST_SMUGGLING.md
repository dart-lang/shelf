# Phase 2: Request Smuggling Prevention

## Problem
HTTP Request Smuggling occurs when a proxy and a backend server disagree on where a request ends. This often happens when a request contains both a `Content-Length` header and a `Transfer-Encoding: chunked` header. If the proxy prioritizes one and the backend prioritizes the other, an attacker can append a malicious second request to the body of the first.

## Proposed Solution
According to RFC 9112 section 6.1:
> If a message is received with both a Transfer-Encoding and a Content-Length header field, the Transfer-Encoding overrides the Content-Length. Such a message might indicate an attempt to perform request smuggling (Section 11.2) or response splitting (Section 11.1) and ought to be handled as an error. A sender MUST remove the received Content-Length field prior to forwarding such a message downstream.

Because `bottom_shelf` is a backend server, the safest and most compliant approach is to **reject** requests containing both headers with a `400 Bad Request`.

## Plan
1.  **Analyze Header Slices:** After the headers have been fully parsed (in `RawShelfServer._handleConnection` or a helper), check if both `content-length` and `transfer-encoding` are present.
2.  **Implementation:**
    - To make this fast, we can add this check to `TypedHeaders` or do it directly in the parser.
    - Let's add a property to `TypedHeaders`, e.g., `bool get hasConflictingBodyHeaders`.
    - If `hasConflictingBodyHeaders` is true, immediately close the connection (or return a 400 Bad Request) and `break` the processing loop.
3.  **Support for Chunked Encoding (Requests):** Note that we *currently* do not support parsing `Transfer-Encoding: chunked` requests at all (it's marked as a skipped test). But, for *this* step, simply rejecting the conflicting headers is the priority. We will need to implement chunked request decoding to fully solve request handling, but that's a separate roadmap item.
    - Wait, the roadmap has "Chunked Encoding Robustness" as a separate item, but it specifically mentions "Support chunk extensions and trailers if needed, and handle split chunks". We do need basic chunked parsing.
    - For this specific bullet, let's implement the strict rejection.

## Verification & Testing
1.  **Add Test to `test/robustness_test.dart`:**
    - Send a request with both `Content-Length` and `Transfer-Encoding: chunked`.
    - Ensure the server responds with a 400 or forcefully closes the socket.

## Performance Considerations
- We already parse `TypedHeaders`. Checking for the presence of both headers can be done efficiently in that pass or by looking at the `_cache` if we compute it.