import 'package:http_session/http_session.dart';
import 'package:test/test.dart';

/// TODO: Add test server
final testURI = Uri.parse('https://raddle.me/login');
void main() {
  // Set the debug log to true
  HttpSession.shared.debugLog = true;
  HttpSession.shared.maxRedirects = 5;

  test('Http Session', () async {
    expect(HttpSession.shared.headers, isEmpty);

    await HttpSession.shared.get(testURI);

    print('Final cookie: ${HttpSession.shared.headers}');
    expect(HttpSession.shared.headers, isNotEmpty);

    HttpSession.shared.close();

    expect(HttpSession.shared.headers, isEmpty);
  });

  // test('Http Session', () async {
  //   String raddleBase = "https://raddle.me";
  //   expect(HttpSession.shared.headers, isEmpty);

  //   await HttpSession.shared.get(Uri.parse("https://raddle.me/login"));

  //   print(HttpSession.shared.headers);
  // });
}
