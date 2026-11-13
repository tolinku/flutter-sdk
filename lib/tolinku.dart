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
/// Queued analytics and ecommerce events are flushed automatically when the app
/// leaves the foreground, so there is no lifecycle observer to install. Earlier
/// versions of this package asked you to implement one; if you did, it still
/// works and costs nothing, because the queue is empty by the time your
/// observer runs. [Tolinku.flush] remains available for sending a batch sooner.
library;

export 'src/tolinku_client.dart';
export 'src/analytics.dart' show Analytics;
export 'src/ecommerce.dart' show Ecommerce, TolinkuItem;
export 'src/referrals.dart';
export 'src/deferred.dart';
export 'src/links.dart';
export 'src/messages.dart';
export 'src/message_presenter.dart';
export 'src/models.dart';
export 'src/exceptions.dart';
export 'src/validation.dart' show isSafeUrl;
export 'src/device_signals.dart' show DeviceSignals, collectDeviceSignals;
export 'src/device_signals_native.dart'
    show readPlatformSignals, collectAllDeviceSignals;
export 'src/install_referrer.dart' show parseInstallReferrer, ReferrerProvider;
// http_client.dart is intentionally not exported; it is internal to the SDK.
// The following are re-exported from http_client.dart for public use:
export 'src/http_client.dart'
    show tolinkuSdkVersion, setTolinkuDebugMode, isTolinkuDebugMode;
