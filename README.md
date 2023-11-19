# Http Session

If you want to login to a web service and keep comunicate with it, you need to save the session and use it for all the requests. This plugin will help you to do that.

## Features

Create an instance of http and manage the session.

## Usage

Use shared session across the application

```dart
final httpSession = HttpSession.shared;
```

Or create a new session instance

``` dart
final httpSession = HttpSession();
```

Now you can requests any URI and the plugin will automatically save the session.

``` dart
final response = await httpSession.post(url, body: data);
final response = await httpSession.get(url);
```

Clear the current session

``` dart
httpSession.clear();
```

Close the current http and also clear the session

``` dart
httpSession.close();
```

If you would like to access current cookie store directly, you can do so:

``` dart
import 'package:cookie_store/cookie_store.dart';
final List<Cookie> cookies = httpSession.cookieStore;
```

See the [cookie_store documentation](https://github.com/egefeyzioglu/cookie_store)
for details of the `Cookie` class.