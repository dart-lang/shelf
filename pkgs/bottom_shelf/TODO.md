# TODO

- [ ] Update the compliance tool to support intentional failures
  - Example: `COMP-CHUNKED-NO-FINAL` fails because `bottom_shelf` is a streaming server and abruptly closes the connection on error after headers are sent (to signal truncation). The compliance tool flags this truncated `200 OK` response as a failure rather than an acceptable close/timeout. We accept this failure as an honest reflection of streaming trade-offs.
