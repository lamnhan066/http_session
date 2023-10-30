import 'package:punycode/punycode.dart';
import 'package:meta/meta.dart';

class CookieStore {
  /// Regex string that matches an LDH Label. Matches the entire string only.
  ///
  /// LDH Label format defined in RFC 5890 Section 2.3.1:
  ///
  /// ASCII uppercase, lowercase, or numbers. Dashes allowed other than in the
  /// first and last position. Complete string must not be longer than
  /// 63 octets.
  ///
  /// More information:
  ///   https://datatracker.ietf.org/doc/html/rfc5890#section-2.3.1
  static const String _ldhLabelRegexString =
      "/\\A[A-Za-z0-9][A-Za-z0-9-]{0,61}[A-Za-z0-9]\\Z/";

  List<Cookie> cookies = [];

  (
    String name,
    String value,
    Map<String, String> attrs,
  ) parseSetCookie(String header) {
    // TODO: Implement
    throw UnimplementedError();
  }

  /// Process given Set-Cookie and add to [cookies].
  /// It must be already broken down to name, value, and lowercase attributes
  ///
  /// @return whether the cookie was accepted
  bool _processCookie(
    String name,
    String value,
    Map<String, String> attrs,
    String requestDomain,
    String requestPath,
  ) {
    // Go through the steps in RFC 6265 section 5.3

    // Step 1
    // This implementation doesn't ignore any cookies

    // Step 2
    Cookie cookie = Cookie(name, value);

    // Step 3
    if (attrs.containsKey("max-age")) {
      // If Max-Age is present:
      // Cookie is persistent
      cookie.persistent = true;
      // Value is the max age in seconds (or -1)
      int seconds = int.parse(attrs["max-age"]!);
      if (seconds > 0) {
        // If the max age is not -1, calculate expiry time
        cookie.expiryTime = cookie.creationTime.add(Duration(seconds: seconds));
      } else {
        // If the max age -1, set expiry time to 1 Jan 1970
        cookie.expiryTime = DateTime.fromMicrosecondsSinceEpoch(0);
      }
    } else if (attrs.containsKey("expires")) {
      // Otherwise:
      // If Expires is present
      // Cookie is persistent
      cookie.persistent = true;

      /// TODO: This is technically not compliant with RFC 6265 but should work
      /// in almost all instances in practice
      cookie.expiryTime = DateTime.parse(attrs["expires"]!);
    } else {
      // Otherwise:
      // Cookie is not persistent
      cookie.persistent = false;

      // Set expiry time to 1 Jan 1970
      cookie.expiryTime = DateTime.fromMicrosecondsSinceEpoch(0);
    }

    // Step 4
    if (attrs.containsKey("domain")) {
      cookie.domain = attrs["domain"]!;
    }

    // Step 5
    /// TODO: This should probably be implemented

    // Step 6
    if (cookie.domain != "") {
      if (!_domainCompare(cookie.domain, requestDomain)) {
        return false;
      } else {
        cookie.hostOnly = false;
        cookie.domain = attrs["domain"]!;
      }
    } else {
      cookie.hostOnly = true;
      cookie.domain = toCanonical(requestDomain);
    }

    // Step 7
    if (attrs.containsKey("path")) {
      cookie.path = attrs["path"]!;
    } else {
      cookie.path = requestPath;
    }

    // Step 8
    cookie.secure = attrs.containsKey("secure");

    // Step 9
    cookie.secure = attrs.containsKey("httponly");

    // Step 10
    // Non-HTTP APIs are not supported, skip

    // Step 11
    cookies.remove(cookie);
    cookies.add(cookie);
    return true;
  }

  /// Tests whether the two domains are equivalent
  ///
  /// Returns false if one or more of the domains are invalid
  bool _domainCompare(String x, String y) {
    try {
      return toCanonical(x) == toCanonical(y);
    } catch (e) {
      // If either are invalid, return false
      return false;
    }
  }

  /// Converts a given [requestDomain] to a canonical representation per RFC6265
  /// !!EXTERNAL USER: READ BELOW!!
  ///
  /// Throws a [FormatException] if [requestDomain] is invalid
  ///
  /// I really hate that I have to expose this, since I don't want people to
  /// rely on my implementation -it is not meant to be a perfect implementation,
  /// and I have not thought through all edge cases. Some might come up for you
  /// that won't not come up for my use of this method.
  ///
  /// If you use this implementation, you might introduce bugs into your code.
  /// Please just reimplement it yourself. You have been warned.
  ///
  /// More information: RFC6265 Section 5.1.2
  ///             https://datatracker.ietf.org/doc/html/rfc6265#section-5.1.2
  @visibleForTesting
  String toCanonical(String requestDomain) {
    var outLabels = [];
    // Step 1
    final labels = requestDomain.split('.');
    // Step 2
    for (var label in labels) {
      // A. Check if the label is not an NR-LDH label:
      //    NR-LDH := LDH && NOT(R-LDH)
      //            = LDH && NOT(XN-label)
      //    So NOT(NR-LDH) = NOT(LDH && NOT(XN-label))
      //                   = NOT(LDH) || XN-label

      /// Is the current [label] not an NR-LDH label?
      bool notNrLdh = false;

      // First check if it is not an LDH label
      final ldh = RegExp(_ldhLabelRegexString);
      notNrLdh = !ldh.hasMatch(label); // If it is a match, it is LDH

      // Then check if it is an XN-label (short circuit if above was true)
      notNrLdh = notNrLdh || (label[2] == '-' && label[3] == '-');

      // B. If it is not an NR-LDH label, convert it to an A-label
      //    otherwise, keep it as is
      if (!notNrLdh) {
        outLabels.add(label);
      } else {
        // An A-label is the sequence "xn--" followed by the output of the
        // RFC3492 punycode algorithm.
        // Don't catch the possible exception, pass upwards
        outLabels.add("xn--${_toPunyCode(label)}");
      }
    }
    // Step 3
    // 0x2E is just '.' but the RFC refers to it by codepoint so I figured
    // I would too
    return outLabels.join("\x2E");
  }

  /// Runs the RFC 3492 Punycode algorithm on a given [input] string and returns
  /// the result.
  ///
  /// Throws a [FormatException] if the provided string is invalid
  ///
  /// More information: RFC 3492 https://datatracker.ietf.org/doc/html/rfc3492
  String _toPunyCode(String input) {
    // TODO: I should probably implement this myself and actually fail on
    // overflow but oh well
    return punycodeEncode(input);
  }
}

class Cookie {
  String name;
  String value;
  DateTime? expiryTime;
  String domain = "";
  late String path;
  DateTime creationTime;
  DateTime lastAccessTime;
  bool persistent = false;
  bool hostOnly = false;
  bool secure = false;
  bool httpOnly = false;

  Cookie(
    this.name,
    this.value, {
    DateTime? creationTime,
    DateTime? lastAccessTime,
  })  : creationTime = creationTime ?? DateTime.now(),
        lastAccessTime = lastAccessTime ?? DateTime.now();

  @override
  bool operator ==(Object other) {
    return other is Cookie &&
        (name == other.name) &&
        (domain == other.domain) &&
        (path == other.path);
  }

  @override
  int get hashCode => ("$name\\\\\\$domain\\\\\\$path").hashCode;
}
