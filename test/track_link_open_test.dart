import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tolinku/src/analytics.dart';
import 'package:tolinku/src/http_client.dart';

/// A Universal Link or App Link opens the app without the browser loading, so
/// Tolinku is never contacted and the tap is not recorded. Those taps come from
/// people who already have the app, so leaving them out makes a re-engagement
/// campaign read as a failure exactly when it worked.
///
/// The rule for what to report is the scheme the app received, and it has to
/// hold here as well as on the server: a custom scheme means Tolinku's own
/// hand-off page opened the app, and that tap was counted when the page was
/// served.
void main() {
  late List<Uri> sentUris;
  late List<Map<String, dynamic>> sentBodies;

  Analytics analytics({
    int status = 200,
    String body = '{"attribute":true}',
    bool throws = false,
  }) {
    return Analytics(TolinkuHttpClient(
      baseUrl: 'https://links.example.com',
      apiKey: 'tolk_pub_test',
      httpClient: MockClient((request) async {
        if (throws) throw const _ConnectionFailed();
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
    ));
  }

  setUp(() {
    sentUris = [];
    sentBodies = [];
  });

  group('trackLinkOpen', () {
    test('reports a link the operating system delivered', () async {
      await analytics().trackLinkOpen('https://links.example.com/promo');

      expect(sentUris.single.path, '/v1/api/opens');
      expect(sentBodies.single['url'], 'https://links.example.com/promo');
    });

    test('says nothing about a custom scheme', () async {
      // The hand-off page opens the app as scheme://path, and only after
      // serving a page that recorded the tap. Reporting it would count it twice.
      await analytics().trackLinkOpen('myapp://promo');

      expect(sentUris, isEmpty);
    });

    test('ignores anything that is not a link', () async {
      final a = analytics();
      for (final url in ['', '   ', 'javascript:alert(1)', 'file:///etc/passwd']) {
        await a.trackLinkOpen(url);
      }

      expect(sentUris, isEmpty);
    });

    test('sends the user id when one is given', () async {
      await analytics().trackLinkOpen(
        'https://links.example.com/promo',
        userId: 'user_123',
      );

      expect(sentBodies.single['user_id'], 'user_123');
    });

    test('omits the user id rather than sending null', () async {
      await analytics().trackLinkOpen('https://links.example.com/promo');

      expect(sentBodies.single.containsKey('user_id'), isFalse);
    });

    test('stops sending once the Appspace says it does not attribute', () async {
      // Otherwise switching the setting off would still cost a request on every
      // link the app opens.
      final a = analytics(body: '{"attribute":false}');

      await a.trackLinkOpen('https://links.example.com/a');
      expect(sentUris, hasLength(1));

      await a.trackLinkOpen('https://links.example.com/b');
      await a.trackLinkOpen('https://links.example.com/c');
      expect(sentUris, hasLength(1), reason: 'the answer is remembered');
    });

    test('keeps reporting while the Appspace does attribute', () async {
      final a = analytics();
      await a.trackLinkOpen('https://links.example.com/a');
      await a.trackLinkOpen('https://links.example.com/b');

      expect(sentUris, hasLength(2));
    });

    test('never throws on a server error', () async {
      // This runs on the path that routes the user somewhere. A tap that goes
      // unrecorded is not worth interrupting that.
      await expectLater(
        analytics(status: 500, body: '{"error":"boom"}')
            .trackLinkOpen('https://links.example.com/a'),
        completes,
      );
    });

    test('never throws when the connection fails', () async {
      await expectLater(
        analytics(throws: true).trackLinkOpen('https://links.example.com/a'),
        completes,
      );
    });

    test('reports one tap once, however it was delivered', () async {
      // Cold start and the link stream can both hand over the same tap, so an
      // app instrumenting both paths would otherwise be billed twice for it.
      final a = analytics();
      await a.trackLinkOpen('https://links.example.com/promo');
      await a.trackLinkOpen('https://links.example.com/promo');

      expect(sentUris, hasLength(1));
    });

    test('still reports a different link straight after', () async {
      final a = analytics();
      await a.trackLinkOpen('https://links.example.com/a');
      await a.trackLinkOpen('https://links.example.com/b');

      expect(sentUris, hasLength(2));
    });
  });
}

/// Stands in for a connection failure, which is not an HTTP status.
class _ConnectionFailed implements Exception {
  const _ConnectionFailed();
}