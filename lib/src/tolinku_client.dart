import 'analytics.dart';
import 'deferred.dart';
import 'ecommerce.dart';
import 'exceptions.dart';
import 'http_client.dart';
import 'messages.dart';
import 'referrals.dart';

/// Regular expression for URLs allowed to use HTTP (local development only).
final RegExp _localHttpPattern = RegExp(
  r'^http://(localhost|10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.|127\.0\.0\.1)',
);

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
    _messages = Messages(_httpClient);
  }

  static Tolinku? _instance;

  final TolinkuHttpClient _httpClient;
  late final Analytics _analytics;
  late final Ecommerce _ecommerce;
  late final Referrals _referrals;
  late final Deferred _deferred;
  late final Messages _messages;

  /// The current user ID for segment targeting and analytics attribution.
  String? _userId;

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

    final httpClient = TolinkuHttpClient(
      baseUrl: baseUrl,
      apiKey: apiKey,
    );
    _instance = Tolinku._(httpClient: httpClient);
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

  /// Flushes any queued analytics events to the server.
  ///
  /// This delegates to [Analytics.flush]. Call this when the app goes to
  /// background if you are not using a lifecycle observer.
  Future<void> flush() async {
    await _analytics.flush();
    await _ecommerce.flush();
  }

  /// Closes the underlying HTTP client and resets the singleton.
  ///
  /// Flushes any remaining analytics and ecommerce events before cleaning up.
  /// After calling this, [configure] must be called again before using the
  /// SDK.
  Future<void> dispose() async {
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
