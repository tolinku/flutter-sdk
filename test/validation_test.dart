import 'package:flutter_test/flutter_test.dart';
import 'package:tolinku/src/validation.dart';

/// An in-app message is rendered in a WebView and can ask the app to navigate.
/// That URL crosses from page content into native code, so the scheme decides
/// whether it opens a web page or does something else entirely.
///
/// The iOS, Android, React Native and web SDKs have applied this rule since they
/// shipped. This package did not until 0.4.1.
void main() {
  group('isSafeUrl', () {
    test('allows the two web schemes', () {
      expect(isSafeUrl('https://example.com/promo'), isTrue);
      expect(isSafeUrl('http://example.com/promo'), isTrue);
    });

    test('is not fooled by the case of the scheme', () {
      expect(isSafeUrl('HTTPS://example.com'), isTrue);
      expect(isSafeUrl('JavaScript:alert(1)'), isFalse);
    });

    test('blocks schemes that do something other than open a page', () {
      expect(isSafeUrl('javascript:alert(1)'), isFalse);
      expect(isSafeUrl('file:///etc/passwd'), isFalse);
      expect(isSafeUrl('content://com.other.app/data'), isFalse);
      expect(isSafeUrl('intent://scan/#Intent;scheme=zxing;end'), isFalse);
      expect(isSafeUrl('data:text/html,<script>alert(1)</script>'), isFalse);
    });

    test('blocks a scheme hidden behind whitespace', () {
      // A prefix check without trimming would pass these through.
      expect(isSafeUrl('  javascript:alert(1)'), isFalse);
      expect(isSafeUrl('\tfile:///etc/passwd'), isFalse);
    });

    test('requires a scheme rather than assuming one', () {
      expect(isSafeUrl('example.com'), isFalse);
      expect(isSafeUrl('//example.com'), isFalse);
      expect(isSafeUrl('/promo'), isFalse);
    });

    test('treats absent or empty as unsafe', () {
      expect(isSafeUrl(null), isFalse);
      expect(isSafeUrl(''), isFalse);
      expect(isSafeUrl('   '), isFalse);
    });

    test('does not throw on a string that will not parse', () {
      // Uri.tryParse returns null rather than raising, and the result is a
      // refusal rather than an exception on a message tap.
      expect(() => isSafeUrl('ht!tp://[bad'), returnsNormally);
      expect(isSafeUrl('ht!tp://[bad'), isFalse);
    });

    test('keeps the query and fragment of an allowed URL irrelevant', () {
      // Only the scheme decides. Nothing after it makes an http URL unsafe here,
      // and the host app is free to apply its own rules on top.
      expect(isSafeUrl('https://example.com/p?a=1#b'), isTrue);
    });

    test('still refuses an app scheme, which is what isNavigableUrl is for', () {
      // This function did not change when the message action path stopped using
      // it. Everything else that allows only a web page still gets that answer.
      expect(isSafeUrl('myapp://order/4821'), isFalse);
      expect(isSafeUrl('market://details?id=com.example'), isFalse);
      expect(isSafeUrl('tel:+18005551234'), isFalse);
    });
  });

  /// A message's call to action is the other half of the same bridge, and it
  /// wants the opposite rule. On a deep linking platform the most natural button
  /// in a message opens a screen in the host app, so an http allowlist dropped
  /// exactly the link the product exists to deliver, without so much as calling
  /// the app's own handler.
  group('isNavigableUrl', () {
    test('allows a custom app scheme', () {
      expect(isNavigableUrl('myapp://order/4821'), isTrue);
      expect(isNavigableUrl('com.example.app://profile'), isTrue);
    });

    test('allows the store and intent schemes', () {
      expect(isNavigableUrl('market://details?id=com.example'), isTrue);
      expect(isNavigableUrl('itms-apps://apps.apple.com/app/id123'), isTrue);
      expect(isNavigableUrl('intent://scan/#Intent;scheme=zxing;end'), isTrue);
    });

    test('allows the two web schemes', () {
      expect(isNavigableUrl('https://example.com/promo'), isTrue);
      expect(isNavigableUrl('http://example.com/promo'), isTrue);
    });

    test('refuses every scheme that can run code or forge an origin', () {
      expect(isNavigableUrl('javascript:alert(1)'), isFalse);
      expect(isNavigableUrl('vbscript:msgbox(1)'), isFalse);
      expect(
        isNavigableUrl('data:text/html,<script>alert(1)</script>'),
        isFalse,
      );
      expect(isNavigableUrl('blob:https://example.com/abc-123'), isFalse);
      expect(isNavigableUrl('file:///etc/passwd'), isFalse);
    });

    test('is not fooled by the case of a denied scheme', () {
      expect(isNavigableUrl('JavaScript:alert(1)'), isFalse);
      expect(isNavigableUrl('JAVASCRIPT:alert(1)'), isFalse);
      expect(isNavigableUrl('FILE:///etc/passwd'), isFalse);
    });

    test('is not fooled by whitespace around or inside a denied scheme', () {
      // Whatever follows the URL ignores tabs and newlines inside it, so
      // "java<TAB>script:" runs. Refusing to parse is not the same as refusing
      // the URL, so the scheme is read the way a URL parser reads it.
      expect(isNavigableUrl('  javascript:alert(1)  '), isFalse);
      expect(isNavigableUrl('java\tscript:alert(1)'), isFalse);
      expect(isNavigableUrl('java\nscript:alert(1)'), isFalse);
      expect(isNavigableUrl('jav\ras\tcript:alert(1)'), isFalse);
      expect(isNavigableUrl('\u0000javascript:alert(1)'), isFalse);
    });

    test('refuses a URL that names no scheme', () {
      // There is no base to resolve a relative URL against on a device.
      expect(isNavigableUrl('example.com'), isFalse);
      expect(isNavigableUrl('//example.com'), isFalse);
      expect(isNavigableUrl('/promo'), isFalse);
      expect(isNavigableUrl('#section'), isFalse);
      expect(isNavigableUrl('1nvalid://x'), isFalse);
    });

    test('treats absent or empty as not navigable', () {
      expect(isNavigableUrl(null), isFalse);
      expect(isNavigableUrl(''), isFalse);
      expect(isNavigableUrl('   '), isFalse);
    });

    test('does not throw on a string that will not parse', () {
      // A refusal on a message tap, never an exception into the host app.
      expect(() => isNavigableUrl('ht!tp://[bad'), returnsNormally);
      expect(isNavigableUrl('myapp://order/[4821'), isTrue);
    });
  });
}
