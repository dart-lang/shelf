# Compliance Test Summary

| Category | Count |
| --- | --- |
| Total | 215 |
| Passed | 155 |
| Failed | 21 |
| Warnings | 39 |
| Errors | 0 |
| Skipped | 0 |

## Failed or Warning Results

| ID | Category | Verdict | Description |
| --- | --- | --- | --- |
| CAP-ETAG-304 | Capabilities | Warn | ETag conditional GET returns 304 Not Modified |
| CAP-ETAG-IN-304 | Capabilities | Warn | 304 response includes ETag header |
| CAP-ETAG-WEAK | Capabilities | Warn | Weak ETag comparison for GET |
| CAP-INM-PRECEDENCE | Capabilities | Warn | If-None-Match takes precedence over If-Modified-Since |
| CAP-INM-UNQUOTED | Capabilities | Warn | If-None-Match with unquoted ETag |
| CAP-INM-WILDCARD | Capabilities | Warn | If-None-Match: * on existing resource returns 304 |
| CAP-LAST-MODIFIED-304 | Capabilities | Warn | Last-Modified conditional GET returns 304 Not Modified |
| COMP-405-ALLOW | Compliance | Warn | 405 response must include an Allow header |
| COMP-ACCEPT-NONSENSE | Compliance | Warn | Unrecognized Accept value — server may return 406 or default representation |
| COMP-CHUNKED-EXTENSION | Compliance | Fail | Chunk extension (valid per RFC) — server should accept or may reject |
| COMP-CHUNKED-NO-FINAL | Compliance | Fail | Chunked body without zero terminator — incomplete transfer |
| COMP-CONTENT-TYPE | Compliance | Warn | Response with content should include Content-Type header |
| COMP-DUPLICATE-CT | Compliance | Warn | Duplicate Content-Type headers with different values |
| COMP-EXPECT-UNKNOWN | Compliance | Warn | Unknown Expect value should be rejected with 417 |
| COMP-GET-WITH-CL-BODY | Compliance | Warn | GET with Content-Length and body — semantically unusual |
| COMP-HEAD-NO-BODY | Compliance | Fail | HEAD response must not contain a message body |
| COMP-HTTP10-NO-HOST | Compliance | Warn | HTTP/1.0 without Host header — valid per HTTP/1.0 |
| COMP-HTTP12-VERSION | Compliance | Warn | HTTP/1.2 — higher minor version should be accepted as HTTP/1.x compatible |
| COMP-METHOD-CASE | Compliance | Fail | Lowercase method 'get' — methods are case-sensitive per RFC |
| COMP-METHOD-TRACE | Compliance | Fail | TRACE request — should be disabled in production |
| COMP-NO-CL-IN-204 | Compliance | Warn | Server must not send Content-Length in a 204 response |
| COMP-OPTIONS-ALLOW | Compliance | Fail | OPTIONS response should include Allow header listing supported methods |
| COMP-OPTIONS-STAR | Compliance | Fail | OPTIONS * is the only valid asterisk-form request |
| COMP-POST-CL-UNDERSEND | Compliance | Fail | POST with Content-Length: 10 but only 5 bytes sent — incomplete body |
| COMP-TRACE-SENSITIVE | Compliance | Fail | TRACE should exclude sensitive headers from echoed response |
| COMP-TRACE-WITH-BODY | Compliance | Fail | TRACE with Content-Length body should be rejected |
| COMP-UNKNOWN-METHOD | Compliance | Fail | Unrecognized method should be rejected with 501 or 405 |
| MAL-CHUNK-EXT-64K | MalformedInput | Fail | 64KB chunk extension — tests extension length limits (CVE-2023-39326 class) |
| MAL-CL-TAB-BEFORE-VALUE | MalformedInput | Warn | Content-Length with tab as OWS — valid per RFC but unusual |
| MAL-POST-CL-HUGE-NO-BODY | MalformedInput | Fail | POST with Content-Length: 999999999 but no body — tests timeout vs memory allocation |
| MAL-RANGE-OVERLAPPING | MalformedInput | Warn | 1000 overlapping Range values — resource exhaustion vector (CVE-2011-3192 class) |
| MAL-URL-BACKSLASH | MalformedInput | Warn | Backslash in URL path — not valid URI character, some servers normalize to / |
| MAL-URL-PERCENT-CRLF | MalformedInput | Warn | Percent-encoded CRLF (%0d%0a) in URL — header injection if server decodes during parsing |
| MAL-URL-PERCENT-NULL | MalformedInput | Warn | Percent-encoded NUL byte (%00) in URL — security risk from null byte injection |
| NORM-UNDERSCORE-CL | Normalization | Warn | Underscore in Content-Length name — checks if server normalizes Content_Length to Content-Length |
| NORM-UNDERSCORE-TE | Normalization | Warn | Underscore in Transfer-Encoding name — checks if server normalizes Transfer_Encoding to Transfer-Encoding |
| SMUG-ABSOLUTE-URI-HOST-MISMATCH | Smuggling | Warn | Absolute-form URI with different Host header — routing confusion vector |
| SMUG-CHUNK-BARE-SEMICOLON | Smuggling | Fail | Chunk size with bare semicolon and no extension name must be rejected |
| SMUG-CHUNK-EXT-CR | Smuggling | Fail | Bare CR (not CRLF) in chunk extension — some parsers treat CR alone as line ending |
| SMUG-CHUNK-EXT-CTRL | Smuggling | Fail | NUL byte in chunk extension must be rejected |
| SMUG-CHUNK-EXT-INVALID-TOKEN | Smuggling | Fail | Chunk extension with invalid token character must be rejected |
| SMUG-CHUNK-EXT-LF | Smuggling | Fail | Bare LF in chunk extension — server MAY accept bare LF per RFC 9112 §2.2 |
| SMUG-CHUNK-LF-TRAILER | Smuggling | Warn | Bare LF in chunked trailer termination — server MAY accept bare LF per RFC 9112 §2.2 |
| SMUG-CL-DOUBLE-ZERO | Smuggling | Warn | Content-Length: 00 — matches 1*DIGIT but leading zero ambiguity |
| SMUG-CL-EXTRA-LEADING-SP | Smuggling | Warn | Content-Length with extra leading whitespace (double space OWS) |
| SMUG-CL-LEADING-ZEROS | Smuggling | Warn | Content-Length with leading zeros — valid per 1*DIGIT grammar but may cause parser disagreement |
| SMUG-CL-LEADING-ZEROS-OCTAL | Smuggling | Warn | Content-Length: 0200 — octal 128 vs decimal 200, parser disagreement vector |
| SMUG-CL-TRAILING-SPACE | Smuggling | Warn | Content-Length with trailing space — OWS trimming is valid per RFC 9110 §5.5 |
| SMUG-CL0-BODY-POISON | Smuggling | Warn | Content-Length: 0 with trailing bytes — checks if leftover bytes poison the next request |
| SMUG-EXPECT-100-CL | Smuggling | Warn | Expect: 100-continue with Content-Length — server should send 100 then read body |
| SMUG-HEAD-CL-BODY | Smuggling | Fail | HEAD request with Content-Length and body — server must not leave body on connection |
| SMUG-OPTIONS-CL-BODY | Smuggling | Fail | OPTIONS with Content-Length and body — server should consume or reject body |
| SMUG-OPTIONS-CL-BODY-DESYNC | Smuggling | Fail | OPTIONS with Content-Length body followed by a second request — detects unread-body desync |
| SMUG-TRAILER-AUTH | Smuggling | Warn | Authorization header in chunked trailers — prohibited per RFC 9110 §6.5.1 |
| SMUG-TRAILER-CL | Smuggling | Warn | Content-Length in chunked trailers must be ignored — prohibited trailer field |
| SMUG-TRAILER-CONTENT-TYPE | Smuggling | Warn | Content-Type in chunked trailer — prohibited per RFC 9110 §6.5.1 |
| SMUG-TRAILER-HOST | Smuggling | Warn | Host header in chunked trailers must not be used for routing |
| SMUG-TRAILER-TE | Smuggling | Warn | Transfer-Encoding in chunked trailers must be ignored — prohibited trailer field |
| SMUG-TRANSFER_ENCODING | Smuggling | Warn | Transfer_Encoding (underscore) header with CL — not a valid header but some parsers accept |
| WS-UPGRADE-INVALID-VER | WebSockets | Warn | WebSocket upgrade with unsupported version — should return 426 |
