import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tolinku/src/http_client.dart';
import 'package:tolinku/tolinku.dart';

/// Tests for the payload [Deferred.claimBySignals] sends.
///
/// These values are matched against what the Tolinku landing page records in the
/// browser. A format or unit mismatch does not fail loudly: the signal is skipped
/// and the claim quietly returns null, which is exactly how an integration issue
/// went unexplained for days. Asserting the wire payload keeps that honest.
void main() {
  late List<Map<String, dynamic>> sentBodies;
  late List<Uri> sentUris;

  /// A client capturing every request and replying with [status] and [body].
  TolinkuHttpClient clientReturning(int status, String body) {
    return TolinkuHttpClient(
      baseUrl: 'https://myapp.tolinku.com',
      apiKey: 'tolk_pub_test',
      httpClient: MockClient((request) async {
        sentUris.add(request.url);
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

  setUp(() {
    sentBodies = [];
    sentUris = [];
  });

  const okBody = '{"deep_link_path":"/product/42","appspace_id":"64f0a1b2c3d4e5f60718"}';

  group('claimBySignals payload', () {
    test('sends every signal the matcher compares', () async {
      final deferred = Deferred(clientReturning(200, okBody));

      await deferred.claimBySignals(
        appspaceId: '64f0a1b2c3d4e5f60718',
        timezone: 'Asia/Seoul',
        language: 'ko-KR',
        screenWidth: 390,
        screenHeight: 844,
        devicePixelRatio: 3.0,
        osVersion: '17.4',
      );

      expect(sentBodies, hasLength(1));
      final body = sentBodies.single;
      expect(body['appspace_id'], '64f0a1b2c3d4e5f60718');
      expect(body['timezone'], 'Asia/Seoul');
      expect(body['language'], 'ko-KR');
      expect(body['screen_width'], 390);
      expect(body['screen_height'], 844);
      expect(body['device_pixel_ratio'], 3.0);
      expect(body['os_version'], '17.4');
    });

    test('never sends the Appspace ID alone', () async {
      // A claim with nothing to compare cannot match, because the matcher only
      // compares fields present on both the click and the claim. The caller
      // supplying nothing is a reason to read the device, not to send an empty
      // claim. This SDK sent one until 0.4.1.
      final deferred = Deferred(clientReturning(200, okBody));

      await deferred.claimBySignals(appspaceId: '64f0a1b2c3d4e5f60718');

      expect(sentBodies.single.keys, isNot(equals(['appspace_id'])));
    });

    test('keeps a partial set and fills the rest from the device', () async {
      final deferred = Deferred(clientReturning(200, okBody));

      await deferred.claimBySignals(
        appspaceId: '64f0a1b2c3d4e5f60718',
        timezone: 'Asia/Seoul',
        devicePixelRatio: 2.0,
      );

      final body = sentBodies.single;
      expect(body['timezone'], 'Asia/Seoul');
      expect(body['device_pixel_ratio'], 2.0);
    });

    test('a signal that cannot be read is absent, not null or zero', () async {
      // The server compares a signal only when both sides supplied it, so a
      // placeholder would register as a disagreement rather than as silence.
      final deferred = Deferred(clientReturning(200, okBody));

      await deferred.claimBySignals(appspaceId: '64f0a1b2c3d4e5f60718');

      for (final value in sentBodies.single.values) {
        expect(value, isNotNull);
      }
    });

    test('posts to the claim-by-signals endpoint', () async {
      final deferred = Deferred(clientReturning(200, okBody));

      await deferred.claimBySignals(appspaceId: '64f0a1b2c3d4e5f60718');

      expect(sentUris.single.path, '/v1/api/deferred/claim-by-signals');
      expect(sentUris.single.host, 'myapp.tolinku.com');
    });
  });

  group('claimBySignals results', () {
    test('returns the link on success', () async {
      final deferred = Deferred(clientReturning(200, okBody));

      final link = await deferred.claimBySignals(appspaceId: '64f0a1b2c3d4e5f60718');

      expect(link, isNotNull);
      expect(link!.deepLinkPath, '/product/42');
    });

    test('returns null on 404, which means nothing was waiting', () async {
      final deferred = Deferred(
        clientReturning(404, '{"error":"No matching deferred link found"}'),
      );

      final link = await deferred.claimBySignals(appspaceId: '64f0a1b2c3d4e5f60718');

      expect(link, isNull);
    });

    test('throws on 403 rather than reporting no match', () async {
      final deferred = Deferred(
        clientReturning(
          403,
          '{"error":"Unknown appspace_id. Use your Appspace ID, not its slug or subdomain."}',
        ),
      );

      // A wrong appspaceId must surface. Collapsing it into null is what made an
      // earlier integration failure impossible to diagnose from the client side.
      await expectLater(
        deferred.claimBySignals(appspaceId: 'my-subdomain'),
        throwsA(isA<TolinkuException>()),
      );
    });

    test('rejects a blank appspaceId before making a request', () async {
      final deferred = Deferred(clientReturning(200, okBody));

      expect(
        () => deferred.claimBySignals(appspaceId: '   '),
        throwsA(isA<ArgumentError>()),
      );
      expect(sentUris, isEmpty);
    });
  });
}
