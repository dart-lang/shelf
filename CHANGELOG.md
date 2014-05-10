## 0.1.2

* Respond with `304-Not modified` against `IF-MODIFIED-SINCE` request header.

## 0.1.1+1

* Removed work around for [issue](https://codereview.chromium.org/278783002/).

## 0.1.1

* Correctly handle requests when not hosted at the root of a site.
* Send `last-modified` header.
* Work around [known issue](https://codereview.chromium.org/278783002/) with HTTP date formatting.
