import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tolinku/src/deferred.dart';
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

    test('omits signals the caller did not supply', () async {
      final deferred = Deferred(clientReturning(200, okBody));

      await deferred.claimBySignals(appspaceId: '64f0a1b2c3d4e5f60718');

      final body = sentBodies.single;
      expect(body.keys, ['appspace_id']);
      // A signal the caller cannot provide must be absent rather than null or
      // zero: the server only compares a signal when both sides supplied it, and
      // a placeholder value would register as a disagreement.
      expect(body.containsKey('device_pixel_ratio'), isFalse);
      expect(body.containsKey('os_version'), isFalse);
    });

    test('sends a partial set unchanged', () async {
      final deferred = Deferred(clientReturning(200, okBody));

      await deferred.claimBySignals(
        appspaceId: '64f0a1b2c3d4e5f60718',
        timezone: 'Asia/Seoul',
        devicePixelRatio: 2.0,
      );

      final body = sentBodies.single;
      expect(body['timezone'], 'Asia/Seoul');
      expect(body['device_pixel_ratio'], 2.0);
      expect(body.containsKey('language'), isFalse);
      expect(body.containsKey('screen_width'), isFalse);
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
