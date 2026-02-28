/// Tolinku SDK for deep linking, analytics, referrals, and in-app messages.
///
/// Usage:
/// ```dart
/// import 'package:tolinku/tolinku.dart';
///
/// Tolinku.configure(apiKey: 'tolk_pub_...');
/// await Tolinku.instance.track('custom.signup');
/// ```
///
/// For lifecycle handling, call [Tolinku.flush] when the app goes to background.
/// Implement [WidgetsBindingObserver] and call `Tolinku.instance.flush()` in
/// [didChangeAppLifecycleState] when the state is [AppLifecycleState.paused].
library tolinku;

export 'src/tolinku_client.dart';
export 'src/analytics.dart' show Analytics;
export 'src/referrals.dart';
export 'src/deferred.dart';
export 'src/messages.dart';
export 'src/message_presenter.dart';
export 'src/models.dart';
export 'src/exceptions.dart';
// http_client.dart is intentionally not exported; it is internal to the SDK.
// The following are re-exported from http_client.dart for public use:
export 'src/http_client.dart'
    show tolinkuSdkVersion, setTolinkuDebugMode, isTolinkuDebugMode;
