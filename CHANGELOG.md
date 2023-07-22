## 0.2.0-rc.3

* Add `updateCookieFromHeaders` to manually update the cookies from headers.

## 0.2.0-rc.2

* **[BREAKING CHANGE]** Decide whether to accept a connection that has bad certificate via `acceptBadCertificate` parameter. This value will be `false` by default since this version, so you need to change it to `true` if you need to accept the bad certificate like the old version.
* You can modify the `HttpClient` when you create a new `HttpSession` via `client` parameter.

## 0.2.0-rc.1

* Rewrite to support adding cookie to redirected URL.
* Add `debugLog` parameter to allow printing the debug log.
* Add `maxRedirects` parameter to set the max redirects.

## 0.1.0

* Update dependencies
* Update sdk version to ">=2.18.0 <4.0.0"

## 0.0.3

* Export http package

## 0.0.1

* Initial Release
