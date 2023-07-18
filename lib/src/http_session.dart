import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

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
  ) {
    final headers = _getCookie(request.headers);
    final tempRequest = request
      ..headers.clear()
      ..headers.addAll(headers);

    final result = _httpDelegate.send(tempRequest);
    result.then((value) => _updateCookieHeaders(value.headers));

    return result;
  }

  @override
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return _updateResponse(await _httpDelegate.delete(
      url,
      headers: _getCookie(headers),
      body: body,
      encoding: encoding,
    ));
  }

  @override
  Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    return _updateResponse(await _httpDelegate.get(
      url,
      headers: _getCookie(headers),
    ));
  }

  @override
  Future<http.Response> head(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    return _updateResponse(await _httpDelegate.head(
      url,
      headers: _getCookie(headers),
    ));
  }

  @override
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return _updateResponse(await _httpDelegate.patch(
      url,
      headers: _getCookie(headers),
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
    return _updateResponse(await _httpDelegate.post(
      url,
      headers: _getCookie(headers),
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
    return _updateResponse(await _httpDelegate.put(
      url,
      headers: _getCookie(headers),
      body: body,
      encoding: encoding,
    ));
  }

  @override
  Future<String> read(
    Uri url, {
    Map<String, String>? headers,
  }) =>
      _httpDelegate.read(url, headers: _getCookie(headers));

  @override
  Future<Uint8List> readBytes(
    Uri url, {
    Map<String, String>? headers,
  }) =>
      _httpDelegate.readBytes(url, headers: _getCookie(headers));

  /// Add cookie to the request
  Map<String, String> _getCookie(Map<String, String>? headers) {
    if (headers != null) {
      headers.addAll(_headers);
    }
    headers ??= _headers;
    return headers;
  }

  /// Update the response
  http.Response _updateResponse(http.Response response) {
    _updateCookieHeaders(response.headers);

    return response;
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
}
