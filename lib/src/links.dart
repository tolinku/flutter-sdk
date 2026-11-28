import 'dart:convert';

import 'package:http/http.dart' as http;

import 'http_client.dart';

/// The route that answers a link.
class ResolvedRoute {
  /// Creates a resolved route.
  const ResolvedRoute({
    required this.prefix,
    required this.name,
    required this.template,
    required this.linkType,
  });

  /// The route's prefix, which may place its token with `{token}`.
  final String prefix;

  /// The route's name, as set in the dashboard.
  final String name;

  /// Which landing page the route uses, or `none`.
  final String template;

  /// `dynamic` or `static`, or null from an older platform.
  final String? linkType;
}

/// What a Tolinku link turned out to mean.
///
/// The same shape in every SDK, so an app moving between them reads one thing.
/// The Appspace the link belongs to is deliberately not here: the app already
/// knows which Appspace it is, and nothing about routing a link needs it.
class ResolvedLink {
  /// Creates a resolved link.
  const ResolvedLink({
    required this.route,
    required this.token,
    required this.deepLinkPath,
  });

  /// The route that answers this link.
  final ResolvedRoute route;

  /// The token the link carried, or an empty string where it carried none.
  final String token;

  /// The canonical path, with the token wherever the route's prefix puts it.
  final String deepLinkPath;
}

/// Working out what a link the system handed the app actually means.
///
/// An app receives the URL that was tapped, exactly as it was written. That is
/// fine while the URL is readable: `/order/4821` says "order" and the app
/// can route it. It is not fine for a short link, which is the same route
/// written as a code:
///
/// ```
/// https://links.example.com/s7k2p9q/4821
/// ```
///
/// Nothing in that URL says "order", and nothing about the code can be worked
/// out on the device. An app parsing the path itself sees a first segment it
/// has never heard of and does nothing, so the link opens the app and then
/// appears to fail: no error, no screen, no clue. Short links are what the
/// dashboard offers for sharing and what a QR code carries, so this is not a
/// rare path.
///
/// [resolve] asks the platform, which answers with the route, the token and
/// the canonical path, and the app can route that the way it routes anything
/// else. A readable URL comes back unchanged, so an app can simply resolve
/// everything rather than guessing which kind it has.
class Links {
  /// Creates the links module.
  Links(this._client);

  final TolinkuHttpClient _client;

  /// What this link means, or null if it means nothing here.
  ///
  /// The question goes to the link's own host, because that is how the platform
  /// knows which Appspace is being asked about, which also means a link on a
  /// domain that is not yours simply answers nothing.
  ///
  /// The link is tidied once first (whitespace and fragment dropped, scheme and
  /// host lowercased, http upgraded to https, a default port dropped, path and
  /// query kept exactly as written) and that form is what both questions use.
  ///
  /// The link's own host is asked once, with a five second limit and no
  /// retries. If it answers as Tolinku (the `X-Tolinku: 1` header, or, from a
  /// server that does not send it yet, a JSON body with an `error` on Tolinku's
  /// own domain), that is the answer, even when it is "no": the server unwraps
  /// an email link once, which is how the email platform counts the click
  /// (Tolinku records no click of its own), so asking again could count it
  /// twice. An email platform's host can answer with a JSON `error` too, so the
  /// body alone is not enough. If it does not answer as Tolinku, which is what
  /// happens to a link in an email once the email platform has wrapped it for
  /// click tracking, the question goes once more to the Tolinku API, with the
  /// API key, so it can unwrap the link. That second question is skipped when the link is already
  /// on the API's host, or when there is no key to ask with.
  ///
  /// Never throws. A link that cannot be resolved, for a bad network or any
  /// other reason, is one the app should fall back to its own handling for, and
  /// an exception in the middle of a cold start is no way to say so.
  Future<ResolvedLink?> resolve(String url) async {
    // The fragment never reaches a server, so it plays no part in the answer.
    final trimmed = url.trim();
    final hash = trimmed.indexOf('#');
    final written = hash < 0 ? trimmed : trimmed.substring(0, hash);

    final Uri uri;
    try {
      uri = Uri.parse(written);
    } on FormatException {
      return null;
    }

    // http and https only. A custom scheme link already carries the path the
    // app wants, and anything else is not a link this could answer for.
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') return null;
    if (uri.host.isEmpty) return null;

    // Always https: every Tolinku and click domain serves it, and iOS ATS and
    // Android's cleartext rules block plain http anyway. A default port says
    // nothing once the scheme is settled; any other port is kept.
    final host = uri.host.toLowerCase();
    final hostPart = host.contains(':') ? '[$host]' : host;
    final port =
        uri.hasPort && uri.port != 80 && uri.port != 443 ? ':${uri.port}' : '';
    final origin = 'https://$hostPart$port';

    // The path as written, percent-encoding intact. A token may contain an
    // encoded slash, and decoding first turns "/promo/a%2Fb" into a path three
    // deep rather than a token of "a/b" on "promo", which resolves to a
    // different route or to nothing.
    final path = uri.path.isEmpty ? '/' : uri.path;

    // The whole link goes along too, query and all, taken from the string as
    // written rather than from the parsed Uri, which would tidy its encoding. A
    // link in an email arrives wrapped in the email platform's click tracking
    // URL, and for some of them (SendGrid, for one) everything that says where
    // the link really goes is in the query. Older servers ignore the field.
    final authorityEnd =
        written.indexOf(RegExp(r'[/?]'), written.indexOf('://') + 3);
    var rest = authorityEnd < 0 ? '' : written.substring(authorityEnd);
    if (!rest.startsWith('/')) rest = '/$rest';
    final whole = '$origin$rest';

    try {
      final response = await _client.postOnce(
        '/v1/api/path',
        origin: origin,
        body: {'path': path, 'url': whole},
      );
      final body = _json(response.body);
      // Tolinku's own answer, even a "no": the host is ours and has answered.
      if (_isTolinkuReply(response, body, host)) return null;
      if (body != null) {
        if (response.statusCode == 200) {
          final resolved = _read(body);
          if (resolved != null) return resolved;
        }
      }
    } catch (_) {
      // No answer from the host; the Tolinku API below may still know the link.
    }

    return _askTolinku(host, whole);
  }

