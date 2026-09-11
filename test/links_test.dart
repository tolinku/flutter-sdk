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

  const answer = '''
  {
    "route": {"prefix": "order/{token}/receipt", "name": "Order Receipt", "template": "none", "link_type": "dynamic"},
    "token": "4821",
    "deep_link_path": "/order/4821/receipt",
    "appspace": {"name": "Example App", "slug": "example"}
  }
  ''';

  TolinkuHttpClient client({int status = 200, String body = answer}) {
    return TolinkuHttpClient(
      // Deliberately not the link host, so a request that went here instead of
      // to the link's own origin shows up as a failure.
      baseUrl: 'https://api.tolinku.com',
      apiKey: 'tolk_pub_test',
      httpClient: MockClient((request) async {
        requestedUrls.add(request.url);
        if (request.body.isNotEmpty) {
          sentBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        }
        return http.Response(body, status,
            headers: {'content-type': 'application/json'});
      }),
    );
  }

  setUp(() {
    requestedUrls = [];
    sentBodies = [];
  });

  test('asks the link its own host, with just the path', () async {
    final link = await Links(client())
        .resolve('https://links.example.com/s7k2p9q/4821');

    expect(requestedUrls.single.toString(),
        'https://links.example.com/v1/api/path');
    expect(sentBodies.single, {'path': '/s7k2p9q/4821'});
    expect(link!.token, '4821');
    expect(link.deepLinkPath, '/order/4821/receipt');
    expect(link.route.prefix, 'order/{token}/receipt');
    expect(link.route.name, 'Order Receipt');
    expect(link.route.linkType, 'dynamic');
  });

  test('leaves the query string out of the question', () async {
    // A tapped link usually carries utm parameters, and they say nothing about
    // which route it is.
    await Links(client())
        .resolve('https://links.example.com/s7k2p9q/4821?utm_source=qr');
    expect(sentBodies.single, {'path': '/s7k2p9q/4821'});
  });

  test('keeps an encoded slash in the token encoded', () async {
    // Decoding first turns "/promo/a%2Fb" into a path three deep rather than a
    // token of "a/b" on "promo", which resolves to a different route or none.
    await Links(client()).resolve('https://links.example.com/promo/a%2Fb');
    expect(sentBodies.single, {'path': '/promo/a%2Fb'});
  });

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
}
