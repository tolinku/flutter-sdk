/// The Play Install Referrer, the deterministic half of deferred linking on
/// Android.
///
/// A Tolinku link sends an Android visitor to the store with
/// `referrer=tolk_token=<token>` attached. Play keeps that string through the
/// install and returns it on first launch, naming the exact click rather than
/// inferring it from device signals, which are probabilistic and expire in
/// hours.
///
/// Reading it requires a Play Services binding, so the referrer is supplied by
/// whichever package the app already uses. See [ReferrerProvider].
library;

const String _tokenKey = 'tolk_token';

/// Supplies the raw Play referrer string for this install.
///
/// Typically wraps a package such as `android_play_install_referrer`. Returning
/// `null` means "nothing to report", which is the ordinary case for an organic
/// install and for every non-Android platform.
typedef ReferrerProvider = Future<String?> Function();

/// Extracts the Tolinku token from a Play referrer string.
///
/// The referrer is shared: a developer's own `utm_source` and anything else
/// they attached live in the same string, so the token is found among the pairs
/// rather than assumed to be the whole value. A percent-encoded `%3D` is
/// tolerated, since Play normally decodes it and that assumption is not worth a
/// lost install if it is ever wrong.
///
/// Returns `null` when the string carries no Tolinku token.
String? parseInstallReferrer(String? referrer) {
  if (referrer == null || referrer.trim().isEmpty) return null;

  var decoded = referrer;
  try {
    decoded = Uri.decodeComponent(referrer);
  } catch (_) {
    // Malformed encoding: fall back to the raw string. Caught broadly on
    // purpose, since Uri.decodeComponent raises ArgumentError, an Error rather
    // than an Exception, so `on Exception` would not catch it.
  }

  for (final pair in decoded.split('&')) {
    final trimmed = pair.trim();
    if (!trimmed.startsWith('$_tokenKey=')) continue;
    final token = trimmed.substring(_tokenKey.length + 1).trim();
    return token.isEmpty ? null : token;
  }
  return null;
}