  /// Asks the Tolinku API about a link its own host could not answer for.
  ///
  /// An email platform's click tracking domain is the usual case: the host is
  /// the email platform's or a subdomain pointed at it, so a question asked
  /// there never reaches Tolinku. The API can unwrap the link and resolve what
  /// is inside. This one is authenticated, because it is the API key that says
  /// which Appspace is asking now that the host cannot.
  Future<ResolvedLink?> _askTolinku(String host, String whole) async {
    // Without a key the API has no way to know which Appspace is asking.
    if (_client.apiKey.trim().isEmpty) return null;

    // If the link is on the API's own host, the first question already went
    // there, and asking again would only get the same answer.
    final apiHost = Uri.tryParse(_client.baseUrl)?.host.toLowerCase() ?? '';
    if (apiHost.isEmpty || host == apiHost) return null;

    try {
      final response = await _client.postOnce(
        '/v1/api/links/resolve',
        body: {'url': whole},
        authenticated: true,
      );
      if (response.statusCode != 200) return null;
      final body = _json(response.body);
      return body == null ? null : _read(body);
    } catch (_) {
      return null;
    }
  }

  /// Whether a reply is Tolinku's: marked `X-Tolinku: 1`, or, from a server
  /// that predates the header, a JSON `error` from Tolinku's own domain (the
  /// API's host or a host under its parent domain).
  bool _isTolinkuReply(
      http.Response response, Map<String, dynamic>? body, String host) {
    if (response.headers['x-tolinku'] == '1') return true;
    if (body == null || body['error'] is! String) return false;
    final apiHost = Uri.tryParse(_client.baseUrl)?.host.toLowerCase() ?? '';
    if (apiHost.isEmpty) return false;
    if (host == apiHost) return true;
    final labels = apiHost.split('.');
    return labels.length > 2 &&
        host.endsWith('.${labels.sublist(labels.length - 2).join('.')}');
  }

  /// The body as a JSON object, or null if it is not one.
  Map<String, dynamic>? _json(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Reads an answer from either endpoint, or null if it is not one.
  ResolvedLink? _read(Map<String, dynamic> response) {
    final route = response['route'];
    if (route is! Map<String, dynamic>) return null;

    // The answer may have come from a host taken from the URL this was given,
    // so an app resolving a link from somewhere it does not control is talking
    // to a stranger. The contract is a path: a full URL, or a protocol relative
    // "//host" that reads as one, is a redirect waiting to happen in whatever
    // the app does next.
    final deepLinkPath = response['deep_link_path'];
    if (deepLinkPath is! String ||
        !deepLinkPath.startsWith('/') ||
        deepLinkPath.startsWith('//')) {
      return null;
    }
    return ResolvedLink(
      route: ResolvedRoute(
        prefix: route['prefix'] as String? ?? '',
        name: route['name'] as String? ?? '',
        template: route['template'] as String? ?? '',
        linkType: route['link_type'] as String?,
      ),
      token: response['token'] as String? ?? '',
      deepLinkPath: deepLinkPath,
    );
  }
}
