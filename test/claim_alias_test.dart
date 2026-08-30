import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tolinku/src/deferred.dart';
import 'package:tolinku/src/http_client.dart';
import 'package:tolinku/tolinku.dart';

/// [Deferred.claimByToken] is the name the other Tolinku SDKs use;
/// [Deferred.claim] is the one this package shipped in 0.3.0. Both are
/// supported, and `claim` is meant for deprecation once moving off it is a
/// one-line change rather than a surprise.
///
/// An alias is only worth having while it stays identical, and "it just
/// forwards" is the kind of thing that stops being true when someone adds a
/// parameter to one of them. These compare what actually goes over the wire.
void main() {
  late List<Uri> sentUris;

  TolinkuHttpClient clientReturning(int status, String body) {
    return TolinkuHttpClient(
      baseUrl: 'https://myapp.tolinku.com',
      apiKey: 'tolk_pub_test',
      httpClient: MockClient((request) async {
        sentUris.add(request.url);
        return http.Response(
          body,
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }

  const linkJson = '{"deep_link_path":"/product/42","appspace_id":"app123"}';

  setUp(() => sentUris = []);

  test('both names send the same request', () async {
    final viaClaim = Deferred(clientReturning(200, linkJson));
    await viaClaim.claim(token: 'tok_abc', appspaceId: 'app123');
    final claimUri = sentUris.single;

    sentUris = [];
    final viaAlias = Deferred(clientReturning(200, linkJson));
    await viaAlias.claimByToken(token: 'tok_abc', appspaceId: 'app123');
    final aliasUri = sentUris.single;

    expect(aliasUri, claimUri);
  });

  test('both names return the same link', () async {
    final a = await Deferred(clientReturning(200, linkJson))
        .claim(token: 'tok_abc');
    final b = await Deferred(clientReturning(200, linkJson))
        .claimByToken(token: 'tok_abc');

    expect(b, isNotNull);
    expect(b!.deepLinkPath, a!.deepLinkPath);
    expect(jsonEncode(b.toJson()), jsonEncode(a.toJson()));
  });

  test('both names treat a miss as null rather than an error', () async {
    expect(
      await Deferred(clientReturning(404, '{"error":"not found"}'))
          .claim(token: 'tok_missing'),
      isNull,
    );
    expect(
      await Deferred(clientReturning(404, '{"error":"not found"}'))
          .claimByToken(token: 'tok_missing'),
      isNull,
    );
  });

  test('both names reject an empty token the same way', () async {
    final d = Deferred(clientReturning(200, linkJson));
    expect(() => d.claim(token: '   '), throwsArgumentError);
    expect(() => d.claimByToken(token: '   '), throwsArgumentError);
  });

  test('appspaceId is optional on both', () async {
    final viaClaim = Deferred(clientReturning(200, linkJson));
    await viaClaim.claim(token: 'tok_abc');
    final claimUri = sentUris.single;

    sentUris = [];
    final viaAlias = Deferred(clientReturning(200, linkJson));
    await viaAlias.claimByToken(token: 'tok_abc');

    expect(sentUris.single, claimUri);
    expect(claimUri.queryParameters.containsKey('appspace_id'), isFalse);
  });
}
