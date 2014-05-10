## 0.1.2

* The preferred top-level method is now `createStaticHandler`. `getHandler` is deprecated.
* Set `content-type` header if the mime type of the requested file can be determined from the file extension.
* Respond with `304-Not modified` against `IF-MODIFIED-SINCE` request header.
* Better error when provided a non-existant `fileSystemPath`.
* Added `example/example_server.dart`.

## 0.1.1+1

* Removed work around for [issue](https://codereview.chromium.org/278783002/).

## 0.1.1

* Correctly handle requests when not hosted at the root of a site.
* Send `last-modified` header.
* Work around [known issue](https://codereview.chromium.org/278783002/) with HTTP date formatting.
