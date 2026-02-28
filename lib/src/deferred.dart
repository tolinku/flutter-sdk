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
  /// [appspaceId] is required. The remaining parameters (timezone, language,
  /// screen dimensions) are optional because this is a pure Dart package and
  /// cannot access device info directly; the caller should provide them.
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
        },
        authenticated: false,
      );
      return DeferredLink.fromJson(data);
    } on TolinkuException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }
}
