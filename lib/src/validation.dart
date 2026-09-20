/// Whether a URL is safe to open or render as a web page.
///
/// Only `http` and `https` are allowed. Everything else a URL can carry is a way
/// of doing something other than opening a web page: `javascript:` executes,
/// `file:` reads local storage, `content:` and `intent:` reach other apps on
/// Android.
///
/// This is the right rule wherever the destination is known to be a web page,
/// and the wrong one for a message's call to action, which on a deep linking
/// product is most often a link into the host app. See [isNavigableUrl] for
/// that.
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

/// The schemes that can run code or forge an origin when something follows them.
const Set<String> _executableSchemes = {
  'javascript',
  'vbscript',
  'data',
  'blob',
  'file',
};

/// Matches a scheme at the start of a URL, per RFC 3986: a letter, then letters,
/// digits, `+`, `-` and `.`.
final RegExp _schemePattern = RegExp(r'^([a-zA-Z][a-zA-Z\d+\-.]*):');

/// A URL's scheme, lowercased, or null when it has none.
///
/// Deliberately not `Uri.tryParse(...).scheme`. That parser is lenient in both
/// directions: it returns null for anything with a tab or a newline in it, and
/// it returns a Uri with an empty scheme for a relative path. Neither answer
/// distinguishes "no scheme" from "a scheme written so a parser will not read
/// it", and the second of those is the one that matters here.
///
/// Whitespace and control characters are removed the way a URL parser removes
/// them, from the ends and from inside the scheme, so `java\tscript:` is
/// recognised as javascript: rather than waved through as unparseable.
String? _schemeOf(String url) {
  if (url.isEmpty) return null;

  // Tabs and newlines are ignored anywhere in a URL by the things that follow
  // one; spaces and C0 controls are stripped from the ends.
  final cleaned = url
      .replaceAll(RegExp(r'[\t\n\r]'), '')
      .replaceAll(RegExp(r'^[\x00-\x20]+|[\x00-\x20]+$'), '');

  final match = _schemePattern.firstMatch(cleaned);
  return match?.group(1)?.toLowerCase();
}

/// Whether a URL is safe to follow when someone taps a message's call to action.
///
/// Deliberately not [isSafeUrl]. That one allows http and https only, which is
/// right for an image source and wrong for a call to action: this is a deep
/// linking product, so the most natural button in an in-app message is one that
/// opens a screen in the app, `myapp://order/4821`. An allowlist blocked exactly
/// that, silently, before the host app's own handler was even called, while the
/// platform that authors the message has always permitted it.
///
/// Every customer's scheme is different, so there is no list to allow. The small
/// known set of dangerous schemes is named instead, matching the platform's own
/// rule in `safe-url.ts` and the React Native SDK's `isSafeActionUrl`, and
/// everything else is left to open.
bool isNavigableUrl(String? url) {
  if (url == null) return false;

  final scheme = _schemeOf(url);
  // No scheme means relative or a fragment. There is no base to resolve it
  // against on a device, so it is not something to open.
  if (scheme == null) return false;

  return !_executableSchemes.contains(scheme);
}
