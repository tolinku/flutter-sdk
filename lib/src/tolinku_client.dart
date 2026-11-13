import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'analytics.dart';
import 'deferred.dart';
import 'links.dart';
import 'ecommerce.dart';
import 'exceptions.dart';
import 'http_client.dart';
import 'messages.dart';
import 'referrals.dart';

/// Regular expression for URLs allowed to use HTTP (local development only).
final RegExp _localHttpPattern = RegExp(
  r'^http://(localhost|10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.|127\.0\.0\.1)',
);

/// Flushes queued events when the app leaves the foreground.
///
/// The other four SDKs each do this for themselves: the web SDK on
/// `beforeunload`, React Native through `AppState`, iOS on
/// `willResignActive`, and Android through `ActivityLifecycleCallbacks`. This
/// package was the only one that did not, and asked the app to implement
/// [WidgetsBindingObserver] and call `flush()` instead. Anyone who did not
/// read that lost whatever was still queued every time the app was
/// backgrounded, with nothing to indicate it, which is not a reasonable thing
/// to ask of a caller who was told batching is handled.
class _LifecycleFlusher extends WidgetsBindingObserver {
  _LifecycleFlusher(this._onLeaveForeground);

  final void Function() _onLeaveForeground;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (shouldFlushForLifecycle(state)) _onLeaveForeground();
  }
}

/// Whether [state] means the app has left the foreground and queued events
/// should be sent now.
///
/// hidden and paused both mean the app is no longer on screen; detached is the
/// last callback before it goes away. All three are a last chance to send, and
/// flushing on more than one of them is harmless because the queue is emptied
/// by the first. inactive is excluded deliberately: it fires for a pulled-down
/// notification shade or an incoming call, where the app is usually about to
/// come straight back, and flushing there would send a part-full batch on every
/// interruption.
@visibleForTesting
bool shouldFlushForLifecycle(AppLifecycleState state) =>
    state == AppLifecycleState.hidden ||
    state == AppLifecycleState.paused ||
    state == AppLifecycleState.detached;

/// The main entry point for the Tolinku SDK.
///
/// Use [Tolinku.configure] to initialize the SDK, then access the singleton
/// via [Tolinku.instance].
///
/// ```dart
/// Tolinku.configure(apiKey: 'tolk_pub_...');
/// await Tolinku.instance.track('custom.signup');
/// ```
class Tolinku {
  Tolinku._({
    required TolinkuHttpClient httpClient,
  }) : _httpClient = httpClient {
    _analytics = Analytics(_httpClient);
    _ecommerce = Ecommerce(_httpClient, () => _userId);
    _referrals = Referrals(_httpClient);
    _deferred = Deferred(_httpClient);
    _links = Links(_httpClient);
    _messages = Messages(_httpClient);
  }

  static Tolinku? _instance;

  final TolinkuHttpClient _httpClient;
  late final Analytics _analytics;
  late final Ecommerce _ecommerce;
  late final Referrals _referrals;
  late final Deferred _deferred;
  late final Links _links;
  late final Messages _messages;

  /// The current user ID for segment targeting and analytics attribution.
  String? _userId;

  /// Registered in [configure], removed in [dispose]. Null when there was no
  /// widgets binding to register with.
  _LifecycleFlusher? _lifecycleFlusher;

  /// Whether the background-flush observer is currently attached.
  @visibleForTesting
  bool get hasLifecycleFlusher => _lifecycleFlusher != null;

  /// Starts flushing on background, if there is a binding to observe.
  ///
  /// Wrapped because [WidgetsBinding.instance] asserts when the binding has not
  /// been initialized, which happens when [configure] is called before
  /// `WidgetsFlutterBinding.ensureInitialized()` or from a plain Dart test.
  /// Failing to observe the lifecycle is not a reason to fail configuration, so
  /// this degrades to the old manual behaviour instead of throwing.
  /// Flushes without letting a failure escape.
  ///
  /// [flush] rethrows, which is right when the caller awaited it and can
  /// decide what to do. Nothing awaits this one: it is started from a lifecycle
  /// callback as the app leaves the foreground, so an error here would become
  /// an unhandled asynchronous error, reported by the zone and shown as a
  /// crash, for a background send the app never asked for.
  ///
  /// Swallowing it is safe because both queues put their events back on
  /// failure, so nothing is lost and the next flush retries them.
  Future<void> _flushQuietly() async {
    try {
      await flush();
    } catch (e) {
      _debugLog('Background flush failed; events stay queued to retry: $e');
    }
  }

