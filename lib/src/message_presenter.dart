import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'http_client.dart' show tolinkuDebugLog;
import 'models.dart';
import 'validation.dart';

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
  /// If [TolinkuMessage.dismissDays] is null or 0 ("After closing, hide for"
  /// left empty), a close isn't remembered and this returns false, the same
  /// as the web SDK and the docs.
  static Future<bool> isMessageDismissed(TolinkuMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_dismissPrefix${message.id}';
    final dismissedAt = prefs.getString(key);

    return stillDismissed(
      dismissedAt == null ? null : DateTime.tryParse(dismissedAt),
      message.dismissDays,
      DateTime.now(),
    );
  }

  /// Whether a close at [dismissedAt] still hides a message whose "After
  /// closing, hide for" is [dismissDays], at [now]. With no number (or 0) the
  /// close isn't remembered; earlier versions hid the message forever.
  @visibleForTesting
  static bool stillDismissed(
    DateTime? dismissedAt,
    int? dismissDays,
    DateTime now,
  ) {
    if (dismissedAt == null) return false;
    if (dismissDays == null || dismissDays <= 0) return false;
    return now.difference(dismissedAt).inDays < dismissDays;
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

  /// Whether a `navigate` action from the message bridge should be followed.
  ///
  /// One line, lifted out of the bridge handler below so there is something to
  /// test. The dialog needs a WebView and a live BuildContext, so none of it
  /// runs under `flutter test`, and the rule it applies was therefore asserted
  /// nowhere: swapping `isNavigableUrl` back for [isSafeUrl] here kills every
  /// message that links into the host app, silently, and left the whole suite
  /// green. Now it does not.
  @visibleForTesting
  static bool shouldFollowMessageAction(String url) => isNavigableUrl(url);

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
          // The URL comes from page content, so it is checked before it reaches
          // the host app rather than left for the app to check. The check is a
          // denylist rather than an allowlist because the whole point of a
          // message on this platform is often a button into the app itself,
          // `myapp://order/4821`, and there is no way to enumerate every
          // customer's scheme.
          if (url != null &&
              TolinkuMessagePresenter.shouldFollowMessageAction(url)) {
            _dismiss();
            final handler = widget.onAction;
            if (handler != null) {
              handler(url);
            } else {
              // This package opens nothing itself: a message's button is most
              // often a link into the host app, and only the host knows how to
              // route one. Without a handler the button closes the message and
              // does nothing else, which looks from the outside exactly like a
              // message that works, so say so rather than let it pass.
              tolinkuDebugLog(
                'A message button was tapped but no onAction handler was '
                'given, so nothing opened. Pass onAction to Tolinku.messages.'
                'show and route the URL yourself: $url',
              );
            }
          } else if (url != null) {
            tolinkuDebugLog(
              'Blocked navigation to an unsafe URL scheme: $url. '
              'Message actions may not use javascript, vbscript, data, blob or '
              'file, and must name a scheme.',
            );
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
            // Native close button in the top-right corner: a white X on a
            // dark disc, so it shows on a message of any colour. The disc is
            // 36 wide; the area that answers a tap is 48, the minimum Android
            // and Apple recommend.
            Positioned(
              top: MediaQuery.of(context).padding.top + 2,
              right: 2,
              child: Semantics(
                button: true,
                label: 'Close',
                child: GestureDetector(
                  onTap: _dismiss,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color.fromRGBO(0, 0, 0, 0.45),
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
