import 'package:http_session/src/cookie.dart';
import 'package:test/test.dart';

void main() {
  test('Cookie Store - Test the canonucalisation method', () {
    CookieStore store = CookieStore();

    String result = store.toCanonical("öbb.at");
    expect(result, "xn--bb-eka.at");

    result = store.toCanonical("Bücher.example");
    expect(result, "xn--bcher-kva.example");
  });
}
