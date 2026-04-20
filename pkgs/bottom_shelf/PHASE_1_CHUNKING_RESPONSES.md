# Phase 1: Support Chunked Encoding for Responses

## Problem
Currently, `RawShelfResponseSerializer` buffers the entire response body to calculate the `Content-Length`. This is highly inefficient for large responses and defeats the purpose of a streaming HTTP server.

## Proposed Solution
1.  **Introduce Chunked Support:**
    - If `response.contentLength` is `null`, and no `content-length` header is provided by the handler, use `Transfer-Encoding: chunked`.
    - Stream chunks as they arrive from `response.read()`.
2.  **Streaming Strategy:**
    - Write the status line and headers first.
    - If chunked, wrap each chunk in HTTP chunk framing: `<hex-size>\r\n<data>\r\n`.
    - End with a final `0\r\n\r\n` chunk.
3.  **Correct Content-Length:** If `response.contentLength` *is* provided, use it and stream the body normally without chunked encoding.

## Plan
1.  **Draft the new streaming logic in `writeResponse`:**
    - Branch based on whether `Content-Length` is known.
    - Implement a `_writeChunked` helper.
    - Ensure `socket.flush()` is called appropriately.
2.  **Handle Status Phrases:** (Optional but good for compliance) Use a more robust status phrase mapping or default to "OK".
3.  **Zero-Copy:** Reuse byte buffers where possible.
4.  **Refactor `writeResponse`:** Move from `await response.read().toList()` to `await for (var chunk in response.read())`.

## Verification & Testing
1.  **Manual Test:** A test where a handler returns a `Stream` of data without a `contentLength`.
2.  **Verify Headers:** Ensure `Transfer-Encoding: chunked` is added when `Content-Length` is missing.
3.  **Integration Test:** Ensure `dart:io` HttpClient can correctly parse the chunked responses from `bottom_shelf`.

## Performance Considerations
- Chunked encoding adds a small overhead (hex size and CRLFs).
- Avoid `utf8.encode` in the tight loop; pre-calculate static parts if possible.
