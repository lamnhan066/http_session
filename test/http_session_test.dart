import 'package:http_session/http_session.dart';
import 'package:test/test.dart';

import 'dart:convert';
import 'dart:io';

const int testPort = 8888;
const testURL = 'http://localhost:$testPort';

late HttpServer testServer;

const int serverShutdownTimeLimitSeconds = 15;

void main() async {
  late HttpSession session;
  setUpAll(() async {
    // Session object
    session = HttpSession();
    // Test server
    testServer = await HttpServer.bind(InternetAddress.anyIPv4, testPort);
    testServer.listen((HttpRequest request) async {
      var response = request.response;
      var uri = request.uri;
      if (uri.path == "/gimmecookies") {
        // /gimmecookies
        if (uri.queryParameters.containsKey("name") &&
            uri.queryParameters.containsKey("value")) {
          // ?name=<name of cookie>&value=<value of cookie>
          response.headers.add("Set-Cookie",
              "${uri.queryParameters['name']}=${uri.queryParameters['value']}");
        } else if (uri.queryParameters.containsKey("num")) {
          // num=<how many cookies to set>
          List<String> cookies = [];
          for (var i = 0; i < int.parse(uri.queryParameters["num"]!); i++) {
            cookies.add("test$i=true");
          }
          response.headers.add("Set-Cookie", cookies.join(","));
        } else {
          response.statusCode = 400;
          response.reasonPhrase = "Bad Request";
        }
      } else if (uri.path == "/redirectLoop") {
        // /redirectLoop
        response.statusCode = 302;
        response.headers.add("Location", "/redirectLoop");
      } else if (uri.path == "/longRedirectLoop1") {
        // /longRedirectLoop1
        response.statusCode = 302;
        response.headers.add("Location", "/longRedirectLoop2");
      } else if (uri.path == "/longRedirectLoop2") {
        // /longRedirectLoop2
        response.statusCode = 302;
        response.headers.add("Location", "/longRedirectLoop1");
      } else if (uri.path == "/httpdetails") {
        String content = await utf8.decodeStream(request);
        response.writeln(jsonEncode(
            {'method': request.method, 'path': uri.path, 'body': content}));
      } else {
        response.statusCode = 404;
        response.reasonPhrase = "Not Found";
      }
      await response.flush();
      response.close();
    });
  });
  tearDownAll(
    () async {
      try {
        testServer
            .close()
            .timeout(Duration(seconds: serverShutdownTimeLimitSeconds));
      } catch (e) {
        testServer.close(force: true);
      }
    },
  );
  test('Test that we can save cookies', () async {
    ///TODO: Minimal test, expand
    session.clear();
    expect(session.cookieStore.cookies.length, 0);
    await session.get(Uri.parse("$testURL/gimmecookies?name=foo&value=bar"));
    expect(session.cookieStore.cookies.length, 1);
    await session.get(Uri.parse("$testURL/gimmecookies?num=5"));
    expect(session.cookieStore.cookies.length, 6);
    session.clear();
    expect(session.cookieStore.cookies.length, 0);
  });
  test("Test that we don't send cookies when we shouldn't", () {
    session.clear();
    session.get(Uri.parse("$testURL/gimmecookies?name=foo&value=bar"));
    expect([], session.cookieStore.getCookiesForRequest(testURL, "/somethingelse"));
  });
  group('Test HTTP requests being sent correctly -', () {
    test('GET', () async {
      Response response = await session.get(Uri.parse("$testURL/httpdetails"));
      String str = response.body;
      Object respObj = jsonDecode(str);
      expect(respObj, {'method': 'GET', 'path': "/httpdetails", 'body': ''});
    });
    test('POST', () async {
      Response response = await session.post(Uri.parse("$testURL/httpdetails"));
      String str = response.body;
      Object respObj = jsonDecode(str);
      expect(respObj, {'method': 'POST', 'path': "/httpdetails", 'body': ''});
    });
    test('DELETE', () async {
      Response response =
          await session.delete(Uri.parse("$testURL/httpdetails"));
      String str = response.body;
      Object respObj = jsonDecode(str);
      expect(respObj, {'method': 'DELETE', 'path': "/httpdetails", 'body': ''});
    });
    test('PATCH', () async {
      Response response =
          await session.patch(Uri.parse("$testURL/httpdetails"));
      String str = response.body;
      Object respObj = jsonDecode(str);
      expect(respObj, {'method': 'PATCH', 'path': "/httpdetails", 'body': ''});
    });
    test('PUT', () async {
      Response response = await session.put(Uri.parse("$testURL/httpdetails"));
      String str = response.body;
      Object respObj = jsonDecode(str);
      expect(respObj, {'method': 'PUT', 'path': "/httpdetails", 'body': ''});
    });
    test('HEAD', () async {
      Response response = await session.head(Uri.parse("$testURL/httpdetails"));
      String str = response.body;
      expect(str.isEmpty, true);
    });
  });
}
