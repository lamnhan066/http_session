import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cookie_store/cookie_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class _RedirectInfo implements RedirectInfo {
  @override
  final int statusCode;
  @override
  final String method;
  @override
  final Uri location;
  @override
  const _RedirectInfo(this.statusCode, this.method, this.location);
}

class HttpSession implements IOClient {
  /// Shared http session instance.
  static final shared = HttpSession();

  /// Set maximum number of redirects.
  int maxRedirects;

  /// Getter for the cookie store.
  CookieStore get cookieStore => _cookieStore;

  /// Accept bad server certificates. This should NOT be set in production.
  final bool acceptBadCertificate;

  /// Create a new http session instance.
  HttpSession({this.acceptBadCertificate = false, this.maxRedirects = 15}) {
    _httpDelegate = _ioClient();
    _cookieStore = CookieStore();
  }

  late IOClient _httpDelegate;
  late CookieStore _cookieStore;

  /// Avoid badCertificate error.
  IOClient _ioClient([HttpClient? client]) {
    final HttpClient ioc = client ?? HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => acceptBadCertificate;

    return IOClient(ioc);
  }

  /// Clear the current session.
  void clear() {
    _cookieStore.reduceSize(0, true);
  }

  @override
  void close() {
    _cookieStore.onSessionEnded();
    _httpDelegate.close();
  }

  @override
  Future<IOStreamedResponse> send(
    http.BaseRequest request,
  ) {
    final tempRequest = request;
    request.headers['Cookie'] = CookieStore.buildCookieHeader(
        _cookieStore.getCookiesForRequest(request.url.host, request.url.path));

    final result = _httpDelegate.send(tempRequest);
    return Future.value(result.then((result) {
      String? setCookie = result.headers["Set-Cookie"];
      if (setCookie != null) {
        _cookieStore.updateCookies(
            setCookie, request.url.host, request.url.path);
      }
      return result;
    }));
  }

  Future<http.Response> _sendRequest(String method, Uri url, int numRecurseLeft,
      {Map<String, String>? headers,
      Object? body,
      Encoding? encoding,
      List<_RedirectInfo>? redirects}) async {
    // Make sure we're not in an infinite (or too long of a) loop
    if (--numRecurseLeft < 0) {
      throw RedirectException("Too many redirects!", redirects ?? []);
    }

    // Get the cookie header for this request
    String cookieHeader = _getCookieHeader(url.host, url.path);
    Map<String, String> headers0 = {"Cookie": cookieHeader};
    headers0.addAll(headers ?? {});

    // Construct request using the parameters passed in
    final request = http.Request(method, url)
      ..followRedirects = false
      ..headers.addAll(headers0);

    // Yoink, this is how the HTTP package itself does it
    if (body != null) {
      if (body is String) {
        request.body = body;
      } else if (body is List) {
        request.bodyBytes = body.cast<int>();
      } else if (body is Map) {
        request.bodyFields = body.cast<String, String>();
      } else {
        throw ArgumentError('Invalid request body "$body".');
      }
    }
    if (encoding != null) {
      request.encoding = encoding;
    }
    // Return promise but pass it through _updateResponse.
    return _updateResponse(_httpDelegate.send(request).then((streamedResponse) {
      // Also follow redirects by recursing if we see a redirect.
      final response = http.Response.fromStream(streamedResponse);
      return response.then((newResponse) {
        // Add current call to the redirect chain.
        redirects = redirects ?? [];
        if (newResponse.request == null) {
          throw StateError(
              "The response doesn't have a request associated with it!");
        }
        final redirectInfo = _RedirectInfo(
          newResponse.statusCode,
          newResponse.request!.method,
          newResponse.request!.url,
        );
        redirects!.add(redirectInfo);
        final String? location = newResponse.headers['location'];
        if (newResponse.isRedirect) {
          if (location != null) {
            final redirectUri = Uri.parse(location);
            final resolvedUri = redirectInfo.location.resolveUri(redirectUri);
            return _sendRequest(
              redirectInfo.method,
              resolvedUri,
              numRecurseLeft,
              headers: headers,
              body: body,
              encoding: encoding,
              redirects: redirects,
            );
          } else {
            return _sendRequest(
              redirectInfo.method,
              redirectInfo.location,
              numRecurseLeft,
              headers: headers,
              body: body,
              encoding: encoding,
              redirects: redirects,
            );
          }
        }

        return response;
      });
    }));
  }

  @override
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return _sendRequest("DELETE", url, maxRedirects,
        headers: headers, body: body, encoding: encoding);
  }

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    return _sendRequest("GET", url, maxRedirects, headers: headers);
  }

  @override
  Future<http.Response> head(Uri url, {Map<String, String>? headers}) async {
    return _sendRequest("HEAD", url, maxRedirects, headers: headers);
  }

  @override
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return _sendRequest("PATCH", url, maxRedirects,
        headers: headers, body: body, encoding: encoding);
  }

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return _sendRequest("POST", url, maxRedirects,
        headers: headers, body: body, encoding: encoding);
  }

  @override
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return _sendRequest("PUT", url, maxRedirects,
        headers: headers, body: body, encoding: encoding);
  }

  @override
  Future<String> read(
    Uri url, {
    Map<String, String>? headers,
  }) {
    return _sendRequest("GET", url, maxRedirects).then((value) => value.body);
  }

  @override
  Future<Uint8List> readBytes(
    Uri url, {
    Map<String, String>? headers,
  }) {
    return _sendRequest("GET", url, maxRedirects)
        .then((value) => value.bodyBytes);
  }

  /// Add cookie to the request.
  String _getCookieHeader(String requestDomain, String requestPath) {
    return CookieStore.buildCookieHeader(
        _cookieStore.getCookiesForRequest(requestDomain, requestPath));
  }

  /// Update the cookie.
  void _updateCookies(
      Map<String, String> headers, String requestDomain, String requestPath) {
    final String? rawCookie = headers['set-cookie'];
    if (rawCookie != null) {
      _cookieStore.updateCookies(rawCookie, requestDomain, requestPath);
    }
  }

  /// Get cookies from the response and pass it along.
  Future<http.Response> _updateResponse(Future<http.Response> resp) {
    return Future.value(resp.then((http.Response response) {
      _updateCookies(response.headers, response.request!.url.host,
          response.request!.url.path);
      return response;
    }));
  }
}
