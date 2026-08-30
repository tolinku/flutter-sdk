import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tolinku/src/install_referrer.dart';
import 'package:tolinku/src/install_referrer_native.dart';

/// The Play referrer is a shared string: a developer's own campaign parameters
/// sit beside ours, so the token has to be found among the pairs rather than
/// taken as the whole value.
void main() {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  _channelTests();

  group('parseInstallReferrer', () {
    test('reads the token when it is the only pair', () {
      expect(parseInstallReferrer('tolk_token=ABC123'), 'ABC123');
    });

    test("reads the token beside a developer's own parameters", () {
      expect(
        parseInstallReferrer('utm_source=newsletter&tolk_token=ABC123&utm_medium=email'),
        'ABC123',
      );
    });

    test('reads the token when it is last', () {
      expect(parseInstallReferrer('utm_source=x&tolk_token=ABC123'), 'ABC123');
    });

    test('tolerates a percent encoded referrer', () {
      expect(parseInstallReferrer('tolk_token%3DABC123'), 'ABC123');
    });

    test('returns null for an organic install', () {
      expect(parseInstallReferrer('utm_source=google-play&utm_medium=organic'), isNull);
    });

    test('returns null for nothing at all', () {
      expect(parseInstallReferrer(null), isNull);
      expect(parseInstallReferrer(''), isNull);
      expect(parseInstallReferrer('   '), isNull);
    });

    test('returns null rather than an empty token', () {
      expect(parseInstallReferrer('tolk_token='), isNull);
      expect(parseInstallReferrer('utm_source=x&tolk_token=&utm_medium=y'), isNull);
    });

    test('does not mistake a similarly named parameter for ours', () {
      expect(parseInstallReferrer('my_tolk_token=NOPE'), isNull);
      expect(parseInstallReferrer('tolk_token_other=NOPE'), isNull);
    });

    test('survives malformed percent encoding', () {
      expect(parseInstallReferrer('tolk_token=ABC%ZZ'), 'ABC%ZZ');
    });
  });
}

/// The plugin channel. Verified against the Kotlin side, which answers
/// `getInstallReferrer` on `com.tolinku/install_referrer` with the raw referrer
/// string or null.
void _channelTests() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.tolinku/install_referrer');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group('readInstallReferrer', () {
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('returns the referrer the platform reports', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getInstallReferrer');
        return 'utm_source=x&tolk_token=FROM_PLAY';
      });
      expect(await readInstallReferrer(), 'utm_source=x&tolk_token=FROM_PLAY');
    });

    test('returns null when there is nothing to report', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      expect(await readInstallReferrer(), isNull);
    });

    test('returns null rather than throwing when the plugin is missing', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException('no implementation');
      });
      expect(await readInstallReferrer(), isNull);
    });
  });
}
