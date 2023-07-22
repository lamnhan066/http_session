import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http_session/http_session.dart';

class HttpSession extends IOClient {
  /// Shared http session instance
  static final shared = HttpSession();

  /// Sets a value that will decide whether to accept a secure connection
  /// with a server certificate that cannot be authenticated by any of the
  /// trusted root certificates.
  ///
  /// This setting is only affect the default [HttpClient] (means `client` is null),
  /// so please notice it.
  ///
  /// If this value is `true`, this setting will be added to the [HttpClient] :
  /// ``` dart
  /// client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  /// ```
  final bool acceptBadCertificate;

  /// Set this property to the maximum number of redirects to follow.
  /// If this number is exceeded an error event will be added with a [RedirectException].
  ///
  /// The default value is 5.
  int maxRedirects;

  /// Allow printing the debug logs
  bool debugLog = false;

  /// Count the redirection
  int _redirectCounter = 0;

  /// Get current headers value
  Map<String, String> get headers => _headers;

  late IOClient _httpDelegate;
  final Map<String, String> _headers = <String, String>{};

  /// Create a new [HttpSession] instance
  HttpSession({
    HttpClient? client,
    this.acceptBadCertificate = false,
    this.maxRedirects = 5,
    this.debugLog = false,
  }) {
    _httpDelegate = _ioClient(client);
  }

  /// Avoid badCertificate error
  IOClient _ioClient([HttpClient? client]) {
    final HttpClient ioc = client ?? HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => acceptBadCertificate;

    return IOClient(ioc);
  }

  /// Clear the current session
  void clear() {
    _headers.clear();
  }

  /// Update cookie manually from headers
  void updateCookieFromHeaders(Map<String, String> headers) {
    _updateCookieHeaders(headers);
  }

  @override
  void close() {
    _headers.clear();
    _httpDelegate.close();
  }

  @override
  Future<IOStreamedResponse> send(
    http.BaseRequest request,
  ) async {
    _getCookie(request.headers);
    _print('Request: $request with cookie: ${request.headers}');

    final response = await _httpDelegate.send(request);
    _updateCookieHeaders(response.headers);
    _print('Status code: ${response.statusCode}');
    return response;
  }

  @override
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _send(
      'DELETE',
      url,
      headers,
      body,
      encoding,
    );
  }

  @override
  Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) {
    return _send(
      'GET',
      url,
      headers,
    );
  }

  @override
  Future<http.Response> head(
    Uri url, {
    Map<String, String>? headers,
  }) {
    return _send(
      'HEAD',
      url,
      headers,
    );
  }

  @override
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _send(
      'PATCH',
      url,
      headers,
      body,
      encoding,
    );
  }

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _send(
      'POST',
      url,
      headers,
      body,
      encoding,
    );
  }

  @override
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _send(
      'PUT',
      url,
      headers,
      body,
      encoding,
    );
  }

  // @override
  // Future<String> read(
  //   Uri url, {
  //   Map<String, String>? headers,
  // }) async {
  //   final response = await get(url, headers: headers);
  //   _checkResponseSuccess(url, response);
  //   return response.body;
  // }

  // @override
  // Future<Uint8List> readBytes(
  //   Uri url, {
  //   Map<String, String>? headers,
  // }) async {
  //   final response = await get(url, headers: headers);
  //   _checkResponseSuccess(url, response);
  //   return response.bodyBytes;
  // }

  Future<http.Response> _send(
    String method,
    Uri url,
    Map<String, String>? headers, [
    Object? body,
    Encoding? encoding,
  ]) async {
    _redirectCounter = 0;
    Uri uri = url;
    IOStreamedResponse response;
    while (true) {
      final request = _tempRequest(
        method,
        uri,
        headers,
        body,
        encoding,
      );
      request.followRedirects = false;
      response = await send(request);

      if (!response.isRedirect) break;

      uri = Uri.parse(response.headers[HttpHeaders.locationHeader]!);
      _print('Redirecting to: $uri...');

      _redirectCounter++;
      if (_redirectCounter > maxRedirects) {
        return throw RedirectException("Redirect limit exceeded", []);
      }
    }

    return Response.fromStream(response);
  }

  /// Create a temporary [Request]
  http.BaseRequest _tempRequest(
    String method,
    Uri url,
    Map<String, String>? headers, [
    Object? body,
    Encoding? encoding,
  ]) {
    var request = Request(method, url);

    if (headers != null) request.headers.addAll(headers);
    if (encoding != null) request.encoding = encoding;
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

    return request;
  }

  /// Add cookie to the request
  void _getCookie(Map<String, String> headers) {
    headers.addAll(_headers);
  }

  /// Update the cookie
  void _updateCookieHeaders(Map<String, String> headers) {
    final String? rawCookie = headers[HttpHeaders.setCookieHeader];
    if (rawCookie != null) {
      final int index = rawCookie.indexOf(';');
      _headers[HttpHeaders.cookieHeader] =
          (index == -1) ? rawCookie : rawCookie.substring(0, index);
    }
  }

  /// Throws an error if [response] is not successful.
  // void _checkResponseSuccess(Uri url, Response response) {
  //   if (response.statusCode < 400) return;
  //   var message = 'Request to $url failed with status ${response.statusCode}';
  //   if (response.reasonPhrase != null) {
  //     message = '$message: ${response.reasonPhrase}';
  //   }
  //   throw ClientException('$message.', url);
  // }

  /// Print the debug logs
  void _print(String log) {
    if (!debugLog) return;
    print(log);
  }
}
