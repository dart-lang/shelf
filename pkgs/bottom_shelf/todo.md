# TODOs in bottom_shelf

- [ ] Support chunked encoding for responses to avoid buffering the entire body (lib/src/raw_shelf_response_serializer.dart:17)
- [ ] Support chunked transfer encoding for requests (lib/src/raw_shelf_server.dart:81)
- [ ] Real body streaming (lib/src/raw_shelf_server.dart:92)



- [ ] Look at the exceptions thrown!! Since we ARE building on dart:io, maybe we could/should use their network exception types
  - we should AVOID just throwing `Exception`
