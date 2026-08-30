import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'install_referrer.dart';

/// Reads the Play Install Referrer through this package's own Android plugin.
///
/// Kept apart from [parseInstallReferrer] so the parsing stays free of any
/// platform channel and can be tested without a Flutter binding.
const MethodChannel _channel = MethodChannel('com.tolinku/install_referrer');

/// The raw Play referrer string for this install, or `null`.
///
/// Android only. There is no equivalent on iOS, which is why signal matching
/// exists. Never throws: an organic install, a device without Play Services,
/// and a missing plugin are all ordinary outcomes that fall back to signals,
/// and an exception here would surface on a first launch.
Future<String?> readInstallReferrer() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    return await _channel.invokeMethod<String>('getInstallReferrer');
  } catch (_) {
    return null;
  }
}

/// [ReferrerProvider] backed by the bundled Android plugin.
Future<String?> nativeReferrerProvider() => readInstallReferrer();
