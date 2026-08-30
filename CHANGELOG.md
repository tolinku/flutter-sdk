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
