import 'package:http_session/src/cookie.dart';
import 'package:test/test.dart';

void main() {
  test('Cookie Store - Test the canonicalisation method', () {
    CookieStore store = CookieStore();

    String result = store.toCanonical("öbb.at");
    expect(result, "xn--bb-eka.at");

    result = store.toCanonical("Bücher.example");
    expect(result, "xn--bcher-kva.example");
  });

  /// LDH Label format defined in RFC 5890 Section 2.3.1:
  ///
  /// ASCII uppercase, lowercase, or numbers. Dashes allowed other than in the
  /// first and last position. Complete string must not be longer than
  /// 63 octets.
  test('Cookie Store - Test the LDH label regex', () {
    // Short strings are valid, so are dashes not in the last position
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("a"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("aa"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("a-a"));
    // Same, uppercase is allowed
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("A"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("AA"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("A-A"));
    // So is a mixture of upper and lowercase
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("aA"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("Aa"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("a-A"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("A-a"));
    // Short strings with dashes in the first and/or last positions are invalid
    expect(false, RegExp(CookieStore.ldhLabelRegexString).hasMatch("a-"));
    expect(false, RegExp(CookieStore.ldhLabelRegexString).hasMatch("-a"));
    expect(false, RegExp(CookieStore.ldhLabelRegexString).hasMatch("-a-"));
    expect(false, RegExp(CookieStore.ldhLabelRegexString).hasMatch("aa-"));
    expect(false, RegExp(CookieStore.ldhLabelRegexString).hasMatch("-aa"));
    expect(false, RegExp(CookieStore.ldhLabelRegexString).hasMatch("-aa-"));
    expect(false, RegExp(CookieStore.ldhLabelRegexString).hasMatch("-"));
    // Numbers are valid, on their own or as part of a larger string
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("1"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("1a"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("1aA"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("1Aa"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("11"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("11a"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("11aA"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("1a1"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("1aA1"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("1Aa1"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("1a11"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("1aA11"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("1Aa11"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("a11"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("aA11"));
    expect(true, RegExp(CookieStore.ldhLabelRegexString).hasMatch("111"));
    // Non-ASCII characters and non-alphanumeric ASCII characters are invalid
    expect(false, RegExp(CookieStore.ldhLabelRegexString).hasMatch("a a"));
    expect(false, RegExp(CookieStore.ldhLabelRegexString).hasMatch("aç a"));
    expect(false, RegExp(CookieStore.ldhLabelRegexString).hasMatch("aça"));
    expect(false, RegExp(CookieStore.ldhLabelRegexString).hasMatch("a ça"));
    expect(
        false,
        RegExp(CookieStore.ldhLabelRegexString)
            .hasMatch("aaaaaaaaaaaaaaaaaaaaaaaaaa ça"));
    expect(
        false,
        RegExp(CookieStore.ldhLabelRegexString)
            .hasMatch("a                   ça"));
    expect(false,
        RegExp(CookieStore.ldhLabelRegexString).hasMatch("a ççççççççççççça"));
    expect(
        false,
        RegExp(CookieStore.ldhLabelRegexString)
            .hasMatch("a çaaaaaaaaaaaaaaaaaaaa"));
    // A 63-octet string is valid
    expect(
        true,
        RegExp(CookieStore.ldhLabelRegexString).hasMatch(
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"));
    // But no longer
    expect(
        false,
        RegExp(CookieStore.ldhLabelRegexString).hasMatch(
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"));
  });
}
