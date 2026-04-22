# TODO

- [ ] Update the compliance tool to support intentional failures
  - Example: `COMP-CHUNKED-NO-FINAL` fails because `bottom_shelf` is a streaming server and abruptly closes the connection on error after headers are sent (to signal truncation). The compliance tool flags this truncated `200 OK` response as a failure rather than an acceptable close/timeout. We accept this failure as an honest reflection of streaming trade-offs.

- [ ] Document accepted failures due to lack of global routing knowledge in `shelf`
  - Examples: `COMP-METHOD-CASE`, `COMP-UNKNOWN-METHOD`, `COMP-OPTIONS-ALLOW`. These return `404 Not Found` because the server passes the request to the handler, and if the handler doesn't match the method, it falls through to a default 404. A compliant server should return `405 Method Not Allowed` or `501 Not Implemented`, but without a global routing table at the server level, we cannot know if a path is valid for other methods. We accept these failures as an honest reflection of the `shelf` architecture.

- [ ] Document accepted failures for chunk extensions due to security and simplicity choices
  - Examples: `COMP-CHUNKED-EXTENSION`, `MAL-CHUNK-EXT-64K`. These fail because `bottom_shelf` explicitly rejects chunk extensions with `501 Not Implemented` to reduce attack surface and avoid request smuggling vectors associated with complex extension parsing. The compliance tool expects them to be ignored or rejected with `400 Bad Request`. We accept these failures as an honest reflection of a defensive security posture.
