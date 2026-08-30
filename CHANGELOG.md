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
