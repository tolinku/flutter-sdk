# tolinku

[![pub package](https://img.shields.io/pub/v/tolinku.svg)](https://pub.dev/packages/tolinku)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

The official [Tolinku](https://tolinku.com) SDK for Flutter. Add deep linking, analytics, referral tracking, deferred deep links, and in-app messages to your Flutter app.

## What is Tolinku?

[Tolinku](https://tolinku.com) is a deep linking platform for mobile and web apps. It handles Universal Links (iOS), App Links (Android), deferred deep linking, referral programs, analytics, and smart banners. Tolinku provides a complete toolkit for user acquisition, attribution, and engagement across platforms.

Get your API key at [tolinku.com](https://tolinku.com) and check out the [documentation](https://tolinku.com/docs) to get started.

## Installation

```bash
flutter pub add tolinku
```

**Requirements:** Dart SDK >=3.0.0, Flutter >=3.10.0

## Quick Start

```dart
import 'package:tolinku/tolinku.dart';

// Configure the SDK (typically in main() or initState)
Tolinku.configure(apiKey: 'tolk_pub_your_api_key');

// Identify a user
Tolinku.instance.setUserId('user_123');

// Track a custom event
await Tolinku.instance.track('purchase', properties: {'plan': 'growth'});
```

## Features

### Analytics

Track custom events with automatic batching. Events are queued and sent in batches of 10, or every 5 seconds. For reliable delivery, call `flush()` when your app moves to the background using `WidgetsBindingObserver`.

```dart
await Tolinku.instance.track('signup_completed', properties: {
  'source': 'landing_page',
  'trial': true,
});

// Flush queued events immediately
await Tolinku.instance.flush();
```

**Background flush with WidgetsBindingObserver:**

```dart
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      Tolinku.instance.flush();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
```

### Referrals

Create and manage referral programs with leaderboards and reward tracking.

```dart
final referrals = Tolinku.instance.referrals;

// Create a referral
final result = await referrals.create(userId: 'user_123', userName: 'Alice');
final code = result.referralCode;

// Look up a referral
final details = await referrals.get(code);

// Complete a referral
final completion = await referrals.complete(
  code: code,
  referredUserId: 'user_456',
  referredUserName: 'Bob',
);

// Update milestone
final milestone = await referrals.milestone(
  code: code,
  milestone: 'first_purchase',
);

// Claim reward
final reward = await referrals.claimReward(code: code);

// Fetch leaderboard
final entries = await referrals.leaderboard(limit: 10);
```

### Deferred Deep Links

Recover deep link context for users who installed your app after clicking a link. Deferred deep linking lets you route users to specific content even when the app was not installed at the time of the click.

```dart
final deferred = Tolinku.instance.deferred;

// Claim by referrer token
final link = await deferred.claim(token: 'abc123');
if (link != null) {
  print(link.deepLinkPath); // e.g. "/merchant/xyz"
}

// Claim by device signal matching
final link = await deferred.claimBySignals(
  appspaceId: 'your_appspace_id',
);
```

### Deep Link Parsing

Parse incoming deep links with a utility method (no SDK configuration required).

```dart
final result = Tolinku.parseDeepLink('https://example.com/merchant/xyz?ref=abc');
print(result.path);        // "/merchant/xyz"
print(result.queryParams); // {"ref": "abc"}
```

### In-App Messages

Display server-configured messages as full-screen dialogs using `TolinkuMessagePresenter`. Create and manage messages from the Tolinku dashboard without shipping app updates.

```dart
// Show the highest-priority message matching a trigger
await Tolinku.instance.messages.show(
  context,
  trigger: 'milestone',
  onAction: (action) => print('Button tapped: $action'),
  onDismiss: () => print('Message dismissed'),
);
```

You can also fetch and present messages manually:

```dart
final messages = await Tolinku.instance.messages.fetch(trigger: 'milestone');
if (messages.isNotEmpty) {
  final message = messages.first;
  final token = await Tolinku.instance.messages.renderToken(message.id);
  await TolinkuMessagePresenter.show(
    context,
    message,
    baseUrl: 'https://api.tolinku.com',
    renderToken: token,
  );
}
```

## Configuration Options

```dart
// Full configuration
Tolinku.configure(
  apiKey: 'tolk_pub_your_api_key',     // Required. Your Tolinku publishable API key.
  baseUrl: 'https://api.tolinku.com', // Optional. API base URL.
  debug: false,                        // Optional. Enable debug logging.
);

// Set user identity at any time
Tolinku.instance.setUserId('user_123');

// Dispose the SDK when done
await Tolinku.instance.dispose();
```

## API Reference

### `Tolinku`

| Method | Description |
|--------|-------------|
| `configure(apiKey:, baseUrl:, debug:)` | Initialize the SDK (static) |
| `instance` | Access the configured singleton (static) |
| `isConfigured` | Check if the SDK is initialized (static) |
| `setUserId(userId)` | Set or clear the current user ID |
| `track(eventType, properties:)` | Track a custom event |
| `flush()` | Flush queued analytics events |
| `parseDeepLink(uri)` | Parse a deep link URI (static) |
| `dispose()` | Release all resources |

### `tolinku.referrals`

| Method | Description |
|--------|-------------|
| `create(userId:, metadata:, userName:)` | Create a new referral |
| `get(code)` | Get referral details by code |
| `complete(code:, referredUserId:, milestone:, referredUserName:)` | Mark a referral as converted |
| `milestone(code:, milestone:)` | Update a referral milestone |
| `claimReward(code:)` | Claim a referral reward |
| `leaderboard(limit:)` | Fetch the referral leaderboard |

### `tolinku.deferred`

| Method | Description |
|--------|-------------|
| `claim(token:)` | Claim a deferred link by token |
| `claimBySignals(appspaceId:, ...)` | Claim a deferred link by device signals |

### `tolinku.messages`

| Method | Description |
|--------|-------------|
| `fetch(trigger:)` | Fetch messages with optional trigger filter |
| `renderToken(messageId)` | Get a render token for a message |
| `show(context, trigger:, onAction:, onDismiss:)` | Show the highest-priority message |

## Documentation

Full documentation is available at [tolinku.com/docs](https://tolinku.com/docs).

## Community

- [GitHub](https://github.com/tolinku)
- [X (Twitter)](https://x.com/trytolinku)
- [Facebook](https://facebook.com/trytolinku)
- [Instagram](https://www.instagram.com/trytolinku/)

## License

MIT
