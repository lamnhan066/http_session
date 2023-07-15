import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http_session/http_session.dart';

class HttpSession implements IOClient {
  /// Shared http session instance
  static final shared = HttpSession();

  /// Get current headers value
  Map<String, String> get headers => _headers;

  /// Create a new http session instance
  HttpSession() {
    _httpDelegate = _ioClient();
  }

  late IOClient _httpDelegate;
  final Map<String, String> _headers = <String, String>{};

  /// Avoid badCertificate error
  IOClient _ioClient() {
    final HttpClient ioc = HttpClient();
    ioc.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;

    return IOClient(ioc);
  }

  /// Clear the current session
  void clear() {
    _headers.clear();
  }

  @override
  void close() {
    _headers.clear();
    _httpDelegate.close();
  }

  @override
  Future<IOStreamedResponse> send(
    http.BaseRequest request,
  ) =>
      _send(request.method, request.url, request.headers);

  @override
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return Response.fromStream(await _send(
      'DELETE',
      url,
      headers,
      body,
      encoding,
    ));
  }

  @override
  Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    return Response.fromStream(await _send(
      'GET',
      url,
      headers,
    ));
  }

  @override
  Future<http.Response> head(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    return Response.fromStream(await _send(
      'HEAD',
      url,
      headers,
    ));
  }

  @override
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return Response.fromStream(await _send(
      'PATCH',
      url,
      headers,
      body,
      encoding,
    ));
  }

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return Response.fromStream(await _send(
      'POST',
      url,
      headers,
      body,
      encoding,
    ));
  }

  @override
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return Response.fromStream(await _send(
      'PUT',
      url,
      headers,
      body,
      encoding,
    ));
  }

  @override
  Future<String> read(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final response = await get(url, headers: headers);
    _checkResponseSuccess(url, response);
    return response.body;
  }

  @override
  Future<Uint8List> readBytes(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final response = await get(url, headers: headers);
    _checkResponseSuccess(url, response);
    return response.bodyBytes;
  }

  Future<IOStreamedResponse> _send(
    String method,
    Uri url,
    Map<String, String>? headers, [
    Object? body,
    Encoding? encoding,
  ]) async {
    final tempRequest =
        _tempRequest(method, url, _getCookie(headers), body, encoding);
    tempRequest.followRedirects = false;

    var result = await _httpDelegate.send(tempRequest);
    _updateCookieHeaders(result.headers);

    while (result.isRedirect) {
      final location = result.headers[HttpHeaders.locationHeader]!;
      final tempRequest = _tempRequest(
        method,
        Uri.parse(location),
        _getCookie(result.headers),
        body,
        encoding,
      );
      tempRequest.followRedirects = false;
      result = await _httpDelegate.send(tempRequest);
      _updateCookieHeaders(result.headers);
    }

    return result;
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
  Map<String, String> _getCookie(Map<String, String>? headers) {
    if (headers != null) {
      headers.addAll(_headers);
    }
    headers ??= _headers;
    return headers;
  }

  /// Update the cookie
  void _updateCookieHeaders(Map<String, String> headers) {
    final String? rawCookie = headers['set-cookie'];
    if (rawCookie != null) {
      final int index = rawCookie.indexOf(';');
      _headers['cookie'] =
          (index == -1) ? rawCookie : rawCookie.substring(0, index);
    }
  }

  /// Throws an error if [response] is not successful.
  void _checkResponseSuccess(Uri url, Response response) {
    if (response.statusCode < 400) return;
    var message = 'Request to $url failed with status ${response.statusCode}';
    if (response.reasonPhrase != null) {
      message = '$message: ${response.reasonPhrase}';
    }
    throw ClientException('$message.', url);
  }
}
