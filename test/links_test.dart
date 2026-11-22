import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tolinku/src/http_client.dart';
import 'package:tolinku/src/links.dart';

/// Turning a link the system handed the app into something routable.
///
/// The URL an app receives is the one that was tapped, exactly as written. A
/// short link is an opaque code, `/s7k2p9q/4821`, and nothing on the device
/// can say what the code stands for. An app parsing the path itself sees a
/// first segment it has never heard of and does nothing, so the link opens the
/// app and appears to fail with no error and no screen.
///
/// The question has to go to the link's own host, because that is how the
/// platform knows which Appspace is being asked about. These assert on the URL
/// the request went to as much as on what came back.
void main() {
  late List<Uri> requestedUrls;
  late List<Map<String, dynamic>> sentBodies;
  late List<Map<String, String>> sentHeaders;

  const answer = '''
  {
    "route": {"prefix": "order/{token}/receipt", "name": "Order Receipt", "template": "none", "link_type": "dynamic"},
    "token": "4821",
    "deep_link_path": "/order/4821/receipt",
    "appspace": {"name": "Example App", "slug": "example"}
  }
  ''';

  // [fallbackStatus] and [fallbackBody] are what the Tolinku API's own
  // /v1/api/links/resolve answers; by default it says the same as the link's
  // host, so a test about the first question is not rescued by the second.
  TolinkuHttpClient client({
    int status = 200,
    String body = answer,
    int? fallbackStatus,
    String? fallbackBody,
    String apiKey = 'tolk_pub_test',
    String baseUrl = 'https://api.tolinku.com',
    Future<http.Response> Function()? onHost,
    Future<http.Response> Function()? onFallback,
  }) {
    return TolinkuHttpClient(
      // Deliberately not the link host, so a request that went here instead of
      // to the link's own origin shows up as a failure.
      baseUrl: baseUrl,
      apiKey: apiKey,
      httpClient: MockClient((request) async {
        requestedUrls.add(request.url);
        sentHeaders.add(request.headers);
        if (request.body.isNotEmpty) {
          sentBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        }
        final isFallback = request.url.path == '/v1/api/links/resolve';
        if (isFallback && onFallback != null) return onFallback();
        if (!isFallback && onHost != null) return onHost();
        return http.Response(
          isFallback ? (fallbackBody ?? body) : body,
          isFallback ? (fallbackStatus ?? status) : status,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }

  setUp(() {
    requestedUrls = [];
    sentBodies = [];
    sentHeaders = [];
  });

  test('asks the link its own host, with the path and the whole link',
      () async {
    final link = await Links(client())
        .resolve('https://links.example.com/s7k2p9q/4821');

    expect(requestedUrls.single.toString(),
        'https://links.example.com/v1/api/path');
    expect(sentBodies.single, {
      'path': '/s7k2p9q/4821',
      'url': 'https://links.example.com/s7k2p9q/4821',
    });
    expect(link!.token, '4821');
    expect(link.deepLinkPath, '/order/4821/receipt');
    expect(link.route.prefix, 'order/{token}/receipt');
    expect(link.route.name, 'Order Receipt');
    expect(link.route.linkType, 'dynamic');
  });

  test('asks without the API key, since the host is not necessarily ours',
      () async {
    // The origin comes from the URL this was handed. An app resolving a link
    // from somewhere it does not control would otherwise send the Appspace's
    // key to a stranger.
    await Links(client()).resolve('https://links.example.com/s7k2p9q/4821');

    expect(sentHeaders.single.keys.map((k) => k.toLowerCase()),
        isNot(contains('x-api-key')));
    expect(sentHeaders.single.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')));
  });

  test('leaves the query string out of the path, but not out of the link',
      () async {
    // A tapped link usually carries utm parameters, and they say nothing about
    // which route it is. The whole link still goes along, because a link
    // wrapped by an email platform keeps where it really goes in the query.
    await Links(client())
        .resolve('https://links.example.com/s7k2p9q/4821?utm_source=qr');
    expect(sentBodies.single, {
      'path': '/s7k2p9q/4821',
      'url': 'https://links.example.com/s7k2p9q/4821?utm_source=qr',
    });
  });

  test('keeps an encoded slash in the token encoded', () async {
    // Decoding first turns "/promo/a%2Fb" into a path three deep rather than a
    // token of "a/b" on "promo", which resolves to a different route or none.
    await Links(client()).resolve('https://links.example.com/promo/a%2Fb');
    expect(sentBodies.single['path'], '/promo/a%2Fb');
  });

  // resolve sends its question to a host taken from the URL it was given, so an
  // app resolving a link from somewhere it does not control is talking to a
  // stranger. Anything but a path is a redirect waiting to happen.
  for (final bad in const [
    'https://evil.example.com/take-over',
    '//evil.example.com/take-over',
    'order/4821',
    '',
  ]) {
    test('refuses an answer of ${bad.isEmpty ? "nothing" : bad}', () async {
      final body = answer.replaceFirst('"/order/4821/receipt"', '"$bad"');
      expect(
        await Links(client(body: body))
            .resolve('https://links.example.com/s7k2p9q/4821'),
        isNull,
      );
    });
  }

  test('says nothing for a custom scheme link', () async {
    // That one already carries the path the app wants.
    expect(await Links(client()).resolve('example://order/4821/receipt'),
        isNull);
    expect(requestedUrls, isEmpty);
  });

  test('says nothing for something that is not a link', () async {
    expect(await Links(client()).resolve('/order/4821'), isNull);
    expect(await Links(client()).resolve(''), isNull);
    expect(requestedUrls, isEmpty);
  });

  test('returns null rather than throwing into a cold start', () async {
    // This runs while the app is opening. An exception here is the difference
    // between a link that did not route and an app that did not start.
    expect(await Links(client(status: 500)).resolve('https://links.example.com/s7k2p9q/1'),
        isNull);
  });

  test('returns null for a link this Appspace does not own', () async {
    expect(await Links(client(body: '{}')).resolve('https://links.example.com/x/1'),
        isNull);
  });

  // The link is tidied once, and that one form is what both questions carry.
  group('normalises the link', () {
    for (final (written, origin, whole) in const [
      (
        '  HTTP://Links.EXAMPLE.com:80/s7k2p9q/4821?utm_source=A%2fb#top  ',
        'https://links.example.com',
        'https://links.example.com/s7k2p9q/4821?utm_source=A%2fb',
      ),
      (
        'https://links.example.com:443/s7k2p9q/4821',
        'https://links.example.com',
        'https://links.example.com/s7k2p9q/4821',
      ),
      (
        'http://links.example.com:443/s7k2p9q/4821',
        'https://links.example.com',
        'https://links.example.com/s7k2p9q/4821',
      ),
      (
        'http://links.example.com:8443/s7k2p9q/4821',
        'https://links.example.com:8443',
        'https://links.example.com:8443/s7k2p9q/4821',
      ),
      (
        'https://links.example.com?x=%41',
        'https://links.example.com',
        'https://links.example.com/?x=%41',
      ),
    ]) {
      test(written.trim(), () async {
        await Links(client()).resolve(written);
        expect(requestedUrls.single.toString(), '$origin/v1/api/path');
        expect(sentBodies.single['url'], whole);
      });
    }

    test('sends the same form to the Tolinku API', () async {
      await Links(client(
        onHost: () async => http.Response('Not Found', 404),
      )).resolve(' http://Click.Brand.com/ls/click?upn=AB%2Fcd#x');
      expect(requestedUrls.map((u) => u.toString()), [
        'https://click.brand.com/v1/api/path',
        'https://api.tolinku.com/v1/api/links/resolve',
      ]);
      expect(sentBodies.first['url'],
          'https://click.brand.com/ls/click?upn=AB%2Fcd');
      expect(sentBodies.last,
          {'url': 'https://click.brand.com/ls/click?upn=AB%2Fcd'});
    });
  });

  // A link in an email arrives wrapped in the email platform's click tracking
  // URL, on a host that is the email platform's. Asking that host gets nothing
  // Tolinku said, so the Tolinku API is asked instead, with the key, and it
  // unwraps the link.
  group('a link its own host cannot answer', () {
    const wrapped = 'https://url1234.email.brand.com/uni/ls/click?upn=XYZ';
    Future<http.Response> notFoundPage() async =>
        http.Response('<html>Not Found</html>', 404);

    test('asks the Tolinku API with the key and the whole link', () async {
      final link = await Links(client(onHost: notFoundPage)).resolve(wrapped);

      expect(requestedUrls.map((u) => u.toString()), [
        'https://url1234.email.brand.com/v1/api/path',
        'https://api.tolinku.com/v1/api/links/resolve',
      ]);
      expect(sentBodies.last, {'url': wrapped});
      // The key goes only to the configured API, never to the link's host.
      expect(sentHeaders.first.keys.map((k) => k.toLowerCase()),
          isNot(contains('x-api-key')));
      expect(sentHeaders.last['X-API-Key'], 'tolk_pub_test');
      expect(link!.token, '4821');
      expect(link.deepLinkPath, '/order/4821/receipt');
      expect(link.route.name, 'Order Receipt');
    });

    test('falls back after a network error', () async {
      final link = await Links(client(
        onHost: () async => throw http.ClientException('connection refused'),
      )).resolve(wrapped);
      expect(link!.token, '4821');
      expect(requestedUrls, hasLength(2));
    });

    test('falls back after JSON without an error field', () async {
      final link = await Links(client(
        onHost: () async => http.Response('{"message": "nope"}', 404),
      )).resolve(wrapped);
      expect(link!.token, '4821');
      expect(requestedUrls, hasLength(2));
    });

    test('falls back after a 200 that is not an answer', () async {
      final link = await Links(client(
        onHost: () async => http.Response('{"ok": true}', 200),
      )).resolve(wrapped);
      expect(link!.token, '4821');
      expect(requestedUrls, hasLength(2));
    });

    test('skips the API host, whatever its case or port', () async {
      final link = await Links(client(
        baseUrl: 'https://API.Tolinku.com:8443',
        onHost: notFoundPage,
      )).resolve('https://api.TOLINKU.com/s7k2p9q/4821');

      expect(link, isNull);
      expect(requestedUrls.single.toString(),
          'https://api.tolinku.com/v1/api/path');
    });

    test('does not ask without an API key', () async {
      final link = await Links(client(onHost: notFoundPage, apiKey: ''))
          .resolve(wrapped);

      expect(link, isNull);
      expect(requestedUrls, hasLength(1));
    });

    test('refuses an unsafe path from the Tolinku API too', () async {
      final link = await Links(client(
        onHost: notFoundPage,
        fallbackBody: answer.replaceFirst(
            '"/order/4821/receipt"', '"//evil.example.com/take-over"'),
      )).resolve(wrapped);

      expect(link, isNull);
      expect(requestedUrls, hasLength(2));
    });

    test('refuses an unsafe path from the host when nothing else answers',
        () async {
      final link = await Links(client(
        body: answer.replaceFirst(
            '"/order/4821/receipt"', '"https://evil.example.com/x"'),
        fallbackStatus: 404,
        fallbackBody: '{"error": "Route not found"}',
      )).resolve(wrapped);

      expect(link, isNull);
      expect(requestedUrls, hasLength(2));
    });

    test('returns null when the Tolinku API does not know it either',
        () async {
      final link = await Links(client(
        onHost: notFoundPage,
        fallbackStatus: 404,
        fallbackBody: '{"error": "Not found", "web_url": "https://brand.com"}',
      )).resolve(wrapped);

      expect(link, isNull);
      expect(requestedUrls, hasLength(2));
    });

    test('accepts only a 200 from the Tolinku API', () async {
      final link = await Links(client(
        onHost: notFoundPage,
        fallbackStatus: 201,
      )).resolve(wrapped);

      expect(link, isNull);
      expect(requestedUrls, hasLength(2));
    });
  });

  // The host is Tolinku's and has said no. Asking the API as well would count
  // the email click twice, so that answer stands.
  group("Tolinku's own answer stops there", () {
    for (final (status, body) in const [
      (404, '{"error": "Route not found"}'),
      (404, '{"error": "Route not found", "web_url": "https://brand.com/x"}'),
      (400, '{"error": "Invalid path"}'),
      (500, '{"error": "Internal error"}'),
      (200, '{"error": "Route not found"}'),
    ]) {
      test('$status $body', () async {
        final link = await Links(client(
          status: status,
          body: body,
          fallbackStatus: 200,
          fallbackBody: answer,
        )).resolve('https://links.example.com/s7k2p9q/4821');

        expect(link, isNull);
        expect(requestedUrls.single.toString(),
            'https://links.example.com/v1/api/path');
      });
    }
  });

  // Each question is asked exactly once: a retry could count the same click
  // twice, and this runs while the app is opening.
  group('asks each question once', () {
    test('no retry after a server error on either request', () async {
      final link = await Links(client(
        onHost: () async => http.Response('Bad Gateway', 502),
        onFallback: () async => http.Response('Bad Gateway', 502),
      )).resolve('https://links.example.com/s7k2p9q/4821');

      expect(link, isNull);
      expect(requestedUrls.map((u) => u.path),
          ['/v1/api/path', '/v1/api/links/resolve']);
    });

    test('no retry after a network error on either request', () async {
      final link = await Links(client(
        onHost: () async => throw http.ClientException('reset'),
        onFallback: () async => throw http.ClientException('reset'),
      )).resolve('https://links.example.com/s7k2p9q/4821');

      expect(link, isNull);
      expect(requestedUrls, hasLength(2));
    });

    test('no retry after a 429 on either request', () async {
      final link = await Links(client(
        onHost: () async => http.Response('slow down', 429,
            headers: {'retry-after': '0'}),
        onFallback: () async => http.Response('slow down', 429,
            headers: {'retry-after': '0'}),
      )).resolve('https://links.example.com/s7k2p9q/4821');

      expect(link, isNull);
      expect(requestedUrls, hasLength(2));
    });
  });

  group('time limit', () {
    test('is five seconds', () {
      expect(tolinkuOneShotTimeout, const Duration(seconds: 5));
    });

    // testWidgets runs on a fake clock, so the five seconds pass instantly.
    testWidgets('gives up on a silent host after five seconds and falls back',
        (tester) async {
      final hang = Completer<http.Response>();
      ResolvedLink? link;
      var done = false;
      unawaited(Links(client(onHost: () => hang.future))
          .resolve('https://links.example.com/s7k2p9q/4821')
          .then((value) {
        link = value;
        done = true;
      }));

      await tester.pump(const Duration(milliseconds: 4900));
      expect(done, isFalse);
      expect(requestedUrls, hasLength(1));

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(done, isTrue);
      expect(link!.token, '4821');
      expect(requestedUrls.map((u) => u.path),
          ['/v1/api/path', '/v1/api/links/resolve']);
    });

    testWidgets('gives up on a silent Tolinku API after five seconds',
        (tester) async {
      final hang = Completer<http.Response>();
      ResolvedLink? link;
      var done = false;
      unawaited(Links(client(
        onHost: () async => http.Response('Not Found', 404),
        onFallback: () => hang.future,
      )).resolve('https://links.example.com/s7k2p9q/4821').then((value) {
        link = value;
        done = true;
      }));

      await tester.pump(const Duration(milliseconds: 4900));
      expect(done, isFalse);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(done, isTrue);
      expect(link, isNull);
      expect(requestedUrls, hasLength(2));
    });
  });
}
