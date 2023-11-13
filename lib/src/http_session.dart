import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:cookie_store/cookie_store.dart';

class HttpSession implements IOClient {
  /// Shared http session instance
  static final shared = HttpSession();

  /// Getter for the cookie store
  CookieStore get cookieStore => _cookieStore;

  /// Create a new http session instance
  HttpSession() {
    _httpDelegate = _ioClient();
    _cookieStore = CookieStore();
  }

  late IOClient _httpDelegate;
  late CookieStore _cookieStore;

  /// Avoid badCertificate error
  IOClient _ioClient() {
    final HttpClient ioc = HttpClient();
    ioc.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    return IOClient(ioc);
  }

  /// Clear the current session
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

  @override
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    Map<String, String> headers0 = {
      "Cookie": _getCookieHeader(url.host, url.path)
    };
    headers0.addAll(headers ?? {});
    return _updateResponse(_httpDelegate.delete(
      url,
      headers: headers0,
      body: body,
      encoding: encoding,
    ));
  }

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    Map<String, String> headers0 = {
      "Cookie": _getCookieHeader(url.host, url.path)
    };
    headers0.addAll(headers ?? {});
    return _updateResponse(_httpDelegate.get(url, headers: headers0));
  }

  @override
  Future<http.Response> head(Uri url, {Map<String, String>? headers}) async {
    Map<String, String> headers0 = {
      "Cookie": _getCookieHeader(url.host, url.path)
    };
    headers0.addAll(headers ?? {});
    return _updateResponse(_httpDelegate.head(url, headers: headers0));
  }

  @override
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    Map<String, String> headers0 = {
      "Cookie": _getCookieHeader(url.host, url.path)
    };
    headers0.addAll(headers ?? {});
    return _updateResponse(_httpDelegate.patch(
      url,
      headers: headers0,
      body: body,
      encoding: encoding,
    ));
  }

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    Map<String, String> headers0 = {
      "Cookie": _getCookieHeader(url.host, url.path)
    };
    headers0.addAll(headers ?? {});
    return _updateResponse(_httpDelegate.post(
      url,
      headers: headers0,
      body: body,
      encoding: encoding,
    ));
  }

  @override
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    Map<String, String> headers0 = {
      "Cookie": _getCookieHeader(url.host, url.path)
    };
    headers0.addAll(headers ?? {});
    return _updateResponse(_httpDelegate.put(
      url,
      headers: headers0,
      body: body,
      encoding: encoding,
    ));
  }

  @override
  Future<String> read(
    Uri url, {
    Map<String, String>? headers,
  }) {
    Map<String, String> headers0 = {
      "Cookie": _getCookieHeader(url.host, url.path)
    };
    headers0.addAll(headers ?? {});
    return _httpDelegate.read(url, headers: headers0);
  }

  @override
  Future<Uint8List> readBytes(
    Uri url, {
    Map<String, String>? headers,
  }) {
    Map<String, String> headers0 = {
      "Cookie": _getCookieHeader(url.host, url.path)
    };
    headers0.addAll(headers ?? {});
    return _httpDelegate.readBytes(url, headers: headers0);
  }

  /// Add cookie to the request
  String _getCookieHeader(String requestDomain, String requestPath) {
    return CookieStore.buildCookieHeader(
        _cookieStore.getCookiesForRequest(requestDomain, requestPath));
  }

  /// Update the cookie
  void _updateCookies(
      Map<String, String> headers, String requestDomain, String requestPath) {
    final String? rawCookie = headers['set-cookie'];
    if (rawCookie != null) {
      _cookieStore.updateCookies(rawCookie, requestDomain, requestPath);
    }
  }

  /// Get cookies from the response and pass it along
  Future<http.Response> _updateResponse(Future<http.Response> resp) {
    return Future.value(resp.then((http.Response response) {
      _updateCookies(response.headers, response.request!.url.host,
          response.request!.url.path);
      return response;
    }));
  }
}
