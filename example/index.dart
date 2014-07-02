import 'dart:convert';
import 'dart:html';

void main() {
  var span = querySelector('#count') as SpanElement;

  HttpRequest.getString('/api').then((value) {
    return JSON.decode(value);
  }).then((obj) {
    var count = obj['count'];
    span.text = count.toString();
  });
}
