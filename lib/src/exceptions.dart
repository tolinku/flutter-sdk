/// Exception thrown by the Tolinku SDK when an API call fails
/// or the SDK is used incorrectly.
class TolinkuException implements Exception {
  /// Creates a [TolinkuException] with the given [message] and optional
  /// [statusCode], [retryAfter] duration, and [code].
  const TolinkuException(
    this.message, {
    this.statusCode,
    this.retryAfter,
    this.code,
  });

  /// A human-readable description of the error.
  final String message;

  /// The HTTP status code, if the error originated from an API response.
  final int? statusCode;

  /// The server-requested retry delay for 429 responses.
  final Duration? retryAfter;

  /// The machine-readable error code from the server (e.g. APPSPACE_FROZEN, FEATURE_GATED).
  final String? code;

  @override
  String toString() {
    if (statusCode != null) {
      return 'TolinkuException($statusCode): $message';
    }
    return 'TolinkuException: $message';
  }
}

/// Exception thrown when a request is attempted after the client has been
/// disposed or when an in-flight request is cancelled.
///
/// This allows callers to distinguish request cancellation from other errors.
class TolinkuCancelledException implements Exception {
  /// Creates a [TolinkuCancelledException].
  const TolinkuCancelledException();

  @override
  String toString() => 'TolinkuCancelledException: HTTP client has been disposed';
}
