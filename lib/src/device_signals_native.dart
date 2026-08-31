import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'device_signals.dart';

/// Reads the device signals that only the platform can report, through this
/// package's own plugin.
///
/// Kept apart from [collectDeviceSignals] so the part that needs no platform
/// channel stays testable without a Flutter binding.
const MethodChannel _channel = MethodChannel('com.tolinku/device_signals');

/// The timezone and OS version for this device, or an empty set.
///
/// These two are read natively because Dart cannot express either in the form
/// deferred link matching compares against: it offers `KST` where matching wants
/// `Asia/Seoul`, and `Version 17.1 (Build 21B74)` where matching wants `17.1`.
/// Everything else [collectDeviceSignals] reports is already correct.
///
/// Never throws. An older host app whose plugin registration predates this
/// channel, and the web, are ordinary outcomes: the signals are then simply
/// absent, which costs nothing because matching skips what it cannot compare.
Future<DeviceSignals> readPlatformSignals() async {
  if (kIsWeb) return const DeviceSignals();
  try {
    final values = await _channel.invokeMapMethod<String, dynamic>(
      'getDeviceSignals',
    );
    if (values == null) return const DeviceSignals();
    return DeviceSignals(
      timezone: _text(values['timezone']),
      osVersion: _text(values['os_version']),
    );
  } catch (_) {
    return const DeviceSignals();
  }
}

/// Every signal this package can gather, platform values included.
///
/// Prefer this over [collectDeviceSignals] where you can await: it is what
/// `claimDeferredLink` uses, and it is the fullest set the SDK can report.
Future<DeviceSignals> collectAllDeviceSignals() async =>
    collectDeviceSignals().merge(await readPlatformSignals());

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
