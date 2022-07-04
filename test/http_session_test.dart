import 'package:http_session/http_session.dart';
import 'package:test/test.dart';

/// TODO: Add test server
const testURL = '';

void main() {
  test('Http Session', () async {
    expect(HttpSession.shared.headers, isEmpty);

    await HttpSession.shared.post(Uri.parse(testURL));

    expect(HttpSession.shared.headers, isNotEmpty);

    await HttpSession.shared.get(Uri.parse(testURL));

    expect(HttpSession.shared.headers, isNotEmpty);

    HttpSession.shared.close();

    expect(HttpSession.shared.headers, isEmpty);
  });
}
