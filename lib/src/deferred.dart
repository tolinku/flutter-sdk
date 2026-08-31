import 'exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_signals.dart';
import 'device_signals_native.dart';
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
  ///
  /// Prefer [claimByToken], which is the name every other Tolinku SDK uses.
  /// This one is kept because it is what 0.3.0 shipped and breaking it would
  /// serve nobody. It is intended for deprecation in a later release, once
  /// enough time has passed that moving is a one-line change rather than a
  /// surprise; it is deliberately not marked deprecated yet, because doing so
  /// would put an analyzer warning in every existing integration today for a
  /// rename that changes nothing about behaviour.
  Future<DeferredLink?> claim({required String token, String? appspaceId}) async {
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
        // appspaceId narrows what the token may claim, never widens it, and it
        // is what lets a failed claim be attributed: the default host resolves
        // to no Appspace, so without it a miss belongs to nobody.
        queryParams: {
          'token': token,
          if (appspaceId != null) 'appspace_id': appspaceId,
        },
        authenticated: false,
      );
      return DeferredLink.fromJson(data);
    } on TolinkuException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Claims a deferred deep link by its [token].
  ///
  /// The same call as [claim], under the name the other Tolinku SDKs use. This
  /// package shipped it as `claim`, so both work and neither is deprecated:
  /// existing code keeps compiling, and code moved across from the Android,
  /// iOS, React Native or web SDKs compiles too, rather than failing on a name
  /// that exists everywhere except here.
  ///
  /// Use this when you already hold a token. To have the token looked up for
  /// you, see [claimDeferredLink]. Neither is preferred over the other; they
  /// differ in how much the SDK does on your behalf.
  Future<DeferredLink?> claimByToken({
    required String token,
    String? appspaceId,
  }) =>
      claim(token: token, appspaceId: appspaceId);

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
  ///
  /// Device signals are collected for you, so nothing needs passing. Language,
  /// screen size and pixel ratio come from Dart; timezone and OS version come
  /// from this package's own Android and iOS plugins, because Dart cannot
  /// express either in the form matching compares against (it offers `KST`
  /// where matching wants `Asia/Seoul`).
  ///
  /// Pass any of [timezone], [language], [screenWidth], [screenHeight],
  /// [devicePixelRatio] or [osVersion] to override one; a value given here is
  /// always used ahead of the collected one. Signals are skipped when absent
  /// rather than counted as a failed comparison, so a signal that cannot be
  /// read costs nothing beyond a weaker match.
  ///
  /// Returns `null` when nothing is waiting for this device, which is the
  /// ordinary outcome for an organic install.
  ///
  /// Throws [TolinkuException] if the server answers with anything other than a
  /// 404, and rethrows a network failure. Both are surfaced rather than
  /// swallowed, because the usual cause is a misconfiguration worth seeing: a
  /// 403 means the Appspace ID is wrong or belongs to another domain. Wrap the
  /// call if a first launch must never fail on it. Nothing is recorded as
  /// attempted unless the server actually answered, so a claim lost to a bad
  /// connection is retried on the next launch rather than spent.
  Future<DeferredLink?> claimDeferredLink({
    required String appspaceId,
    String? timezone,
    String? language,
    int? screenWidth,
    int? screenHeight,
    double? devicePixelRatio,
    String? osVersion,
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
          final byToken = await claim(token: token, appspaceId: appspaceId);
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
    // Signals have to be carried through. The matcher only compares fields
    // present on both sides, so claiming with none of them makes every candidate
    // incomparable and the call can never match. Anything the caller passed wins
    // over what the device reports, since a value from a platform plugin is
    // better than one inferred here.
    // Signals are collected by claimBySignals, which anything passed here
    // overrides. Collecting again first would only ask the platform channel for
    // the same values twice.
    final bySignals = await claimBySignals(
      appspaceId: appspaceId,
      timezone: timezone,
      language: language,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      devicePixelRatio: devicePixelRatio,
      osVersion: osVersion,
    );
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
  /// This is the direct call: you decide when the request goes out and you track
  /// whether you have already claimed. [claimDeferredLink] is the same match
  /// with the Play Install Referrer tried first and the claim-once bookkeeping
  /// done for you. Both are fully supported and neither is going away, so pick
  /// on how much you want the SDK to do.
  ///
  /// [appspaceId] is required. The signals are read from the device, and any you
  /// pass are used in preference to what is read, so pass one only when you hold
  /// a better value than the SDK can obtain.
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
      // Collected first, then overridden by anything the caller passed. Sending
      // only the Appspace ID can never match, because the matcher compares only
      // fields present on both the click and the claim and treats nothing
      // comparable as no match, so a caller who supplies less than the full set
      // is better served by the device's own values than by absence.
      final signals = (await collectAllDeviceSignals()).merge(DeviceSignals(
        timezone: timezone,
        language: language,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        devicePixelRatio: devicePixelRatio,
        osVersion: osVersion,
      ));

      final data = await _httpClient.post(
        '/v1/api/deferred/claim-by-signals',
        body: {
          'appspace_id': appspaceId,
          ...signals.toRequestBody(),
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
