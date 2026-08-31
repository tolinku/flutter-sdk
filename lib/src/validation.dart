/// Whether a URL is safe to open or render.
///
/// Only `http` and `https` are allowed. A message is rendered in a WebView and
/// can ask the app to navigate, so the URL it names crosses from page content
/// into native code. Everything else a URL can carry is a way of doing something
/// other than opening a web page: `javascript:` executes, `file:` reads local
/// storage, `content:` and `intent:` reach other apps on Android.
///
/// The Tolinku iOS, Android, React Native and web SDKs all apply the same rule.
/// This package did not, which made it the one place a message could name a
/// scheme and have it handed to the host app unexamined.
bool isSafeUrl(String? url) {
  if (url == null) return false;

  // Leading and trailing whitespace would otherwise let " javascript:..." past
  // a naive prefix check, and is never meaningful in a URL.
  final trimmed = url.trim();
  if (trimmed.isEmpty) return false;

  final parsed = Uri.tryParse(trimmed);
  if (parsed == null || !parsed.hasScheme) return false;

  final scheme = parsed.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https';
}
