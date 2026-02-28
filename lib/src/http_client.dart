import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'exceptions.dart';

/// SDK version constant.
const String tolinkuSdkVersion = '0.1.0';

/// Maximum number of retry attempts for failed requests.
const int _maxRetries = 3;

/// Base delay for exponential backoff (in milliseconds).
const int _baseDelayMs = 500;

/// Maximum random jitter added to backoff (in milliseconds).
const int _maxJitterMs = 250;

/// Whether debug logging is enabled globally.
bool _debugMode = false;

/// Enables or disables debug logging for the Tolinku SDK.
void setTolinkuDebugMode(bool enabled) {
  _debugMode = enabled;
}

/// Returns true if debug mode is currently enabled.
bool get isTolinkuDebugMode => _debugMode;

/// Logs a message when debug mode is enabled.
void _debugLog(String message) {
  if (_debugMode) {
    // ignore: avoid_print
    print('[TolinkuSDK] $message');
  }
}

/// Internal HTTP client for making API requests to the Tolinku platform.
///
/// This class is not part of the public API. Use [Tolinku] instead.
class TolinkuHttpClient {
  /// Creates a new [TolinkuHttpClient].
  ///
  /// [baseUrl] is the base URL of the Tolinku server (defaults to
  /// "https://api.tolinku.com"). [apiKey] is the API key used for
  /// authenticated endpoints.
  TolinkuHttpClient({
    required this.baseUrl,
    required this.apiKey,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  /// The base URL for all API requests.
  final String baseUrl;

  /// The API key sent as X-API-Key header.
  final String apiKey;

  final http.Client _client;

  bool _disposed = false;

  final Random _random = Random();

  /// Whether this client has been disposed.
  bool get isDisposed => _disposed;

  /// Sends a GET request to the given [path] with optional [queryParams].
  ///
  /// If [authenticated] is true (the default), the X-API-Key header is
  /// included.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParams,
    bool authenticated = true,
  }) async {
    return _requestWithRetry(() async {
      _checkDisposed();
      final uri = _buildUri(path, queryParams);
      _debugLog('GET $uri');
      final response =
          await _client.get(uri, headers: _headers(authenticated));
      return _handleResponse(response);
    });
  }

  /// Sends a POST request to the given [path] with a JSON [body].
  ///
  /// If [authenticated] is true (the default), the X-API-Key header is
  /// included.
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    return _requestWithRetry(() async {
      _checkDisposed();
      final uri = _buildUri(path);
      _debugLog('POST $uri');
      final response = await _client.post(
        uri,
        headers: {
          ..._headers(authenticated),
          'Content-Type': 'application/json',
        },
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    });
  }

  /// Sends a POST request that returns the raw response status and body,
  /// used internally by the analytics batch endpoint.
  ///
  /// Returns the parsed JSON body. Applies retry logic.
  Future<Map<String, dynamic>> postBatch(
    String path, {
    required List<Map<String, dynamic>> events,
    bool authenticated = true,
  }) async {
    return _requestWithRetry(() async {
      _checkDisposed();
      final uri = _buildUri(path);
      _debugLog('POST (batch) $uri with ${events.length} events');
      final response = await _client.post(
        uri,
        headers: {
          ..._headers(authenticated),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'events': events}),
      );
      return _handleResponse(response);
    });
  }

  Future<Map<String, dynamic>> _requestWithRetry(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      // Check disposed flag before each retry attempt.
      _checkDisposed();

      try {
        return await request();
      } on TolinkuException catch (e) {
        // Do not retry on 4xx errors (except 429).
        if (e.statusCode != null &&
            e.statusCode! >= 400 &&
            e.statusCode! < 500 &&
            e.statusCode != 429) {
          rethrow;
        }

        if (attempt == _maxRetries) {
          rethrow;
        }

        final delay = _calculateDelay(attempt, retryAfter: e.retryAfter);
        _debugLog(
          'Request failed (status ${e.statusCode}), '
          'retrying in ${delay.inMilliseconds}ms '
          '(attempt ${attempt + 1}/$_maxRetries)',
        );
        await Future<void>.delayed(delay);
      } on http.ClientException {
        // Network/socket errors are retryable.
        if (attempt == _maxRetries) {
          rethrow;
        }

        final delay = _calculateDelay(attempt);
        _debugLog(
          'Network error, retrying in ${delay.inMilliseconds}ms '
          '(attempt ${attempt + 1}/$_maxRetries)',
        );
        await Future<void>.delayed(delay);
      } on TolinkuCancelledException {
        rethrow;
      }
    }

    // This should never be reached, but the compiler needs it.
    throw const TolinkuException('Max retries exceeded');
  }

  Duration _calculateDelay(int attempt, {Duration? retryAfter}) {
    if (retryAfter != null) {
      return retryAfter;
    }
    final exponentialDelay = _baseDelayMs * pow(2, attempt).toInt();
    final jitter = _random.nextInt(_maxJitterMs);
    return Duration(milliseconds: exponentialDelay + jitter);
  }

  void _checkDisposed() {
    if (_disposed) {
      throw const TolinkuCancelledException();
    }
  }

  Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse('$base$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }
    return uri;
  }

  Map<String, String> _headers(bool authenticated) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'User-Agent': 'TolinkuFlutterSDK/$tolinkuSdkVersion',
    };
    if (authenticated) {
      headers['X-API-Key'] = apiKey;
    }
    return headers;
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final Map<String, dynamic> data;

    // Parse Retry-After header for 429 responses.
    Duration? retryAfter;
    if (response.statusCode == 429) {
      final retryHeader = response.headers['retry-after'];
      if (retryHeader != null) {
        final seconds = int.tryParse(retryHeader);
        if (seconds != null) {
          retryAfter = Duration(seconds: seconds);
        }
      }
    }

    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      if (response.statusCode >= 400) {
        throw TolinkuException(
          'Request failed with status ${response.statusCode}',
          statusCode: response.statusCode,
          retryAfter: retryAfter,
        );
      }
      // Non-JSON successful responses should throw instead of returning empty.
      throw TolinkuException(
        'Expected JSON response but received non-JSON body '
        '(status ${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 400) {
      final message = data['error'] as String? ??
          data['message'] as String? ??
          'Request failed with status ${response.statusCode}';
      final errorCode = data['code'] as String?;
      throw TolinkuException(
        message,
        statusCode: response.statusCode,
        retryAfter: retryAfter,
        code: errorCode,
      );
    }

    return data;
  }

  /// Closes the underlying HTTP client and marks this instance as disposed.
  ///
  /// Any in-flight requests will fail with a [TolinkuCancelledException].
  void close() {
    _disposed = true;
    _client.close();
  }
}
