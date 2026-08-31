import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tolinku/src/device_signals.dart';
import 'package:tolinku/src/deferred.dart';
import 'package:tolinku/src/http_client.dart';

/// 0.4.0 shipped [Deferred.claimDeferredLink] calling `claimBySignals` with the
/// appspace ID and nothing else. Server-side matching only compares fields
/// present on both the click and the claim, and treats "nothing comparable" as
/// no match, so the signals fallback could never succeed. On Android a referrer
/// usually covered it. On iOS, where signals are the only mechanism, the method
/// returned null every time.
///
/// These assert on the request body rather than on the return value, because the
/// bug was invisible from the outside: a broken claim and a genuine "no link is
/// waiting" both come back as null.
void main() {
  late List<Map<String, dynamic>> sentBodies;

  TolinkuHttpClient client({int status = 404, String body = '{}'}) {
    return TolinkuHttpClient(
      baseUrl: 'https://myapp.tolinku.com',
      apiKey: 'tolk_pub_test',
      httpClient: MockClient((request) async {
        if (request.body.isNotEmpty) {
          sentBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        }
        return http.Response(
          body,
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }

  /// No referrer available, so the call goes straight to the signals fallback.
  Future<String?> noReferrer() async => null;

  setUp(() => sentBodies = []);

  group('claimDeferredLink carries signals', () {
    test('sends more than just the appspace ID', () async {
      await Deferred(client()).claimDeferredLink(
        appspaceId: 'app123',
        timezone: 'Asia/Seoul',
        language: 'ko-KR',
        screenWidth: 390,
        screenHeight: 844,
        devicePixelRatio: 3.0,
        osVersion: '17.1',
        referrerProvider: noReferrer,
        force: true,
      );

      final body = sentBodies.single;
      expect(
        body.keys,
        isNot(equals(['appspace_id'])),
        reason: 'a claim with no signals can never match',
      );
    });

    test('forwards every caller-supplied signal verbatim', () async {
      await Deferred(client()).claimDeferredLink(
        appspaceId: 'app123',
        timezone: 'Asia/Seoul',
        language: 'ko-KR',
        screenWidth: 390,
        screenHeight: 844,
        devicePixelRatio: 3.0,
        osVersion: '17.1',
        referrerProvider: noReferrer,
        force: true,
      );

      expect(sentBodies.single, {
        'appspace_id': 'app123',
        'timezone': 'Asia/Seoul',
        'language': 'ko-KR',
        'screen_width': 390,
        'screen_height': 844,
        'device_pixel_ratio': 3.0,
        'os_version': '17.1',
      });
    });

    test('sends the same signals claimBySignals would', () async {
      await Deferred(client()).claimDeferredLink(
        appspaceId: 'app123',
        timezone: 'Asia/Seoul',
        language: 'ko-KR',
        screenWidth: 390,
        screenHeight: 844,
        devicePixelRatio: 3.0,
        osVersion: '17.1',
        referrerProvider: noReferrer,
        force: true,
      );
      final viaDeferred = sentBodies.single;

      sentBodies = [];
      await Deferred(client()).claimBySignals(
        appspaceId: 'app123',
        timezone: 'Asia/Seoul',
        language: 'ko-KR',
        screenWidth: 390,
        screenHeight: 844,
        devicePixelRatio: 3.0,
        osVersion: '17.1',
      );

      expect(viaDeferred, sentBodies.single);
    });

    test('a token claim does not reach the signals endpoint', () async {
      // The referrer path is exact, so signals are not wanted when it succeeds.
      await Deferred(client(status: 200, body: '{"deep_link_path":"/p/1","appspace_id":"app123"}'))
          .claimDeferredLink(
        appspaceId: 'app123',
        referrerProvider: () async => 'tolk_token=tok_abc',
        force: true,
      );

      expect(sentBodies, isEmpty, reason: 'claim by token is a GET');
    });
  });

  group('DeviceSignals', () {
    test('caller values override collected ones', () {
      const collected = DeviceSignals(
        language: 'en-US',
        screenWidth: 100,
        devicePixelRatio: 1.0,
      );
      final merged = collected.merge(
        const DeviceSignals(language: 'ko-KR', screenWidth: 390),
      );

      expect(merged.language, 'ko-KR');
      expect(merged.screenWidth, 390);
      expect(merged.devicePixelRatio, 1.0,
          reason: 'a null override must not erase a collected value');
    });

    test('absent fields are omitted rather than sent as null', () {
      const signals = DeviceSignals(language: 'ko-KR');
      expect(signals.toRequestBody(), {'language': 'ko-KR'});
    });

    test('an empty set is recognisable as unmatched', () {
      expect(const DeviceSignals().isEmpty, isTrue);
      expect(const DeviceSignals(language: 'ko-KR').isEmpty, isFalse);
    });

    test('collection never throws, even with no platform view', () {
      expect(collectDeviceSignals, returnsNormally);
    });
  });
}
