## 0.4.1

### Fixed

- `claimDeferredLink()` could never match on device signals. It called
  `claimBySignals()` with the Appspace ID and nothing else, and matching only
  compares fields present on both the click and the claim, so every candidate
  was incomparable and the fallback returned `null` every time. On Android the
  Play Install Referrer usually covered it. On iOS, where signals are the only
  mechanism, the method never matched at all.

  It now collects and sends every signal matching compares, and accepts
  `timezone`, `language`, `screenWidth`, `screenHeight`, `devicePixelRatio` and
  `osVersion` to override any of them. Upgrading is enough; nothing needs
  passing.

- `claimBySignals()` collects the device signals too, rather than sending only
  what the caller passed. Called with just an Appspace ID it sent a claim with
  nothing to compare, which could never match, and it was the only Tolinku SDK
  that behaved that way: the iOS, Android, React Native and web SDKs all collect
  their own. Signals you pass still take precedence, so an existing call that
  supplies all of them behaves exactly as before.

### Added

- iOS is now a plugin platform. Deferred linking on iOS has no equivalent of the
  Play Install Referrer, so signal matching is the entire mechanism there, and
  the timezone is the one signal Dart cannot express in the form matching
  compares against: it offers `KST` where matching wants `Asia/Seoul`, which is
  what the browser records at click time. A signal that is absent is skipped,
  while one that is present and disagrees counts as a failed comparison, so it
  is read natively rather than approximated. Android reports it the same way.

  An iOS build now compiles a small Swift file and runs `pod install`. Both are
  handled by the normal Flutter build.

- `collectAllDeviceSignals()`, `readPlatformSignals()` and `DeviceSignals` are
  exported, for apps that want to see or adjust what would be sent.

- `isSafeUrl()` is exported, and in-app message navigation now uses it. A message
  is rendered in a WebView and can ask the app to navigate, so the URL it names
  crosses from page content into native code. Only `http` and `https` are passed
  on; a `javascript:`, `file:`, `content:` or `intent:` URL is blocked and logged
  in debug mode. The iOS, Android, React Native and web SDKs already applied this
  rule, and this package was the only one that did not.

### Changed

- `claimBySignals()` and `claimDeferredLink()` are documented as equal choices
  rather than one being preferred. Both are supported and neither is deprecated:
  `claimBySignals()` takes the signals you pass and leaves the mechanism and the
  claim-once bookkeeping to you, `claimDeferredLink()` handles all three.

## 0.4.0

### Added

- `claimDeferredLink()` recovers the link that led to an install, asking the Play
  Install Referrer first and falling back to device signal matching. Call it once
  on first launch instead of choosing between `claim` and `claimBySignals`
  yourself.
- The package is now a Flutter plugin on Android and reads the Play Install
  Referrer itself, so nothing extra needs installing. Android links already
  carried a referrer token to the store and nothing read it back, which left
  every install matched only by device signals: probabilistic, and expiring two
  hours after the click. The platform is declared as Android alone, so an
  iOS-only app never builds it.

- `destroy()` tears the SDK down. The name every Tolinku SDK uses for this.
  `dispose()` does the same thing and still works, and is also the ordinary Dart
  name for it, so it is not going anywhere soon. `destroy()` exists so an app
  sharing code across platforms can call one name everywhere.

- `claimByToken()` as a second name for `claim()`. It is what the Android, iOS,
  React Native and web SDKs call the same operation, so code moved between them
  no longer fails on a name that exists everywhere except here. Both work and
  neither is deprecated: `claim()` is what 0.3.0 shipped, and it is intended for
  deprecation only once moving off it is a one-line change rather than a
  surprise.

- `claimDeferredLink()` runs once per install and remembers it, so calling it on
  every launch costs nothing after the first. Only a real answer is remembered:
  a dropped request leaves the next launch free to try again rather than
  spending the install's one chance at attribution on a bad connection.

- Token claims now name their Appspace. It narrows what a token may claim, never
  widens it, and it is what lets a failed claim be counted: the default host
  resolves to no Appspace, so a miss previously belonged to nobody and the
  reported referrer match rate would have read 100% regardless.

### Fixed

- The SDK version in the `User-Agent` reported 0.1.0 through two releases. A test
  now fails if the constant drifts from `pubspec.yaml`.

## 0.3.0

- `claimBySignals` now explains itself when it returns null. Previously a wrong
  `appspaceId` produced an indistinguishable null, which was the whole cause of a
  reported multi-day integration failure. Debug logging now names the likely cause,
  and non-404 responses (notably the 403 for a wrong `appspaceId`) are logged before
  being rethrown.
- `appspaceId` is your Appspace ID from the dashboard under Settings, not your subdomain
  or slug. Sending the slug now produces an explicit error rather than a silent null.
- `claimBySignals` accepts `devicePixelRatio` and `osVersion`. Pass `devicePixelRatio` if
  you can: it separates devices that report the same logical screen size and is the
  strongest signal available to matching.

## 0.2.0

- Ecommerce analytics module with 13 event types (viewItem, addToCart, purchase, refund, etc.).
- Automatic cart ID lifecycle management via SharedPreferences.
- Event batching (10 events or 5-second timer) with manual flush support.
- Updated dependencies.

## 0.1.0

- Initial release.
- Analytics event tracking.
- Referral creation, completion, milestones, leaderboard, and reward claiming.
- Deferred deep link claiming (by token and by signals).
- In-app message fetching.
