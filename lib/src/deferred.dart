import 'exceptions.dart';
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
