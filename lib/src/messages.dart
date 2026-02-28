import 'package:flutter/widgets.dart';

import 'http_client.dart';
import 'message_presenter.dart';
import 'models.dart';
import 'tolinku_client.dart';

/// Provides in-app message fetching and display via the Tolinku API.
class Messages {
  /// Creates a [Messages] instance backed by the given [httpClient].
  const Messages(this._httpClient);

  final TolinkuHttpClient _httpClient;

  /// Fetches messages, optionally filtered by [trigger].
  ///
  /// Returns a list of [TolinkuMessage] objects. The caller is responsible
  /// for rendering them in the UI, or use [show] for automatic display.
  ///
  /// Throws [ArgumentError] if [trigger] is provided but empty.
  Future<List<TolinkuMessage>> fetch({String? trigger}) async {
    if (trigger != null && trigger.trim().isEmpty) {
      throw ArgumentError.value(
        trigger,
        'trigger',
        'Trigger must not be empty when provided.',
      );
    }

    final queryParams = <String, String>{};
    if (trigger != null) {
      queryParams['trigger'] = trigger;
    }
    final userId = Tolinku.isConfigured ? Tolinku.instance.userId : null;
    if (userId != null) {
      queryParams['user_id'] = userId;
    }
    final data = await _httpClient.get(
      '/v1/api/messages',
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );
    final list = data['messages'] as List<dynamic>? ?? [];
    return list
        .map((e) => TolinkuMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Requests a short-lived render token for loading message HTML in a WebView.
  ///
  /// The token is scoped to the given message and expires after 5 minutes.
  /// Use it to load the render URL without exposing the API key.
  ///
  /// Throws [ArgumentError] if [messageId] is empty.
  Future<String> renderToken(String messageId) async {
    if (messageId.trim().isEmpty) {
      throw ArgumentError.value(
        messageId,
        'messageId',
        'Message ID must not be empty.',
      );
    }

    final encodedId = Uri.encodeComponent(messageId);
    final data = await _httpClient.post(
      '/v1/api/messages/$encodedId/render-token',
    );
    return data['token'] as String;
  }

  /// Fetches, filters, and shows the highest-priority undismissed message.
  ///
  /// This convenience method fetches messages (optionally filtered by
  /// [trigger]), removes any that have been dismissed within their
  /// suppression window, sorts by priority (highest first), and displays
  /// the top message in a full-screen WebView dialog.
  ///
  /// [onAction] is called when the message triggers a navigation, receiving
  /// the URL string. [onDismiss] is called when the message is closed.
  ///
  /// Does nothing if no eligible messages are available.
  Future<void> show(
    BuildContext context, {
    String? trigger,
    Function(String)? onAction,
    VoidCallback? onDismiss,
  }) async {
    final messages = await fetch(trigger: trigger);

    if (messages.isEmpty) return;

    // Filter out dismissed and suppressed messages.
    final eligible = <TolinkuMessage>[];
    for (final message in messages) {
      final dismissed =
          await TolinkuMessagePresenter.isMessageDismissed(message);
      if (dismissed) continue;
      final suppressed =
          await TolinkuMessagePresenter.isMessageSuppressed(message);
      if (!suppressed) {
        eligible.add(message);
      }
    }

    if (eligible.isEmpty) return;

    // Sort by priority, highest first.
    eligible.sort((a, b) => b.priority.compareTo(a.priority));

    final topMessage = eligible.first;

    await TolinkuMessagePresenter.recordImpression(topMessage.id);

    // Fetch a render token before showing the dialog.
    final token = await renderToken(topMessage.id);

    // Verify the context is still mounted before showing the dialog.
    if (!context.mounted) return;

    await TolinkuMessagePresenter.show(
      context,
      topMessage,
      baseUrl: _httpClient.baseUrl,
      renderToken: token,
      onAction: onAction,
      onDismiss: onDismiss,
    );
  }
}
