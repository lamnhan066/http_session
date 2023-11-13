import 'package:http_session/http_session.dart';
import 'package:test/test.dart';

const testURL = 'https://begaydocrime.org/http_session/gimmecookies.php';

void main() {
  test('Http Session', () async {
    ///TODO: Minimal test, expand
    HttpSession session = HttpSession();
    expect(session.cookieStore.cookies.length, 0);
    await session.get(Uri.parse("$testURL?name=foo&value=bar"));
    expect(session.cookieStore.cookies.length, 1);
    await session.get(Uri.parse("$testURL?num=5"));
    expect(session.cookieStore.cookies.length, 6);
    session.clear();
    expect(session.cookieStore.cookies.length, 0);
  });
}