  void _startLifecycleFlush() {
    try {
      final flusher = _LifecycleFlusher(() => unawaited(_flushQuietly()));
      WidgetsBinding.instance.addObserver(flusher);
      _lifecycleFlusher = flusher;
    } catch (_) {
      _debugLog(
        'No widgets binding available, so queued events will not be flushed '
        'automatically on background. Call flush() yourself, or call '
        'WidgetsFlutterBinding.ensureInitialized() before configure().',
      );
    }
  }

  void _stopLifecycleFlush() {
    final flusher = _lifecycleFlusher;
    if (flusher == null) return;
    try {
      WidgetsBinding.instance.removeObserver(flusher);
    } catch (_) {
      // Binding already gone; nothing to detach from.
    }
    _lifecycleFlusher = null;
  }

  /// Configures the Tolinku SDK with the given [apiKey] and optional [baseUrl].
  ///
  /// This must be called before accessing [instance].
  ///
  /// If [debug] is true, the SDK will log HTTP requests and other diagnostic
  /// information via [print].
  ///
  /// The [baseUrl] must use HTTPS, unless it points to a local development
  /// server (localhost, 10.x, 192.168.x, or 127.0.0.1).
  ///
  /// Calling [configure] when the SDK is already configured will log a warning
  /// and return without reconfiguring. Call [dispose] first to reconfigure.
  ///
  /// The [apiKey] should be a publishable key (starts with `tolk_pub_`).
  ///
  /// Throws [ArgumentError] if [apiKey] is empty or [baseUrl] is invalid.
  static void configure({
    required String apiKey,
    String baseUrl = 'https://api.tolinku.com',
    bool debug = false,
    @visibleForTesting http.Client? httpClient,
  }) {
    // Validate apiKey.
    if (apiKey.trim().isEmpty) {
      throw ArgumentError.value(
        apiKey,
        'apiKey',
        'API key must not be empty.',
      );
    }

    // Validate baseUrl format.
    final Uri parsedUrl;
    try {
      parsedUrl = Uri.parse(baseUrl);
    } catch (_) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'Base URL is not a valid URI.',
      );
    }

    if (!parsedUrl.hasScheme || parsedUrl.host.isEmpty) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'Base URL must include a scheme and host.',
      );
    }

    // Enforce HTTPS (with local development exceptions).
    if (parsedUrl.scheme != 'https') {
      if (parsedUrl.scheme == 'http' && _localHttpPattern.hasMatch(baseUrl)) {
        // Allow HTTP for local development.
      } else {
        throw ArgumentError.value(
          baseUrl,
          'baseUrl',
          'Base URL must use HTTPS. HTTP is only allowed for local '
              'development (localhost, 10.x, 192.168.x, 127.0.0.1).',
        );
      }
    }

    // Set debug mode.
    setTolinkuDebugMode(debug);

    // Warn if already configured.
    if (_instance != null) {
      _debugLog(
        'WARNING: Tolinku.configure() called while already configured. '
        'Call dispose() first to reconfigure.',
      );
      return;
    }

    final client = TolinkuHttpClient(
      baseUrl: baseUrl,
      apiKey: apiKey,
      httpClient: httpClient,
    );
    _instance = Tolinku._(httpClient: client);
    _instance!._startLifecycleFlush();
    _debugLog('Tolinku SDK v$tolinkuSdkVersion configured');
  }

  /// Returns the configured [Tolinku] singleton.
  ///
  /// Throws a [TolinkuException] if [configure] has not been called.
  static Tolinku get instance {
    if (_instance == null) {
      throw const TolinkuException(
        'Tolinku has not been configured. '
        'Call Tolinku.configure() before accessing the instance.',
      );
    }
    return _instance!;
  }

  /// Whether the SDK has been configured.
  static bool get isConfigured => _instance != null;

  /// Analytics event tracking.
  Analytics get analytics => _analytics;

  /// Ecommerce event tracking (purchases, carts, products, revenue).
  Ecommerce get ecommerce => _ecommerce;

  /// Referral management.
  Referrals get referrals => _referrals;

  /// Deferred deep link claiming.
  Deferred get deferred => _deferred;

  /// Turning a link the app was handed into the route and token it means.
  ///
  /// Needed for short links, which arrive as an opaque code that nothing on the
  /// device can interpret. See [Links.resolve].
  Links get links => _links;

  /// In-app message fetching.
  Messages get messages => _messages;

  /// The current user ID, or null if not set.
  String? get userId => _userId;

  /// Set the user ID for segment targeting and analytics attribution.
  /// Pass null to clear the user ID.
  void setUserId(String? userId) {
    _userId = userId;
  }

  /// Convenience method to track a custom event.
  ///
  /// This is equivalent to calling `Tolinku.instance.analytics.track(...)`.
  /// If a userId has been set, it is automatically injected into event properties.
  Future<void> track(
    String eventType, {
    Map<String, dynamic>? properties,
  }) {
    final mergedProperties = _userId != null
        ? <String, dynamic>{'user_id': _userId!, ...?properties}
        : properties;
    return _analytics.track(eventType, properties: mergedProperties);
  }

  /// Reports that a link opened the app, when it opened without the browser.
  ///
  /// Equivalent to `Tolinku.instance.analytics.trackLinkOpen(...)`, with the
  /// user ID attached when one has been set.
  ///
  /// A Universal Link or App Link hands the app the URL directly, so Tolinku is
  /// never contacted and the tap goes unrecorded. Those taps come from people
  /// who already have your app, so leaving them out makes a re-engagement
  /// campaign look like a failure exactly when it worked.
  ///
  /// Call it wherever the app receives an incoming link, passing the URL
  /// unchanged:
  ///
  /// Both ways a link arrives need it. The stream fires only while the app is
  /// already running, so a link that launched the app cold arrives separately:
  ///
  /// ```dart
  /// // Launched by a link, app was not running.
  /// final initial = await appLinks.getInitialAppLink();
  /// if (initial != null) {
  ///   Tolinku.instance.trackLinkOpen(initial.toString());
  /// }
  ///
  /// // Tapped while the app was already open.
  /// appLinks.uriLinkStream.listen((uri) {
  ///   Tolinku.instance.trackLinkOpen(uri.toString());
  ///   // your own routing
  /// });
  /// ```
  ///
  /// Wiring both is safe. Some plugins deliver the launching link on the stream
  /// too, and the same link arriving twice in quick succession is reported once.
  ///
  /// Only http and https links are reported. A custom scheme means Tolinku's own
  /// hand-off page opened the app, and that tap was counted when the page was
  /// served, so passing one does nothing rather than counting it twice.
  ///
  /// Never throws and never blocks.
  Future<void> trackLinkOpen(String url) =>
      _analytics.trackLinkOpen(url, userId: _userId);

  /// Flushes any queued analytics events to the server.
  ///
  /// This delegates to [Analytics.flush] and [Ecommerce.flush]. Both are
  /// flushed automatically when the app leaves the foreground, so calling this
  /// by hand is only needed to send a batch earlier than that.
  Future<void> flush() async {
    await _analytics.flush();
    await _ecommerce.flush();
  }

  /// Tears down the SDK and releases its resources.
  ///
  /// The name the other Tolinku SDKs use for this. [dispose] does the same
  /// thing and still works; it is what this package shipped, and `dispose` is
  /// also the ordinary Dart name for it, so it is not going anywhere soon.
  /// [destroy] exists so an app sharing code across platforms can call one name
  /// everywhere.
  Future<void> destroy() => dispose();

  /// Closes the underlying HTTP client and resets the singleton.
  ///
  /// Flushes any remaining analytics and ecommerce events before cleaning up.
  /// After calling this, [configure] must be called again before using the
  /// SDK.
  ///
  /// [destroy] is the same call under the name the other Tolinku SDKs use.
  Future<void> dispose() async {
    _stopLifecycleFlush();
    await _analytics.dispose();
    await _ecommerce.dispose();
    _httpClient.close();
    _instance = null;
    _debugLog('Tolinku SDK disposed');
  }

  /// Parses a deep link URI string into its route path and query parameters.
  ///
  /// Returns a record containing the path and a map of query parameters.
  /// Throws [ArgumentError] if [uri] is empty or cannot be parsed.
  static ({String path, Map<String, String> queryParams}) parseDeepLink(
    String uri,
  ) {
    if (uri.trim().isEmpty) {
      throw ArgumentError.value(
        uri,
        'uri',
        'Deep link URI must not be empty.',
      );
    }

    final parsed = Uri.tryParse(uri);
    if (parsed == null) {
      throw ArgumentError.value(
        uri,
        'uri',
        'Could not parse deep link URI.',
      );
    }

    return (
      path: parsed.path,
      queryParams: parsed.queryParameters,
    );
  }

  static void _debugLog(String message) {
    if (isTolinkuDebugMode) {
      // ignore: avoid_print
      print('[TolinkuSDK] $message');
    }
  }
}
