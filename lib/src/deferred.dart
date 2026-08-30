import 'exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'install_referrer.dart';
import 'install_referrer_native.dart';
import 'http_client.dart';
import 'models.dart';

/// Provides deferred deep link claiming via the Tolinku API.
class Deferred {
  /// Creates a [Deferred] instance backed by the given [httpClient].
  const Deferred(this._httpClient);

  final TolinkuHttpClient _httpClient;

  /// Claims a deferred deep link by its [token].
  ///
  /// Returns a [DeferredLink] if a match is found, or `null` if no deferred
  /// link exists for the given token.
  ///
  /// Throws [ArgumentError] if [token] is empty.
  /// Throws [TolinkuException] if the request fails for reasons other than
  /// "not found".
  Future<DeferredLink?> claim({required String token}) async {
    if (token.trim().isEmpty) {
      throw ArgumentError.value(
        token,
        'token',
        'Deferred link token must not be empty.',
      );
    }

    try {
      final data = await _httpClient.get(
        '/v1/api/deferred/claim',
        queryParams: {'token': token},
        authenticated: false,
      );
      return DeferredLink.fromJson(data);
    } on TolinkuException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Recovers the link that led to this install, trying both mechanisms.
  ///
  /// The Play Install Referrer is asked first when a [referrerProvider] is
  /// given: it names the exact click, survives for days, and does not depend on
  /// which network the device was on. Device signals are the fallback, and the
  /// only option on iOS, where no equivalent exists.
  ///
  /// Call once on first launch. Calling again is safe, but a claim is consumed
  /// the first time it succeeds, so a second call returns `null`.
  ///
  /// The referrer is read by this package's own Android plugin, so nothing
  /// extra needs installing. Pass [referrerProvider] only to override that,
  /// for instance in a test. Where the plugin is unavailable the lookup simply
  /// returns nothing and Android falls back to signal matching.
  Future<DeferredLink?> claimDeferredLink({
    required String appspaceId,
    ReferrerProvider? referrerProvider,
    bool force = false,
  }) async {
    if (appspaceId.trim().isEmpty) {
      throw ArgumentError.value(
        appspaceId,
        'appspaceId',
        'Appspace ID must not be empty.',
      );
    }

    // Claiming is a first-launch action, but nothing stops an app calling this
    // on every launch. Each repeat costs a request and records a miss, so a
    // healthy integration would report a match rate near zero.
    if (!force && await _alreadyAttempted()) return null;

    final provider = referrerProvider ?? nativeReferrerProvider;
    {
      String? token;
      try {
        token = parseInstallReferrer(await provider());
      } catch (_) {
        // A provider that fails is not worth losing the install over.
        token = null;
      }
      if (token != null) {
        try {
          final byToken = await claim(token: token);
          if (byToken != null) {
            await _rememberAttempt();
            return byToken;
          }
        } on TolinkuException {
          // Fall through to signals: the install still happened.
        }
      }
    }

    // claimBySignals returns null only for a 404, a real "nothing waiting", and
    // rethrows anything else. So reaching past it means the server answered,
    // and only an answer is worth remembering: recording a dropped request
    // would spend the install's one chance at attribution on a bad connection.
    final bySignals = await claimBySignals(appspaceId: appspaceId);
    await _rememberAttempt();
    return bySignals;
  }

  static const String _claimedKey = 'tolinku_deferred_claimed';

  Future<bool> _alreadyAttempted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_claimedKey);
    } catch (_) {
      // Storage unavailable: attempt the claim rather than skip it.
      return false;
    }
  }

  Future<void> _rememberAttempt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_claimedKey, DateTime.now().toIso8601String());
    } catch (_) {
      // Not worth failing a claim that already succeeded.
    }
  }

  /// Claims a deferred deep link by matching device signals.
  ///
  /// [appspaceId] is required. The remaining parameters are optional because this
  /// is a pure Dart package and cannot read device info directly; the caller
  /// should supply them.
  ///
  /// Supply as many as you can. Matching compares timezone, language, screen size,
  /// [devicePixelRatio] and [osVersion], and needs at least two of them to agree.
  /// [devicePixelRatio] is the sharpest of them, since it separates devices that
  /// report the same logical dimensions: pass `MediaQuery.of(context).devicePixelRatio`
  /// (the same value you divide `physicalSize` by to get [screenWidth]).
  ///
  /// Returns a [DeferredLink] if a match is found, or `null` otherwise.
  ///
  /// Throws [ArgumentError] if [appspaceId] is empty.
  /// Throws [TolinkuException] if the request fails for reasons other than
  /// "not found".
  Future<DeferredLink?> claimBySignals({
    required String appspaceId,
    String? timezone,
    String? language,
    int? screenWidth,
    int? screenHeight,
    double? devicePixelRatio,
    String? osVersion,
  }) async {
    if (appspaceId.trim().isEmpty) {
      throw ArgumentError.value(
        appspaceId,
        'appspaceId',
        'Appspace ID must not be empty.',
      );
    }

    try {
      final data = await _httpClient.post(
        '/v1/api/deferred/claim-by-signals',
        body: {
          'appspace_id': appspaceId,
          if (timezone != null) 'timezone': timezone,
          if (language != null) 'language': language,
          if (screenWidth != null) 'screen_width': screenWidth,
          if (screenHeight != null) 'screen_height': screenHeight,
          if (devicePixelRatio != null) 'device_pixel_ratio': devicePixelRatio,
          if (osVersion != null) 'os_version': osVersion,
        },
        authenticated: false,
      );
      return DeferredLink.fromJson(data);
    } on TolinkuException catch (e) {
      if (e.statusCode == 404) {
        // A genuine "nothing is waiting for this device". Expected on most calls.
        tolinkuDebugLog(
          'claimBySignals: no match for appspaceId "$appspaceId". '
          'If this never matches, confirm appspaceId is your Appspace ID '
          '(copy it from the dashboard under Settings), not your subdomain or slug.',
        );
        return null;
      }
      // Anything else is a real problem the integrator needs to see. A 403 here
      // means the appspaceId is wrong or belongs to another domain.
      tolinkuDebugLog(
        'claimBySignals failed: HTTP ${e.statusCode} ${e.message}',
      );
      rethrow;
    }
  }
}
