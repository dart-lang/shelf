# Comprehensive Test Plan: `bottom_shelf` HTTP Compatibility & Security

This document outlines the required test suite for `bottom_shelf` to ensure parity with `dart:io` (`_http`), compliance with RFC 9112, and resilience against historical vulnerabilities found in the Dart SDK.

## 1. Security & Vulnerability Hardening (The SDK Legacy)

These tests are derived from critical fixes in `sdk/lib/_http` to prevent regressions in the new implementation.

### 1.1 Header Injection & Sanitization
**Requirement:** Header values must not contain NUL (`0x00`), LF (`0x0A`), or CR (`0x0D`) characters.
- **Rationale:** Prevents header splitting and log injection. Fixes [Issue 56636](https://github.com/dart-lang/sdk/issues/56636).
- **SDK Reference:** `sdk/lib/_http/http_parser.dart` (See `_addToHeaderValueWithValidation` at line 1184).
- **Test Scenario:**
    - Send: `GET / HTTP/1.1\r\nX-Injected: Value\x00Injection\r\n\r\n`.
    - Expected: Server must reject the request with a `400 Bad Request` or terminate the socket.

### 1.2 HTTP Request Smuggling (TE.CL / CL.TE)
**Requirement:** Requests containing both `Content-Length` and `Transfer-Encoding: chunked` must be handled strictly, prioritizing `chunked` or rejecting the ambiguity.
- **Rationale:** Prevents desynchronization between proxy and backend. Fixes [Commit 8b6c67a4ba5](https://github.com/dart-lang/sdk/commit/8b6c67a4ba5).
- **SDK Reference:** `sdk/lib/_http/http_parser.dart` (See `_chunked` logic at lines 800-810).
- **Test Scenario:**
    - Send: A request with `Content-Length: 5` and `Transfer-Encoding: chunked`.
    - Expected: `bottom_shelf` must prioritize `Transfer-Encoding` and correctly parse the chunks, or reject if the mismatch is deemed a security risk.

### 1.3 Credential Leakage on Redirect
**Requirement:** Sensitive headers (Authorization, Cookie) must be stripped when redirecting to a different origin.
- **Rationale:** Security fix for cross-origin data leaks. Fixes [Commit 8b6c67a4ba5](https://github.com/dart-lang/sdk/commit/8b6c67a4ba5).
- **SDK Reference:** `sdk/lib/_http/http_impl.dart` (See `shouldCopyHeaderOnRedirect`).
- **Note:** Since `bottom_shelf` is a server, verify that any internal redirection logic (if implemented) follows these rules.

## 2. Protocol Compliance (RFC 9112)

### 2.1 Chunked Encoding Robustness
**Requirement:** Correct handling of chunk extensions and trailers.
- **SDK Reference:** `sdk/lib/_http/http_parser.dart` (State machine transitions for `BODY_CHUNK_SIZE`, etc.).
- **Test Scenarios:**
    - Large chunks (exceeding 8KB).
    - Chunks split across multiple socket `read` calls.
    - Zero-length end chunk (`0\r\n\r\n`).

### 2.2 Host Header Validation
**Requirement:** Correct parsing of IPv6 addresses in the `Host` header.
- **Rationale:** Fixes [Commit 4160a6b3618](https://github.com/dart-lang/sdk/commit/4160a6b3618).
- **SDK Reference:** `sdk/lib/_http/http_parser.dart` (Host parsing logic).
- **Test Scenario:**
    - Send: `GET / HTTP/1.1\r\nHost: [::1]:8080\r\n\r\n`.
    - Expected: `request.requestedUri.host` must be `::1`.

### 2.3 Legacy Folded Headers
**Requirement:** Correctly ignore or handle (per RFC 9112) headers starting with SP/HTAB on subsequent lines.
- **Rationale:** Historically allowed but now deprecated/restricted. Fixes [Issue 53227](https://github.com/dart-lang/sdk/issues/53227).
- **SDK Reference:** `sdk/lib/_http/http_parser.dart` (Line 760, handling of `_State.HEADER_VALUE_START`).
- **Test Scenario:**
    - Send: `X-Folded: first\r\n  second\r\n`.
    - Expected: Handle as a single value "first second" or reject if strict mode is enabled.

## 3. Robustness & DoS Mitigation

### 3.1 Slowloris (Header Timeout)
**Requirement:** Connection must be closed if headers are not completed within a specific timeframe.
- **Test Scenario:** Send one header byte every 5 seconds. Verify the server eventually closes the connection.

### 3.2 Resource Limits
**Requirement:** Enforce strict limits on URL length, individual header field size, and total header block size.
- **Current `bottom_shelf` limits:** 64KB Total, 8KB Field/URL.
- **Test Scenario:** Send a 9KB URL. Expected: `414 URI Too Long`.

### 3.3 Socket Fragmentation (The "Stress Test")
**Requirement:** The parser must maintain state even if the request is delivered 1 byte at a time.
- **Test Scenario:** Loopback test that pipes a full valid HTTP request byte-by-byte into the server socket.

## 4. `dart:io` Parity Reference Matrix

| Feature | `bottom_shelf` File | `dart:io` Equivalent | Logic Path in SDK |
| :--- | :--- | :--- | :--- |
| **HTTP Parsing** | `raw_http_parser.dart` | `http_parser.dart` | `_HttpParser.onData` |
| **Header Storage** | `lazy_byte_header_map.dart` | `http_headers.dart` | `_HttpHeaders` |
| **Response Writing** | `raw_shelf_response_serializer.dart` | `http_impl.dart` | `_HttpResponse` |
| **Connection Mgmt** | `raw_shelf_server.dart` | `http_impl.dart` | `_HttpServer` |

## 5. Automated Verification Checklist

- [ ] All `tests/standalone/io/http_*_test.dart` relevant to *serving* have been audited.
- [ ] `bottom_shelf/test/protocol_test.dart` includes a "Byte-by-Byte" fragmentation test.
- [ ] `bottom_shelf/test/robustness_test.dart` includes NUL character injection attempts.
- [ ] URI parsing handles absolute forms (`http://.../`) as per `sdk/lib/_http/http_parser.dart:L615`.
