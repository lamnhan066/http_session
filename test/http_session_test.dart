import 'package:http_session/http_session.dart';
import 'package:test/test.dart';
import 'dart:io';

const int testPort = 8888;
const testURL = 'http://localhost:$testPort';

void main() async {
  late HttpServer testServer;
  late HttpSession session;
  setUp(() async {
    // Session object
    session = HttpSession();
    // Test server
    testServer = await HttpServer.bind(InternetAddress.anyIPv4, testPort);
    testServer.listen((HttpRequest request) {
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
      } else {
        response.statusCode = 404;
        response.reasonPhrase = "Not Found";
      }
      response.flush();
      response.close();
    });
  });
  test('Http Session', () async {
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
}
