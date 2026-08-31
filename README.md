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

### Ecommerce

Track purchases, cart activity, and product events with built-in revenue analytics. Available on paid plans.

```dart
Tolinku.instance.setUserId('user_123');

// Track a product view
await Tolinku.instance.ecommerce.viewItem(
  items: [TolinkuItem(itemId: 'sku_1', itemName: 'T-Shirt', price: 24.99)],
);

// Track a purchase
await Tolinku.instance.ecommerce.purchase(
  transactionId: 'order_456',
  revenue: 49.99,
  currency: 'USD',
  items: [TolinkuItem(itemId: 'sku_1', itemName: 'T-Shirt', price: 24.99, quantity: 2)],
);

// Flush ecommerce events
await Tolinku.instance.ecommerce.flush();
```

The SDK supports 13 event types covering the full shopping journey. Cart IDs are managed automatically via `SharedPreferences` and cleared after purchase. Add `Tolinku.instance.ecommerce.flush()` to your `WidgetsBindingObserver` for background flushing.

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
final media = MediaQuery.of(context);

final link = await deferred.claimBySignals(
  appspaceId: '64f0a1b2c3d4e5f60718',   // your Appspace ID, from the dashboard under Settings
  timezone: 'Asia/Seoul',                // IANA name, not an abbreviation like KST
  language: 'ko-KR',                     // BCP-47, hyphen not underscore
  screenWidth: media.size.width.round(), // logical pixels
  screenHeight: media.size.height.round(),
  devicePixelRatio: media.devicePixelRatio,
  osVersion: Platform.operatingSystemVersion,
);
```

On Android the Play Install Referrer is the deterministic mechanism: a Tolinku
link attaches a token to the store URL, Play keeps it through the install, and
this SDK reads it back on first launch. It names the exact click, survives for
days, and does not depend on the network the device was on. Device signals are
the fallback, and the only option on iOS, where no equivalent exists.

There are two supported ways to claim, and neither is going away. They differ
only in how much the SDK does for you, not in how well they match.

**`claimDeferredLink()`** tries the referrer, falls back to signals, reads the
device signals it can, and remembers that it asked:

```dart
// Referrer first, device signals as the fallback.
final link = await tolinku.deferred.claimDeferredLink(
  appspaceId: '64f0a1b2c3d4e5f60718',
);
if (link != null) routeTo(link.deepLinkPath);
```

**`claimBySignals()`** goes straight to signal matching, leaving the mechanism
and the claim-once bookkeeping to you:

```dart
final link = await tolinku.deferred.claimBySignals(
  appspaceId: '64f0a1b2c3d4e5f60718',
);
```

Both collect the device signals themselves, so neither needs anything beyond the
Appspace ID. Both also accept the signals as parameters, and anything you pass is
used ahead of what is collected:

```dart
final link = await tolinku.deferred.claimBySignals(
  appspaceId: '64f0a1b2c3d4e5f60718',
  timezone: 'Asia/Seoul',   // used instead of the collected value
);
```

Choosing between them costs you nothing in control.

It collects all four signals matching actually compares, so on iOS you can call
it with nothing but the Appspace ID and still get a full match:

| Signal | Read from |
|---|---|
| `language`, `screenWidth`, `screenHeight`, `devicePixelRatio` | Dart |
| `timezone` | the bundled Android and iOS plugins |

Timezone is read natively because Dart cannot express it in the form matching
compares against: matching wants an IANA identifier such as `Asia/Seoul`, which
is what the browser records at click time, and `DateTime.now().timeZoneName`
gives only `KST`. Sending the abbreviation would be worse than sending nothing,
since an absent signal is skipped while a present one that disagrees counts as a
failed comparison. `osVersion` is read the same way and sent for completeness,
though the click side does not currently record it.

If you have better values from elsewhere, pass them and they win.

Call it once on first launch. Calling again is safe, but a claim is consumed the
first time it succeeds, so a second call returns nothing.

`appspaceId` is your Appspace ID, not your subdomain or slug. Copy it from the dashboard
under **Integrate** or **Settings**.

This SDK is pure Dart and cannot read device info itself, so the signals above are supplied
by the caller. Matching needs at least two of them to agree, and `devicePixelRatio` is the
strongest of them, so pass as many as you can.

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

### `tolinku.ecommerce`

| Method | Description |
|--------|-------------|
| `viewItem(items:)` | Track a product view |
| `addToCart(items:)` | Track item added to cart |
| `removeFromCart(items:)` | Track item removed from cart |
| `addToWishlist(items:)` | Track item added to wishlist |
| `viewCart()` | Track cart view |
| `addPaymentInfo()` | Track payment info entered |
| `beginCheckout()` | Track checkout started |
| `purchase(transactionId:, revenue:, currency:, items:)` | Track a purchase |
| `refund(transactionId:, revenue:)` | Track a refund |
| `search(searchTerm:)` | Track a product search |
| `share(itemId:)` | Track a product share |
| `rate(itemId:, rating:, maxRating:)` | Track a product rating |
| `spendCredits(revenue:, currency:)` | Track loyalty credits spent |
| `flush()` | Send all queued ecommerce events |

### `tolinku.deferred`

| Method | Description |
|--------|-------------|
| `claimDeferredLink(appspaceId:, ...signals, referrerProvider:, force:)` | Claim via the Play Install Referrer, falling back to device signals |
| `claimBySignals(appspaceId:, timezone:, language:, screenWidth:, screenHeight:, devicePixelRatio:, osVersion:)` | Claim a deferred link by device signals |
| `claimByToken(token:, appspaceId:)` | Claim a deferred link by token |
| `claim(token:, appspaceId:)` | Alias of `claimByToken` |

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
