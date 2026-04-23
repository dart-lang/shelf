# Compliance Test Summary

| Category | Count |
| --- | --- |
| Total | 215 |
| Passed | 101 |
| Failed | 56 |
| Warnings | 58 |
| Errors | 0 |

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
| COMP-ASTERISK-WITH-GET | Compliance | Fail | Asterisk-form (*) request-target with GET must be rejected |
| COMP-CHUNKED-NO-FINAL | Compliance | Fail | Chunked body without zero terminator — incomplete transfer |
| COMP-CHUNKED-TRAILER-VALID | Compliance | Fail | Valid chunked body with trailer field should be accepted |
| COMP-DUPLICATE-CT | Compliance | Warn | Duplicate Content-Type headers with different values |
| COMP-DUPLICATE-HOST-SAME | Compliance | Fail | Duplicate Host headers with identical values must be rejected |
| COMP-EXPECT-UNKNOWN | Compliance | Warn | Unknown Expect value should be rejected with 417 |
| COMP-GET-WITH-CL-BODY | Compliance | Warn | GET with Content-Length and body — semantically unusual |
| COMP-HEAD-NO-BODY | Compliance | Fail | HEAD response must not contain a message body |
| COMP-HOST-EMPTY-VALUE | Compliance | Fail | Empty Host header value must be rejected |
| COMP-HOST-WITH-PATH | Compliance | Fail | Host header with path component must be rejected |
| COMP-HOST-WITH-USERINFO | Compliance | Fail | Host header with userinfo (user@host) must be rejected |
| COMP-HTTP10-NO-HOST | Compliance | Warn | HTTP/1.0 without Host header — valid per HTTP/1.0 |
| COMP-LEADING-CRLF | Compliance | Warn | Leading CRLF before request-line — server may ignore per RFC |
| COMP-METHOD-CASE | Compliance | Fail | Lowercase method 'get' — methods are case-sensitive per RFC |
| COMP-METHOD-TRACE | Compliance | Fail | TRACE request — should be disabled in production |
| COMP-NO-CL-IN-204 | Compliance | Warn | Server must not send Content-Length in a 204 response |
| COMP-OPTIONS-ALLOW | Compliance | Fail | OPTIONS response should include Allow header listing supported methods |
| COMP-OPTIONS-STAR | Compliance | Fail | OPTIONS * is the only valid asterisk-form request |
| COMP-POST-CL-UNDERSEND | Compliance | Fail | POST with Content-Length: 10 but only 5 bytes sent — incomplete body |
| COMP-REQUEST-LINE-TAB | Compliance | Warn | Tab as request-line delimiter — SHOULD reject but MAY parse on whitespace |
| COMP-SPACE-IN-TARGET | Compliance | Warn | Whitespace inside request-target is invalid |
| COMP-TRACE-SENSITIVE | Compliance | Fail | TRACE should exclude sensitive headers from echoed response |
| COMP-TRACE-WITH-BODY | Compliance | Fail | TRACE with Content-Length body should be rejected |
| COMP-UNKNOWN-METHOD | Compliance | Fail | Unrecognized method should be rejected with 501 or 405 |
| COMP-UNKNOWN-TE-501 | Compliance | Fail | Unknown Transfer-Encoding without CL should be rejected with 501 |
| COMP-VERSION-CASE | Compliance | Warn | HTTP version is case-sensitive — lowercase 'http' must be rejected |
| COMP-VERSION-LEADING-ZEROS | Compliance | Warn | HTTP/01.01 — leading zeros in version digits are invalid |
| COMP-VERSION-MISSING-MINOR | Compliance | Warn | HTTP/1 with no minor version digit is invalid |
| COMP-VERSION-WHITESPACE | Compliance | Warn | HTTP/ 1.1 — whitespace inside version token is invalid |
| COOK-CONTROL-CHARS | Cookies | Fail | Control characters (0x01-0x03) in cookie value — dangerous if preserved |
| MAL-CHUNK-EXT-64K | MalformedInput | Warn | 64KB chunk extension — tests extension length limits (CVE-2023-39326 class) |
| MAL-CL-TAB-BEFORE-VALUE | MalformedInput | Warn | Content-Length with tab as OWS — valid per RFC but unusual |
| MAL-CONTROL-CHARS-HEADER | MalformedInput | Fail | Control characters in header value should be rejected |
| MAL-LONG-HEADER-NAME | MalformedInput | Fail | 100KB header name should be rejected with 400/431 |
| MAL-LONG-HEADER-VALUE | MalformedInput | Fail | 100KB header value should be rejected with 431 |
| MAL-LONG-METHOD | MalformedInput | Fail | 100KB method name should be rejected |
| MAL-LONG-URL | MalformedInput | Fail | 100KB URL should be rejected with 414 URI Too Long |
| MAL-MANY-HEADERS | MalformedInput | Fail | 10,000 headers should be rejected with 431 |
| MAL-NON-ASCII-URL | MalformedInput | Fail | Non-ASCII bytes (UTF-8 é) in URL must be rejected |
| MAL-NUL-IN-URL | MalformedInput | Fail | NUL byte in URL should be rejected |
| MAL-RANGE-OVERLAPPING | MalformedInput | Warn | 1000 overlapping Range values — resource exhaustion vector (CVE-2011-3192 class) |
| MAL-URL-BACKSLASH | MalformedInput | Warn | Backslash in URL path — not valid URI character, some servers normalize to / |
| MAL-URL-OVERLONG-UTF8 | MalformedInput | Fail | Overlong UTF-8 encoding of / (0xC0 0xAF) in URL must be rejected |
| MAL-URL-PERCENT-CRLF | MalformedInput | Warn | Percent-encoded CRLF (%0d%0a) in URL — header injection if server decodes during parsing |
| MAL-URL-PERCENT-NULL | MalformedInput | Warn | Percent-encoded NUL byte (%00) in URL — security risk from null byte injection |
| NORM-UNDERSCORE-CL | Normalization | Warn | Underscore in Content-Length name — checks if server normalizes Content_Length to Content-Length |
| NORM-UNDERSCORE-TE | Normalization | Warn | Underscore in Transfer-Encoding name — checks if server normalizes Transfer_Encoding to Transfer-Encoding |
| RFC9110-5.4-DUPLICATE-HOST | Compliance | Fail | Duplicate Host headers with different values must be rejected |
| RFC9110-5.6.2-SP-BEFORE-COLON | Compliance | Fail | Whitespace between header name and colon must be rejected |
| RFC9112-2.2-BARE-LF-HEADER | Compliance | Warn | Bare LF in header should be rejected, but MAY be accepted |
| RFC9112-2.2-BARE-LF-REQUEST-LINE | Compliance | Warn | Bare LF in request line should be rejected, but MAY be accepted |
| RFC9112-2.3-INVALID-VERSION | Compliance | Warn | Invalid HTTP version must be rejected |
| RFC9112-3-CR-ONLY-LINE-ENDING | Compliance | Warn | CR without LF as line ending must be rejected |
| RFC9112-3-MISSING-TARGET | Compliance | Warn | Request line with no target (space but no path) must be rejected |
| RFC9112-3-MULTI-SP-REQUEST-LINE | Compliance | Warn | Multiple spaces between request-line components — SHOULD reject but MAY parse leniently |
| RFC9112-5.1-OBS-FOLD | Compliance | Fail | Obs-fold (line folding) in headers should be rejected |
| RFC9112-7.1-MISSING-HOST | Compliance | Fail | Request without Host header must be rejected with 400 |
| SMUG-ABSOLUTE-URI-HOST-MISMATCH | Smuggling | Warn | Absolute-form URI with different Host header — routing confusion vector |
| SMUG-CHUNK-BARE-SEMICOLON | Smuggling | Fail | Chunk size with bare semicolon and no extension name must be rejected |
| SMUG-CHUNK-EXT-CTRL | Smuggling | Fail | NUL byte in chunk extension must be rejected |
| SMUG-CHUNK-EXT-INVALID-TOKEN | Smuggling | Fail | Chunk extension with invalid token character must be rejected |
| SMUG-CHUNK-EXT-LF | Smuggling | Warn | Bare LF in chunk extension — server MAY accept bare LF per RFC 9112 §2.2 |
| SMUG-CHUNK-LF-TERM | Smuggling | Warn | Bare LF as chunk data terminator — server MAY accept bare LF per RFC 9112 §2.2 |
| SMUG-CHUNK-LF-TRAILER | Smuggling | Warn | Bare LF in chunked trailer termination — server MAY accept bare LF per RFC 9112 §2.2 |
| SMUG-CHUNK-MISSING-TRAILING-CRLF | Smuggling | Fail | Chunk data without trailing CRLF must be rejected |
| SMUG-CHUNK-SPILL | Smuggling | Fail | Chunk declares size 5 but sends 7 bytes — oversized chunk data must be rejected |
| SMUG-CHUNKED-WITH-PARAMS | Smuggling | Warn | Transfer-Encoding: chunked;ext=val — parameters on chunked encoding |
| SMUG-CL-DOUBLE-ZERO | Smuggling | Warn | Content-Length: 00 — matches 1*DIGIT but leading zero ambiguity |
| SMUG-CL-EXTRA-LEADING-SP | Smuggling | Warn | Content-Length with extra leading whitespace (double space OWS) |
| SMUG-CL-LEADING-ZEROS | Smuggling | Warn | Content-Length with leading zeros — valid per 1*DIGIT grammar but may cause parser disagreement |
| SMUG-CL-LEADING-ZEROS-OCTAL | Smuggling | Warn | Content-Length: 0200 — octal 128 vs decimal 200, parser disagreement vector |
| SMUG-CL-TE-BOTH | Smuggling | Warn | Both Content-Length and Transfer-Encoding present — server MAY reject or process with TE alone |
| SMUG-CL-TRAILING-SPACE | Smuggling | Warn | Content-Length with trailing space — OWS trimming is valid per RFC 9110 §5.5 |
| SMUG-CL0-BODY-POISON | Smuggling | Warn | Content-Length: 0 with trailing bytes — checks if leftover bytes poison the next request |
| SMUG-CLTE-CONN-CLOSE | Smuggling | Fail | CL+TE conflict — server MUST close connection after responding |
| SMUG-CLTE-DESYNC | Smuggling | Fail | CL.TE desync — leftover bytes after the body boundary may be interpreted as the next request |
| SMUG-CLTE-PIPELINE | Smuggling | Warn | CL.TE conflict — both Content-Length and Transfer-Encoding: chunked present |
| SMUG-CLTE-SMUGGLED-GET | Smuggling | Fail | CL.TE desync — embedded GET in body; multiple responses indicate request boundary confusion |
| SMUG-CLTE-SMUGGLED-GET-TE-CASE-MISMATCH | Smuggling | Fail | CL.TE desync with TE case mismatch — multiple responses indicate request boundary confusion |
| SMUG-CLTE-SMUGGLED-GET-TE-LEADING-COMMA | Smuggling | Fail | CL.TE desync with TE leading comma — multiple responses indicate request boundary confusion |
| SMUG-CLTE-SMUGGLED-GET-TE-OBS-FOLD | Smuggling | Fail | CL.TE desync with obs-folded Transfer-Encoding — multiple responses indicate request boundary confusion |
| SMUG-CLTE-SMUGGLED-GET-TE-TRAILING-SPACE | Smuggling | Fail | CL.TE desync with TE trailing space — multiple responses indicate request boundary confusion |
| SMUG-CLTE-SMUGGLED-HEAD | Smuggling | Fail | CL.TE desync — embedded HEAD in body; multiple responses indicate request boundary confusion |
| SMUG-EXPECT-100-CL | Smuggling | Warn | Expect: 100-continue with Content-Length — server should send 100 then read body |
| SMUG-GET-CL-PREFIX-DESYNC | Smuggling | Warn | GET with Content-Length body containing an incomplete request prefix — follow-up completes it if body was left unread |
| SMUG-HEAD-CL-BODY | Smuggling | Fail | HEAD request with Content-Length and body — server must not leave body on connection |
| SMUG-MULTIPLE-HOST-COMMA | Smuggling | Fail | Host header with comma-separated values must be rejected |
| SMUG-OPTIONS-CL-BODY | Smuggling | Fail | OPTIONS with Content-Length and body — server should consume or reject body |
| SMUG-OPTIONS-CL-BODY-DESYNC | Smuggling | Fail | OPTIONS with Content-Length body followed by a second request — detects unread-body desync |
| SMUG-TE-DUPLICATE-HEADERS-SMUGGLED-GET | Smuggling | Fail | TE.TE + CL ambiguity with embedded GET — multiple responses indicate request boundary confusion |
| SMUG-TE-EMPTY-VALUE | Smuggling | Fail | Transfer-Encoding with empty value must be rejected |
| SMUG-TE-IDENTITY | Smuggling | Fail | Transfer-Encoding: identity (deprecated) with CL must be rejected |
| SMUG-TE-NOT-FINAL-CHUNKED | Smuggling | Fail | Transfer-Encoding where chunked is not final — server MUST respond with 400 (RFC 9112 §6.3) |
| SMUG-TE-XCHUNKED | Smuggling | Fail | Transfer-Encoding: xchunked must not be treated as chunked |
| SMUG-TECL-CONN-CLOSE | Smuggling | Fail | TE+CL conflict (reversed order) — server MUST close connection after responding |
| SMUG-TECL-DESYNC | Smuggling | Fail | TE.CL desync — chunked terminator before CL boundary, leftover bytes smuggled |
| SMUG-TECL-PIPELINE | Smuggling | Warn | TE.CL conflict — Transfer-Encoding: chunked + conflicting Content-Length |
| SMUG-TECL-SMUGGLED-GET | Smuggling | Fail | TE.CL desync via chunk-size prefix trick — multiple responses indicate request boundary confusion |
| SMUG-TRAILER-AUTH | Smuggling | Warn | Authorization header in chunked trailers — prohibited per RFC 9110 §6.5.1 |
| SMUG-TRAILER-CL | Smuggling | Warn | Content-Length in chunked trailers must be ignored — prohibited trailer field |
| SMUG-TRAILER-CONTENT-TYPE | Smuggling | Warn | Content-Type in chunked trailer — prohibited per RFC 9110 §6.5.1 |
| SMUG-TRAILER-HOST | Smuggling | Warn | Host header in chunked trailers must not be used for routing |
| SMUG-TRAILER-TE | Smuggling | Warn | Transfer-Encoding in chunked trailers must be ignored — prohibited trailer field |
| SMUG-TRANSFER_ENCODING | Smuggling | Warn | Transfer_Encoding (underscore) header with CL — not a valid header but some parsers accept |
| WS-UPGRADE-INVALID-VER | WebSockets | Warn | WebSocket upgrade with unsupported version — should return 426 |
