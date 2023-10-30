import 'package:punycode/punycode.dart';
import 'package:meta/meta.dart';

class CookieStore {
  /// Regex string that matches an LDH Label. Matches the entire string only.
  ///
  /// Would have private'd this but I want it accessible for testing. Just write
  /// your own regex or copy/paste from the source file. This is not in the
  /// package's public API and can change or disappear without notice. Also
  /// like, JFC don't introduce a dependency for a string constant.
  ///
  /// LDH Label format defined in RFC 5890 Section 2.3.1:
  ///
  /// ASCII uppercase, lowercase, or numbers. Dashes allowed other than in the
  /// first and last position. Complete string must not be longer than
  /// 63 octets.
  ///
  /// More information:
  ///   https://datatracker.ietf.org/doc/html/rfc5890#section-2.3.1
  @visibleForTesting
  static const String ldhLabelRegexString =
      r'(^[A-Za-z0-9][A-Za-z0-9-]{0,61}[A-Za-z0-9]$)|(^[A-Za-z0-9]$)';

  List<Cookie> _cookies = [];

  List<Cookie> get cookies {
    for (var cookie in _cookies) {
      if (cookie.expiryTime != null &&
          cookie.expiryTime!.isBefore(DateTime.now())) {
        _cookies.remove(cookie);
      }
    }
    return _cookies;
  }

  set cookies(List<Cookie> value) {
    _cookies = value;
  }

  /// Call this when the session ends (defined by you,) to clear cookies that
  /// were not set as persistent.
  void onSessionEnded() {
    for (Cookie cookie in _cookies) {
      if (!cookie.persistent) _cookies.remove(cookie);
    }
  }

  /// Reduce the cookie store to [targetNumCookies] or smaller. Set [force]
  /// if you want to delete unexpired or non-excessive cookies.
  ///
  /// "Excessive cookies" means cookies that share a domain with more than
  /// [numExcessive] number of cookies.
  ///
  /// Returns true if the main [cookies] array could be reduced to the requested
  /// size, false if not. If [force] is set, the method will never return false.
  bool reduceSize(int targetNumCookies, bool force, {int numExcessive = 75}) {
    // Use getter to clear expired cookies
    var cookies = this.cookies;
    int currentNumCookies = cookies.length;
    if (currentNumCookies <= targetNumCookies) return true;
    // Then, check for excessive cookies
    Map<String, List<Cookie>> cookiesPerDomain = {};
    for (var cookie in cookies) {
      bool found = false;
      cookiesPerDomain.forEach((domain, cookiesForDomain) {
        // If we've already seen cookies domain matching the current cookie's
        // domain (or vice-versa), keep them together.
        if (_domainMatches(cookie.domain, cookiesForDomain[0].domain) ||
            _domainMatches(cookiesForDomain[0].domain, cookie.domain)) {
          cookiesPerDomain[domain]!.add(cookie);
          found = true;
        }
      });
      // Otherwise, start a new pile
      if (!found) cookiesPerDomain[cookie.domain] = [cookie];
    }
    // If any are excessive, delete cookies from that domain
    for (var cookiesForThisDomain in cookiesPerDomain.entries) {
      if (cookiesForThisDomain.value.length > numExcessive) {
        for (var cookie in cookiesForThisDomain.value) {
          _cookies.remove(cookie);
        }
      }
    }

    // Check if we managed to reduce to the requested quantity. If we did,
    // return true.
    // If we didn't and force is set, delete starting from the oldest cookie
    // until we reach the number then return true.
    // If force isn't set, return false.
    if (!force) return _cookies.length <= targetNumCookies;
    _cookies.sort(
        (Cookie x, Cookie y) => x.lastAccessTime.compareTo(y.lastAccessTime));
    int numLeft = _cookies.length - targetNumCookies;
    for (var cookie in _cookies) {
      _cookies.remove(cookie);
      if (--numLeft == 0) break;
    }
    return true;
  }

  /// Updates the cookie store with the given Set-Cookie header
  /// ([setCookieHeader]), for the given [requestDomain] and [requestPath].
  /// Returns true if the cookie was accepted, false if not.
  ///
  /// This is the method you should be using if you want to treat this library
  /// as a black box and have it store cookies for you, along with
  /// [getCookiesForRequest].
  ///
  /// May throw a [FormatException] if [setCookieHeader] is malformed
  ///
  /// Strip the header name, colon and space (the "Set-Cookie: " portion) from
  /// the header before passing it to this function. This is for cases where the
  /// header name and value are already separated before the user needs to call
  /// this method. It wouldn't make sense to spend time reattaching the pieces
  /// for the name to immediately be stripped here.
  ///
  /// For more information:
  ///   https://datatracker.ietf.org/doc/html/rfc6265
  bool updateCookies(
      String setCookieHeader, String requestDomain, String requestPath) {
    String name, value;
    Map<String, String> attrs;
    (name, value, attrs) = parseSetCookie(setCookieHeader);
    return _processCookie(name, value, attrs, requestDomain, requestPath);
  }

