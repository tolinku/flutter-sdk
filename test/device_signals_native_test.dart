import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tolinku/src/deferred.dart';
import 'package:tolinku/src/device_signals_native.dart';
import 'package:tolinku/src/http_client.dart';

/// Timezone is the signal Dart cannot produce in a form matching can use, and
/// the click side records it on every click, so it is the one worth reading
/// natively. These pin that it survives the trip and that nothing breaks where
/// the channel is absent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.tolinku/device_signals');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answerWith(Object? Function() reply) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getDeviceSignals');
      return reply();
    });
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('readPlatformSignals', () {
    test('returns what the platform reports', () async {
      answerWith(() => {'timezone': 'Asia/Seoul', 'os_version': '17.1'});

      final signals = await readPlatformSignals();
      expect(signals.timezone, 'Asia/Seoul');
      expect(signals.osVersion, '17.1');
    });

    test('an absent channel is not an error', () async {
      // The ordinary case for a host app whose plugin registration predates
      // this channel. Matching skips what it cannot compare, so absent is safe.
      messenger.setMockMethodCallHandler(channel, null);
      expect((await readPlatformSignals()).isEmpty, isTrue);
    });

    test('a throwing channel is not an error', () async {
      answerWith(() => throw PlatformException(code: 'nope'));
      expect((await readPlatformSignals()).isEmpty, isTrue);
    });

    test('blank values are treated as absent, not sent as empty', () async {
      answerWith(() => {'timezone': '   ', 'os_version': ''});

      final signals = await readPlatformSignals();
      expect(signals.timezone, isNull);
      expect(signals.osVersion, isNull);
      expect(signals.toRequestBody(), isEmpty);
    });
  });

  group('claimDeferredLink precedence', () {
    late List<Map<String, dynamic>> sentBodies;

    TolinkuHttpClient client() => TolinkuHttpClient(
          baseUrl: 'https://myapp.tolinku.com',
          apiKey: 'tolk_pub_test',
          httpClient: MockClient((request) async {
            if (request.body.isNotEmpty) {
              sentBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
            }
            return http.Response('{"error":"none"}', 404,
                headers: {'content-type': 'application/json'});
          }),
        );

    Future<String?> noReferrer() async => null;

    setUp(() => sentBodies = []);

    test('platform timezone reaches the claim', () async {
      answerWith(() => {'timezone': 'Asia/Seoul', 'os_version': '17.1'});

      await Deferred(client()).claimDeferredLink(
        appspaceId: 'app123',
        referrerProvider: noReferrer,
        force: true,
      );

      expect(sentBodies.single['timezone'], 'Asia/Seoul');
      expect(sentBodies.single['os_version'], '17.1');
    });

    test('a caller value beats the platform one', () async {
      answerWith(() => {'timezone': 'Asia/Seoul', 'os_version': '17.1'});

      await Deferred(client()).claimDeferredLink(
        appspaceId: 'app123',
        timezone: 'Europe/London',
        referrerProvider: noReferrer,
        force: true,
      );

      final body = sentBodies.single;
      expect(body['timezone'], 'Europe/London');
      expect(body['os_version'], '17.1',
          reason: 'overriding one signal must not drop the others');
    });

    test('claiming still works with no platform channel at all', () async {
      messenger.setMockMethodCallHandler(channel, null);

      await Deferred(client()).claimDeferredLink(
        appspaceId: 'app123',
        language: 'ko-KR',
        screenWidth: 390,
        screenHeight: 844,
        devicePixelRatio: 3.0,
        referrerProvider: noReferrer,
        force: true,
      );

      final body = sentBodies.single;
      expect(body.containsKey('timezone'), isFalse);
      expect(body['language'], 'ko-KR');
      expect(body['screen_width'], 390);
    });
  });
}
