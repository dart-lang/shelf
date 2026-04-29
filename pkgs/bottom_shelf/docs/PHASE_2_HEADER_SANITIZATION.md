# Phase 2: Header Injection Sanitization

## Problem
Allowing control characters like NUL, LF, or CR in HTTP header values can lead to header splitting attacks, request smuggling, and log injection.

## Proposed Solution
1.  **Strict Validation:**
    - The `RawHttpParser` must validate every byte of a header value.
    - If `0x00` (NUL), `0x0A` (LF), or `0x0D` (CR) is encountered during parsing of a header value (before the actual end of headers), the parser must throw an error.
2.  **Implementation:**
    - Update `RawHttpParser.process` in the `_stateHeaderValue` case.
    - Add a check within the loop that identifies the end of the header value.

## Plan
1.  **Modify `RawHttpParser.process`:**
    - Within `case _stateHeaderValue:`, before the final processing of the chunk, scan the bytes for `0x00`. (LF and CR are already used as delimiters, but we must ensure they aren't escaped or misused if we ever support folded headers).
    - Actually, `RawHttpParser` handles `charLf` as the state transition. We need to ensure no OTHER `charLf` or `charCr` or `0` appears before that.
2.  **Add `HttpException` or similar error:** Ensure the server handles this by closing the connection.

## Verification & Testing
1.  **Manual Test:**
    - Send `X-Injected: Value\x00Injection\r\n`.
    - Send `X-Injected: Value\nInjected\r\n`.
    - Verify the server rejects these.

## Performance Considerations
- This adds one comparison per byte in the header value. This is a necessary cost for security.