  /// Get the cookies you need to submit for a given [requestDomain] and a
  /// given [requestPath].
  ///
  /// This is the method you should be using if you want to treat this library
  /// as a black box and have it store cookies for you, along with
  /// [updateCookies].
  List<Cookie> getCookiesForRequest(String requestDomain, String requestPath) {
    List<Cookie> ret = [];
    for (Cookie cookie in cookies) {
      if (_domainMatches(cookie.domain, requestDomain) &&
          pathMatches(cookie.path, requestPath)) {
        ret.add(cookie);
      }
    }
    return ret;
  }

  /// Builds a Cookie header containing the [cookies] provided. Does not check
  /// anything about whether the cookies should be sent.
  ///
  /// Does not include the header name or the semicolon (the "Cookie: " part)
  /// This is for cases where the header name and value are needed separately.
  /// It wouldn't make sense to add the header name for it to be immediately
  /// removed by the caller.
  static String buildCookieHeader(List<Cookie> cookies) {
    List<String> cookieStrs = [];
    for (Cookie cookie in cookies) {
      cookieStrs.add("${cookie.name}=${cookie.value}");
    }
    return cookieStrs.join(";");
  }

  /// Compares the two given paths, [requestPath] and [cookiePath], using the
  /// algorithm given in section 5.1.4 of RFC 6265.
  ///
  /// They must first be converted to default-path form using the algorithm in
  /// the same section.
  ///
  /// WARNING: pathMatches(x,y) != pathMatches(y,x) in some cases.
  ///
  /// For more information:
  ///   https://datatracker.ietf.org/doc/html/rfc6265#section-5.1.2
  bool pathMatches(String requestPath, String cookiePath) {
    // If the paths are identical, they match
    if (requestPath == cookiePath) return true;
    // If the cookie path is a prefix of the request path:
    if (requestPath.startsWith(RegExp.escape(cookiePath))) {
      // They match if the cookie path ends with a '/', or
      if (cookiePath.endsWith("/")) return true;
      // If the first character in the request path that isn't in the cookie
      // path is a '/'
      if (requestPath[cookiePath.length] == "\x2F") return true; // 0x2F = '/'
    }
    // Otherwise, they do not match
    return false;
  }

