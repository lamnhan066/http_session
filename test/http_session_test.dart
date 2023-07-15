import 'package:http_session/http_session.dart';
import 'package:test/test.dart';

/// TODO: Add test server
const testURL = 'https://raddle.me/login';

void main() {
  test('Http Session', () async {
    expect(HttpSession.shared.headers, isEmpty);

    // await HttpSession.shared.post(Uri.parse(testURL));

    // expect(HttpSession.shared.headers, isNotEmpty);

    await HttpSession.shared.get(Uri.parse(testURL));

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
