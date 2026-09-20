import 'package:flutter_test/flutter_test.dart';
import 'package:tolinku/src/message_presenter.dart';

/// The decision the in-app message bridge makes about a `navigate` action,
/// tested apart from the dialog that makes it.
///
/// The dialog needs a WebView and a live BuildContext, so nothing in it runs
/// under `flutter test`. That left the rule it applies asserted nowhere: the
/// call could be swapped back to the http-only allowlist, killing every message
/// that links into the host app, and the suite stayed green. The decision is
/// lifted out of the handler so a revert has somewhere to fail.
void main() {
  group('shouldFollowMessageAction', () {
    test('follows a call to action that links into the host app', () {
      // The defect. On a deep linking product this is the ordinary case, and
      // the allowlist dropped it before onAction was ever called.
      expect(
        TolinkuMessagePresenter.shouldFollowMessageAction('myapp://order/4821'),
        isTrue,
      );
      expect(
        TolinkuMessagePresenter.shouldFollowMessageAction(
          'my_app://order/4821',
        ),
        isTrue,
      );
      expect(
        TolinkuMessagePresenter.shouldFollowMessageAction(
          'market://details?id=com.example',
        ),
        isTrue,
      );
      expect(
        TolinkuMessagePresenter.shouldFollowMessageAction('tel:+18005550199'),
        isTrue,
      );
    });

    test('still follows a plain web link', () {
      expect(
        TolinkuMessagePresenter.shouldFollowMessageAction(
          'https://example.com/promo',
        ),
        isTrue,
      );
      expect(
        TolinkuMessagePresenter.shouldFollowMessageAction(
          'http://example.com/promo',
        ),
        isTrue,
      );
    });

    test('refuses a call to action that runs code or forges an origin', () {
      expect(
        TolinkuMessagePresenter.shouldFollowMessageAction('javascript:alert(1)'),
        isFalse,
      );
      expect(
        TolinkuMessagePresenter.shouldFollowMessageAction(
          'java\tscript:alert(1)',
        ),
        isFalse,
      );
      expect(
        TolinkuMessagePresenter.shouldFollowMessageAction(
          'data:text/html,<script>alert(1)</script>',
        ),
        isFalse,
      );
      expect(
        TolinkuMessagePresenter.shouldFollowMessageAction('file:///etc/passwd'),
        isFalse,
      );
    });

    test('refuses an action with nothing to resolve', () {
      // A relative URL has no base to resolve against on a device.
      expect(TolinkuMessagePresenter.shouldFollowMessageAction(''), isFalse);
      expect(
        TolinkuMessagePresenter.shouldFollowMessageAction('/promo'),
        isFalse,
      );
      expect(
        TolinkuMessagePresenter.shouldFollowMessageAction('example.com'),
        isFalse,
      );
    });
  });
}
