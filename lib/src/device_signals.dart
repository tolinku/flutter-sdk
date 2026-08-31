import 'dart:ui' as ui;

/// Device signals used to match an iOS install back to the click that caused it.
///
/// Signal matching compares what the browser recorded at click time against what
/// the app reports at first launch. Only fields present on *both* sides are
/// compared, so an absent field costs nothing, while a field in the wrong format
/// is counted as a comparison that failed and actively lowers the match rate.
/// That asymmetry is why [collectDeviceSignals] returns less than it could.
class DeviceSignals {
  /// Creates a set of device signals.
  const DeviceSignals({
    this.timezone,
    this.language,
    this.screenWidth,
    this.screenHeight,
    this.devicePixelRatio,
    this.osVersion,
  });

  /// IANA timezone identifier, for example `Asia/Seoul`.
  final String? timezone;

  /// BCP-47 language tag, for example `ko-KR`.
  final String? language;

  /// Screen width in logical pixels.
  final int? screenWidth;

  /// Screen height in logical pixels.
  final int? screenHeight;

  /// Ratio of physical pixels to logical pixels.
  final double? devicePixelRatio;

  /// Operating system version, compared on its major component only.
  final String? osVersion;

  /// This set with any non-null field of [overrides] taking precedence.
  ///
  /// Caller-supplied values always win. An app that knows its timezone from a
  /// platform channel should not have that discarded in favour of a guess.
  DeviceSignals merge(DeviceSignals overrides) => DeviceSignals(
        timezone: overrides.timezone ?? timezone,
        language: overrides.language ?? language,
        screenWidth: overrides.screenWidth ?? screenWidth,
        screenHeight: overrides.screenHeight ?? screenHeight,
        devicePixelRatio: overrides.devicePixelRatio ?? devicePixelRatio,
        osVersion: overrides.osVersion ?? osVersion,
      );

  /// The signals as request fields, omitting anything absent.
  Map<String, dynamic> toRequestBody() => {
        if (timezone != null) 'timezone': timezone,
        if (language != null) 'language': language,
        if (screenWidth != null) 'screen_width': screenWidth,
        if (screenHeight != null) 'screen_height': screenHeight,
        if (devicePixelRatio != null) 'device_pixel_ratio': devicePixelRatio,
        if (osVersion != null) 'os_version': osVersion,
      };

  /// Whether anything at all is set. A claim with nothing to compare cannot
  /// match, so this is worth checking before spending a request on it.
  bool get isEmpty => toRequestBody().isEmpty;
}

/// Reads the device signals Dart alone can report in the form the click side
/// records them.
///
/// Returns language, screen size and pixel ratio. It does **not** return a
/// timezone or an OS version: Dart cannot produce either in the format the
/// matcher compares against, so they are read natively instead by
/// `collectAllDeviceSignals`, which is what `claimDeferredLink` uses. Prefer
/// that wherever you can await. The formats are:
///
///  * Timezone. Matching uses IANA identifiers (`Asia/Seoul`), which is what
///    `Intl.DateTimeFormat().resolvedOptions().timeZone` gives the browser at
///    click time. Dart offers only `DateTime.now().timeZoneName`, an
///    abbreviation like `KST`, which can never equal the stored value. Sending
///    it would turn a signal that is skipped into one that always fails.
///  * OS version. `Platform.operatingSystemVersion` is prose, such as
///    `Android 13 (API 33)` or `Version 17.1 (Build 21B74)`. Matching compares
///    leading digits, which neither string has.
///
/// Both are supplied by this package's own Android and iOS plugins, and either
/// can also be passed explicitly, in which case the given value is used as-is.
/// See [DeviceSignals.merge].
DeviceSignals collectDeviceSignals() {
  try {
    final dispatcher = ui.PlatformDispatcher.instance;

    // `display` reports the screen, matching `window.screen` in the browser and
    // `Dimensions.get('screen')` in React Native. A view's own size is the app
    // window, which is smaller than the screen whenever system bars are in play.
    final view = dispatcher.implicitView ??
        (dispatcher.views.isNotEmpty ? dispatcher.views.first : null);
    if (view == null) {
      return DeviceSignals(language: _language(dispatcher));
    }

    final display = view.display;
    final ratio = display.devicePixelRatio;
    if (!ratio.isFinite || ratio <= 0) {
      return DeviceSignals(language: _language(dispatcher));
    }

    // Physical pixels to logical pixels, the unit every other Tolinku SDK and
    // the browser report in.
    final size = display.size;
    return DeviceSignals(
      language: _language(dispatcher),
      screenWidth: (size.width / ratio).round(),
      screenHeight: (size.height / ratio).round(),
      devicePixelRatio: ratio,
    );
  } catch (_) {
    // Reading platform state must never be the reason a claim is not attempted.
    return const DeviceSignals();
  }
}

String? _language(ui.PlatformDispatcher dispatcher) {
  final locale = dispatcher.locale;
  final tag = locale.toLanguageTag();
  return tag.isEmpty || tag == 'und' ? null : tag;
}
