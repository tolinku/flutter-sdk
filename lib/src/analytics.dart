import 'dart:async';

import 'http_client.dart';

/// Regular expression for valid custom event names.
final RegExp _eventNamePattern = RegExp(r'^custom\.[a-z0-9_]+$');

/// Maximum number of events to queue before auto-flushing.
const int _batchSize = 10;

/// Maximum queue size to prevent unbounded memory growth.
const int maxQueueSize = 1000;

/// Interval between automatic flushes.
const Duration _flushInterval = Duration(seconds: 5);

/// Provides analytics event tracking via the Tolinku API.
///
/// Events are queued in memory and sent in batches. The queue is flushed
/// automatically when it reaches [_batchSize] events, every [_flushInterval],
/// or when [flush] or [dispose] is called.
class Analytics {
  /// Creates an [Analytics] instance backed by the given [httpClient].
  Analytics(this._httpClient) {
    _startFlushTimer();
  }

  final TolinkuHttpClient _httpClient;
  final List<Map<String, dynamic>> _queue = [];
  Timer? _flushTimer;
  bool _disposed = false;

  /// Tracks a custom event.
  ///
  /// [eventType] must match the pattern `custom.[a-z0-9_]+`. If the name does
  /// not start with "custom.", the prefix is added automatically. If the name
  /// is invalid after prefixing, an [ArgumentError] is thrown.
  ///
  /// Optional [properties] can include any additional data to attach to the
  /// event.
  Future<void> track(
    String eventType, {
    Map<String, dynamic>? properties,
  }) async {
    if (eventType.trim().isEmpty) {
      throw ArgumentError.value(
        eventType,
        'eventType',
        'Event type must not be empty.',
      );
    }

    // Auto-prefix with "custom." if missing.
    var normalizedName = eventType;
    if (!normalizedName.startsWith('custom.')) {
      normalizedName = 'custom.$normalizedName';
    }

    // Validate the final event name.
    if (!_eventNamePattern.hasMatch(normalizedName)) {
      throw ArgumentError.value(
        eventType,
        'eventType',
        'Event type must match pattern "custom.[a-z0-9_]+" '
            '(after auto-prefixing: "$normalizedName").',
      );
    }

    final event = <String, dynamic>{
      'event_type': normalizedName,
      if (properties != null) 'properties': properties,
    };

    _queue.add(event);

    // Prevent unbounded queue growth.
    if (_queue.length > maxQueueSize) {
      _debugLog('Queue exceeded max size ($maxQueueSize), dropping oldest event');
      _queue.removeAt(0);
    }

    // Auto-flush when batch size is reached.
    if (_queue.length >= _batchSize) {
      await flush();
    }
  }

  /// Flushes all queued events to the server.
  ///
  /// This is safe to call even if the queue is empty.
  Future<void> flush() async {
    if (_queue.isEmpty) return;

    // Take a snapshot of the current queue and clear it.
    final events = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();

    try {
      final result = await _httpClient.postBatch(
        '/v1/api/analytics/batch',
        events: events,
      );
      final errors = result['errors'] as List<dynamic>?;
      if (errors != null && errors.isNotEmpty) {
        _debugLog('Batch partial failure: $errors');
      }
      _debugLog('Flushed ${events.length} analytics events');
    } catch (e) {
      // Re-add events to the front of the queue on failure so they
      // can be retried on the next flush (the HTTP client already
      // retries internally, so this handles permanent failures).
      _queue.insertAll(0, events);

      // Trim if re-adding caused overflow.
      while (_queue.length > maxQueueSize) {
        _queue.removeAt(0);
      }

      _debugLog('Failed to flush analytics events: $e');
      rethrow;
    }
  }

  /// Releases resources held by this instance.
  ///
  /// Flushes remaining events before cleaning up. After calling this,
  /// no further events should be tracked.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    try {
      await flush();
    } catch (_) {
      // Best-effort flush on dispose; swallow errors.
    }
  }

  void _startFlushTimer() {
    _flushTimer = Timer.periodic(_flushInterval, (_) {
      if (_queue.isNotEmpty && !_disposed) {
        flush().catchError((_) {
          // Swallow errors from timer-triggered flushes.
        });
      }
    });
  }

  void _debugLog(String message) {
    if (isTolinkuDebugMode) {
      // ignore: avoid_print
      print('[TolinkuSDK Analytics] $message');
    }
  }
}
