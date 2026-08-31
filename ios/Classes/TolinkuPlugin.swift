import Flutter
import UIKit

/// Reports the device signals Flutter cannot express in the form Tolinku's
/// matcher compares against.
///
/// Deferred linking on iOS has no equivalent of the Play Install Referrer, so an
/// install is matched back to its click by comparing device signals recorded in
/// the browser at click time against those reported by the app at first launch.
/// Only fields present on both sides are compared.
///
/// Dart supplies language, screen size and pixel ratio correctly on its own. It
/// cannot supply these two:
///
///  * Timezone. Matching uses IANA identifiers, which is what
///    `Intl.DateTimeFormat().resolvedOptions().timeZone` gives the browser.
///    `DateTime.now().timeZoneName` in Dart returns an abbreviation such as
///    `KST`, which can never equal the stored value.
///  * OS version. Matching compares leading digits.
///    `Platform.operatingSystemVersion` returns prose such as
///    `Version 17.1 (Build 21B74)`.
///
/// A signal that is absent is skipped and costs nothing, while one that is
/// present and disagrees counts as a failed comparison. Sending Dart's versions
/// would therefore have lowered the match rate rather than raised it, which is
/// why they are read here instead.
public class TolinkuPlugin: NSObject, FlutterPlugin {

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.tolinku/device_signals",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(TolinkuPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "getDeviceSignals" else {
      result(FlutterMethodNotImplemented)
      return
    }

    // Method channel calls are delivered on the main thread, which is where
    // UIDevice must be read.
    result([
      "timezone": TimeZone.current.identifier,
      "os_version": UIDevice.current.systemVersion,
    ])
  }
}
