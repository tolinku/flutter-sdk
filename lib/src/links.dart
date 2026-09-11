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
  /// Never throws. A link that cannot be resolved, for a bad network or any
  /// other reason, is one the app should fall back to its own handling for, and
  /// an exception in the middle of a cold start is no way to say so.
  Future<ResolvedLink?> resolve(String url) async {
    final Uri uri;
    try {
      uri = Uri.parse(url.trim());
    } on FormatException {
      return null;
    }

    // http and https only. A custom scheme link already carries the path the
    // app wants, and anything else is not a link this could answer for.
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') return null;
    if (uri.host.isEmpty) return null;

    final origin = uri.hasPort
        ? '$scheme://${uri.host}:${uri.port}'
        : '$scheme://${uri.host}';

    // The path as written, percent-encoding intact. A token may contain an
    // encoded slash, and decoding first turns "/promo/a%2Fb" into a path three
    // deep rather than a token of "a/b" on "promo", which resolves to a
    // different route or to nothing.
    final path = uri.path.isEmpty ? '/' : uri.path;

    try {
      final response = await _client.postToOrigin(
        origin,
        '/v1/api/path',
        body: {'path': path},
      );
      final route = response['route'];
      if (route is! Map<String, dynamic>) return null;

      // The answer went to a host taken from the URL this was given, so an app
      // resolving a link from somewhere it does not control is talking to a
      // stranger. The contract is a path: a full URL, or a protocol relative
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
    } catch (_) {
      return null;
    }
  }
}
