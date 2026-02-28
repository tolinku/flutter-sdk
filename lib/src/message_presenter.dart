import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'models.dart';

/// Prefix used for SharedPreferences keys that track dismissed messages.
const String _dismissPrefix = 'tolinku_dismissed_';
const String _impressionsPrefix = 'tolinku_impressions_';
const String _lastShownPrefix = 'tolinku_last_shown_';

/// Handles rendering and dismissal tracking for in-app messages.
///
/// Messages are displayed in a full-screen transparent dialog containing a
/// WebView that loads server-rendered HTML from the messages render endpoint.
/// Communication between the WebView and native code happens via a
/// [JavaScriptChannel] named "Tolinku".
class TolinkuMessagePresenter {
  TolinkuMessagePresenter._();

  /// Shows a message in a full-screen WebView dialog.
  ///
  /// The [context] is used to display the dialog. The [message] determines
  /// which message to render. The [baseUrl] and [renderToken] are used to
  /// construct the render URL (no API key is sent to the WebView).
  ///
  /// [onAction] is called when the message triggers a navigation action,
  /// receiving the URL string. [onDismiss] is called when the message is
  /// closed by the user.
  static Future<void> show(
    BuildContext context,
    TolinkuMessage message, {
    required String baseUrl,
    required String renderToken,
    Function(String)? onAction,
    VoidCallback? onDismiss,
  }) async {
    final renderUrl = _buildRenderUrl(baseUrl, message.id, renderToken);

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _MessageDialog(
          renderUrl: renderUrl,
          message: message,
          onAction: onAction,
          onDismiss: onDismiss,
        );
      },
    );
  }

  /// Checks whether a message has been dismissed and is still within
  /// its suppression window.
  ///
  /// Returns true if the message was previously dismissed and the number
  /// of days since dismissal is less than [TolinkuMessage.dismissDays].
  /// If [dismissDays] is null, a dismissed message stays dismissed forever.
  static Future<bool> isMessageDismissed(TolinkuMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_dismissPrefix${message.id}';
    final dismissedAt = prefs.getString(key);

    if (dismissedAt == null) return false;

    final dismissedDate = DateTime.tryParse(dismissedAt);
    if (dismissedDate == null) return false;

    // If dismissDays is null, the message is dismissed indefinitely.
    if (message.dismissDays == null) return true;

    final daysSinceDismiss =
        DateTime.now().difference(dismissedDate).inDays;
    return daysSinceDismiss < message.dismissDays!;
  }

  /// Records the current date as the dismissal timestamp for the given
  /// message ID.
  static Future<void> markDismissed(String messageId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_dismissPrefix$messageId';
    await prefs.setString(key, DateTime.now().toIso8601String());
  }

  /// Checks whether a message should be suppressed based on max impressions
  /// or minimum interval between displays.
  ///
  /// Returns true if the message should NOT be shown.
  static Future<bool> isMessageSuppressed(TolinkuMessage message) async {
    final prefs = await SharedPreferences.getInstance();

    // Check max impressions
    if (message.maxImpressions != null && message.maxImpressions! > 0) {
      final key = '$_impressionsPrefix${message.id}';
      final count = prefs.getInt(key) ?? 0;
      if (count >= message.maxImpressions!) return true;
    }

    // Check min interval
    if (message.minIntervalHours != null && message.minIntervalHours! > 0) {
      final key = '$_lastShownPrefix${message.id}';
      final lastShownStr = prefs.getString(key);
      if (lastShownStr != null) {
        final lastShown = DateTime.tryParse(lastShownStr);
        if (lastShown != null) {
          final hoursSince = DateTime.now().difference(lastShown).inHours;
          if (hoursSince < message.minIntervalHours!) return true;
        }
      }
    }

    return false;
  }

  /// Records that a message was shown (increments impression count and
  /// updates last-shown timestamp).
  static Future<void> recordImpression(String messageId) async {
    final prefs = await SharedPreferences.getInstance();

    // Increment impression count
    final countKey = '$_impressionsPrefix$messageId';
    final count = prefs.getInt(countKey) ?? 0;
    await prefs.setInt(countKey, count + 1);

    // Update last-shown timestamp
    final shownKey = '$_lastShownPrefix$messageId';
    await prefs.setString(shownKey, DateTime.now().toIso8601String());
  }

  static String _buildRenderUrl(String baseUrl, String messageId, String token) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final encodedId = Uri.encodeComponent(messageId);
    final encodedToken = Uri.encodeQueryComponent(token);
    return '$base/v1/api/messages/$encodedId/render?token=$encodedToken';
  }
}

/// Internal stateful widget for the message dialog.
class _MessageDialog extends StatefulWidget {
  const _MessageDialog({
    required this.renderUrl,
    required this.message,
    this.onAction,
    this.onDismiss,
  });

  final String renderUrl;
  final TolinkuMessage message;
  final Function(String)? onAction;
  final VoidCallback? onDismiss;

  @override
  State<_MessageDialog> createState() => _MessageDialogState();
}

class _MessageDialogState extends State<_MessageDialog> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'Tolinku',
        onMessageReceived: _onBridgeMessage,
      )
      ..loadRequest(Uri.parse(widget.renderUrl));
  }

  void _onBridgeMessage(JavaScriptMessage jsMessage) {
    try {
      final data = jsonDecode(jsMessage.message) as Map<String, dynamic>;
      final action = data['action'] as String?;

      switch (action) {
        case 'close':
          _dismiss();
        case 'navigate':
          final url = data['url'] as String?;
          if (url != null) {
            _dismiss();
            widget.onAction?.call(url);
          }
        default:
          break;
      }
    } catch (_) {
      // Ignore malformed bridge messages.
    }
  }

  void _dismiss() {
    TolinkuMessagePresenter.markDismissed(widget.message.id);
    Navigator.of(context).pop();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Stack(
          children: [
            // WebView fills the entire dialog.
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: WebViewWidget(controller: _controller),
              ),
            ),
            // Native close button in the top-right corner.
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: GestureDetector(
                onTap: _dismiss,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(0, 0, 0, 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