  /// Parse the Set-Cookie header value and return the cookie details. Follows
  /// the algorithm in RFC6265 section 5.2.
  ///
  /// [name] is the cookie name, [value] is the cookie value, and [attrs] are
  /// attributes in key-value form, lowercase.
  ///
  /// May throw a [FormatException] if [header] is malformed
  ///
  /// Strip the header name, colon and space (the "Set-Cookie: " portion) from
  /// the header before passing it to this function. This is for cases where the
  /// header name and value are already separated before the user needs to call
  /// this method. It wouldn't make sense to spend time reattaching the pieces
  /// for the name to immediately be stripped here.
  ///
  /// For more information:
  ///   https://datatracker.ietf.org/doc/html/rfc6265#section-5.1.2
  (
    String name,
    String value,
    Map<String, String> attrs,
  ) parseSetCookie(String header) {
    // set-cookie-string portion:
    // Step 1

    int firstSemicolon = header.indexOf("\x3B"); // 0x3B = ';'
    String nameValuePair;
    String unparsedAttributes;
    if (firstSemicolon != -1) {
      // If the set-cookie-string contains a semicolon:
      // Split up the set-cookie-string
      nameValuePair = header.substring(0, firstSemicolon);
      unparsedAttributes =
          header.substring(firstSemicolon); // Yes, include the semicolon
    } else {
      // Otherwise:
      // Everything is name-value-pair
      nameValuePair = header;
      unparsedAttributes = "";
    }

    // Step 2

    // The value starts one after this index
    int valueAfter = nameValuePair.indexOf("\x3d"); // 0x3D = '='
    if (valueAfter == -1) {
      throw FormatException("name-value-pair did not contain an equals sign");
    }

    // Step 3

    // If the name is empty, don't run substring (it will throw)
    String name =
        (valueAfter == 0) ? "" : nameValuePair.substring(0, valueAfter);
    // Same with the value
    String value = (valueAfter == nameValuePair.length - 1)
        ? ""
        : nameValuePair.substring(valueAfter + 1);

    // Step 4
    name = name.trim();
    value = value.trim();

    // Step 5
    if (name.isEmpty) {
      throw FormatException("Cookie name was empty");
    }

    // unparsed-attributes section
    Map<String, String> attrs = {};
    // Step 1
    while (unparsedAttributes.isNotEmpty) {
      // Step 2 (that character should be the semicolon)
      unparsedAttributes = unparsedAttributes.substring(1);
      // Step 3
      String cookieAv;
      int semiColonAt = unparsedAttributes.indexOf("\x3B"); // 0x3B = ';'
      if (semiColonAt == -1) {
        // If there isn't another section left, consume the entire thing
        cookieAv = unparsedAttributes;
        unparsedAttributes = "";
      } else {
        // Otherwise, consume the next section
        cookieAv = unparsedAttributes.substring(0, semiColonAt);
        unparsedAttributes = unparsedAttributes.substring(semiColonAt);
      }
      // Step 4
      int equalsAt = cookieAv.indexOf("\x3D"); // 0x3D = '='
      String attrName, attrValue;
      if (equalsAt == -1) {
        attrName = cookieAv;
        attrValue = "";
      } else {
        // If the attribute name is empty, don't run substring (it will throw)
        attrName = (equalsAt == 0) ? "" : cookieAv.substring(0, equalsAt);
        // Same with the attribute value
        attrValue = (equalsAt == cookieAv.length)
            ? ""
            : cookieAv.substring(equalsAt + 1);
      }
      // Step 5
      attrs[attrName.trim()] = attrValue.trim();
      // Step 6 not done in this method (see [_processCookie])
    } // Step 7

    return (name, value, attrs);
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
      if (!_domainMatches(cookie.domain, requestDomain)) {
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
    // Apply section 5.1.4 to fix the path attribute
    // 5.1.4 Step 1 is done by the caller
    // 5.1.4 Step 2
    if (cookie.path.isEmpty || !cookie.path.startsWith("/")) {
      cookie.path = "/";
    }
    // 5.1.4 Step 3
    if (cookie.path.allMatches("/").length == 1) {
      cookie.path = "/";
    }
    // 5.1.4 Step 4
    if (cookie.path != "/") {
      // Up to but not including the last "/" in the current cookie path
      cookie.path = cookie.path.substring(0, cookie.path.lastIndexOf("/"));
    }
    // 5.1.4 done

    // Step 8
    cookie.secure = attrs.containsKey("secure");

    // Step 9
    cookie.secure = attrs.containsKey("httponly");

    // Step 10
    // Non-HTTP APIs are not supported, skip

    // Step 11
    // Access the private variable directly to be able to change it
    _cookies.remove(cookie);
    _cookies.add(cookie);
    return true;
  }

  /// Tests whether a given [string] domain-matches a given [domainString] as
  /// described in RFC6265 section 5.1.3.
  ///
  /// WARNING: domainMatches(x,y) != domainMatches(y,x) in some cases.
  ///
  /// Returns false if one or more of the domains are invalid
  bool _domainMatches(String string, String domainString) {
    try {
      // If they are exactly equal, return true
      if (toCanonical(string) == toCanonical(domainString)) return true;
    } catch (e) {
      // If either are invalid, return false
      return false;
    }
    // Otherwise, see if they domain-match the other way.
    // All of the following must hold:
    // * domainString is a suffix of the string
    bool match = string.endsWith(domainString);
    // * The last character of the string that is not included in the domain
    //   string is '.'.
    int indexAfterDomainString = string.length - domainString.length - 1;
    if (indexAfterDomainString < 0) return false;
    match &= string[indexAfterDomainString] == "\x2E"; // 0x2E = '.'
    // * The string is a host name (so not an IP address)
    bool notIpAddr = false;
    try {
      Uri.parseIPv4Address(string);
    } on FormatException {
      notIpAddr = true;
    }
    try {
      Uri.parseIPv6Address(string);
    } on FormatException {
      notIpAddr = true;
    }
    match &= notIpAddr;
    // If all of them were true, return true. Otherwise return false.
    return match;
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
      final ldh = RegExp(ldhLabelRegexString);
      notNrLdh = !ldh.hasMatch(label); // If it is a match, it is LDH

      // Then check if it is an XN-label (short circuit if above was true)
      notNrLdh = notNrLdh ||
          (label.length >= 4 && (label[2] == '-' && label[3] == '-'));

      // B. If it is not an NR-LDH label, convert it to an A-label
      //    otherwise, keep it as is
      if (!notNrLdh) {
        outLabels.add(label);
      } else {
        // An A-label is the sequence "xn--" followed by the output of the
        // RFC3492 punycode algorithm.
        // Don't catch the possible exception, pass upwards
        outLabels.add("xn--${_toPunyCode(label).toLowerCase()}");
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
