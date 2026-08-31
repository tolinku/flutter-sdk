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
  });
}
