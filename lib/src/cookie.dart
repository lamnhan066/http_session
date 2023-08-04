class CookieStore {
  List<Cookie> cookies = [];

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
      cookie.domain = _toCanonical(requestDomain);
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

  bool _domainCompare(String x, String y) {
    throw UnimplementedError();
  }

  String _toCanonical(String requestDomain) {
    throw UnimplementedError();
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
