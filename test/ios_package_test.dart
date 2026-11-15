import 'dart:io';
import 'package:test/test.dart';

/// The iOS side ships two manifests describing one plugin.
///
/// `tolinku.podspec` serves apps on CocoaPods and `tolinku/Package.swift` serves
/// apps on Swift Package Manager, which Flutter 3.44 made the default. Both read
/// the same Swift sources, and the sources had to move under `tolinku/Sources`
/// for the Swift package to see them at all: a package cannot reference files
/// outside its own directory.
///
/// That move is the risk worth guarding. A podspec whose `source_files` no
/// longer matches anything does not fail: CocoaPods builds an empty pod, the app
/// compiles, and the plugin is simply missing at runtime, where it looks like a
/// broken method channel rather than a packaging mistake. Nothing in CI on Linux
/// compiles Swift, so these assertions are what stands between a moved file and
/// a silently empty pod.
void main() {
  final podspec = File('ios/tolinku.podspec').readAsStringSync();

  test('the Swift package sits where pub.dev and the Flutter tool look for it', () {
    // Both name this exact path. pub.dev scores the package down when it is
    // missing, which is how this migration was first noticed.
    expect(File('ios/tolinku/Package.swift').existsSync(), isTrue);
  });

  test('every Swift source lives inside the package', () {
    final sources = Directory('ios')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.swift'))
        // Package.swift is the manifest, not a source file.
        .where((f) => !f.path.endsWith('/Package.swift'))
        .map((f) => f.path)
        .toList();

    expect(sources, isNotEmpty, reason: 'no Swift sources found under ios/');
    for (final path in sources) {
      expect(
        path.startsWith('ios/tolinku/Sources/tolinku/'),
        isTrue,
        reason: '$path is outside the Swift package, so SPM builds will not see it',
      );
    }
  });

  test('the podspec still points at the sources that exist', () {
    final match =
        RegExp(r"s\.source_files\s*=\s*'([^']+)'").firstMatch(podspec);
    expect(match, isNotNull, reason: 'no s.source_files in the podspec');

    final glob = match!.group(1)!;
    // 'tolinku/Sources/tolinku/**/*.swift' is relative to the podspec, which
    // lives in ios/.
    final pattern = RegExp(
      '^${RegExp.escape('ios/$glob')
          .replaceAll(r'\*\*/\*', '.*')
          .replaceAll(r'\*\*', '.*')
          .replaceAll(r'\*', '[^/]*')}\$',
    );

    final matched = Directory('ios')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => pattern.hasMatch(f.path))
        .toList();

    expect(
      matched,
      isNotEmpty,
      reason: 'source_files glob "$glob" matches no file, which builds an '
          'empty pod rather than failing',
    );
  });

  test('the two manifests agree on the minimum iOS version', () {
    // They are read by different build systems and neither can see the other,
    // so a disagreement surfaces as a plugin that builds for one set of apps
    // and not the other.
    final fromPodspec =
        RegExp(r"s\.platform\s*=\s*:ios,\s*'([^']+)'").firstMatch(podspec);
    expect(fromPodspec, isNotNull, reason: 'no s.platform in the podspec');

    final packageSwift = File('ios/tolinku/Package.swift').readAsStringSync();
    final fromPackage =
        RegExp(r'\.iOS\("([^"]+)"\)').firstMatch(packageSwift);
    expect(fromPackage, isNotNull, reason: 'no .iOS platform in Package.swift');

    expect(fromPackage!.group(1), fromPodspec!.group(1));
  });

  test('the package, library and target carry the plugin name', () {
    // The Flutter tool resolves the package by the plugin name, so these are
    // not free-form. A mismatch is not a build error, it is a plugin the tool
    // cannot find.
    final packageSwift = File('ios/tolinku/Package.swift').readAsStringSync();

    expect(packageSwift, contains('name: "tolinku"'));
    expect(packageSwift, contains('.library(name: "tolinku", targets: ["tolinku"])'));
    expect(packageSwift, contains('.target('));
  });

  test('declaring FlutterFramework keeps the Flutter floor that provides it', () {
    // The defect this test exists for, caught in review rather than by a user.
    //
    // `../FlutterFramework` is a package the Flutter tool generates at build
    // time, and it only began generating it in 3.41: the same file at 3.38
    // creates the plugin package and stops. A manifest pointing at a directory
    // the tool never writes does not degrade to CocoaPods, it fails resolution,
    // so advertising an older Flutter while declaring this dependency hands
    // those apps a broken build. Flutter's own plugins raise the two together.
    final packageSwift = File('ios/tolinku/Package.swift').readAsStringSync();
    if (!packageSwift.contains('FlutterFramework')) return;

    final constraint = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.trimLeft().startsWith('flutter:'), orElse: () => '');
    final version = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(constraint);
    expect(version, isNotNull,
        reason: 'no Flutter version constraint in pubspec.yaml');

    final major = int.parse(version!.group(1)!);
    final minor = int.parse(version.group(2)!);
    expect(
      major > 3 || (major == 3 && minor >= 41),
      isTrue,
      reason: 'Package.swift depends on FlutterFramework, which the Flutter '
          'tool only generates from 3.41, but pubspec.yaml allows $constraint',
    );
  });

  test('the minimum iOS version is not below the one Flutter itself requires', () {
    // flutter_tools returns 13.0 from deploymentTarget() for iOS, so anything
    // lower is a promise the framework will not keep. It is also rejected by
    // Swift Package Manager, which refuses a dependency whose deployment target
    // sits above the depending target's, and the generated FlutterFramework
    // declares 13.0.
    final packageSwift = File('ios/tolinku/Package.swift').readAsStringSync();
    final match = RegExp(r'\.iOS\("(\d+)\.(\d+)"\)').firstMatch(packageSwift);
    expect(match, isNotNull);

    final major = int.parse(match!.group(1)!);
    expect(major >= 13, isTrue, reason: 'iOS ${match.group(0)} is below Flutter\'s floor of 13.0');
  });

  test('the privacy manifest reaches both build systems', () {
    // One file, declared twice, because a resource is wired differently for
    // each dependency manager. Shipping it to only one set of apps is worse
    // than not shipping it: whether the embedding app can describe us then
    // depends on how it happened to install us.
    final manifest = File('ios/tolinku/Sources/tolinku/PrivacyInfo.xcprivacy');
    expect(manifest.existsSync(), isTrue);

    final packageSwift = File('ios/tolinku/Package.swift').readAsStringSync();
    expect(packageSwift, contains('.process("PrivacyInfo.xcprivacy")'));
    expect(podspec, contains('PrivacyInfo.xcprivacy'));
    expect(podspec, contains('s.resource_bundles'));

    // A manifest that does not parse is worse than none, since it ships inside
    // every app that embeds this one and is read by Apple's tooling.
    final xml = manifest.readAsStringSync();
    expect(xml, contains('<plist version="1.0">'));
    expect(xml, contains('NSPrivacyTracking'));
    expect('<'.allMatches(xml).length, greaterThan(4));
  });

  test('the privacy manifest declares what the Dart side sends', () {
    // The declaration describes the package, not this directory. The Dart side
    // has no bundle of its own, so if these entries are dropped there is
    // nowhere else they can appear, and the developer embedding us has to read
    // our source to fill in their own privacy label.
    final xml =
        File('ios/tolinku/Sources/tolinku/PrivacyInfo.xcprivacy').readAsStringSync();

    const expected = {
      // deferred.claimBySignals, from both Dart and TolinkuPlugin
      'NSPrivacyCollectedDataTypeOtherDataTypes': 'deferred signal matching',
      // trackLinkOpen, track, and the ecommerce interaction events
      'NSPrivacyCollectedDataTypeProductInteraction': 'analytics events',
      // ecommerce.search
      'NSPrivacyCollectedDataTypeSearchHistory': 'ecommerce.search',
      // ecommerce.purchase, refund, beginCheckout
      'NSPrivacyCollectedDataTypePurchaseHistory': 'ecommerce revenue events',
      // setUserId and the referral calls
      'NSPrivacyCollectedDataTypeUserID': 'setUserId and referrals',
      // the optional userName on referrals.create and referrals.complete
      'NSPrivacyCollectedDataTypeName': 'referral display names',
    };

    for (final entry in expected.entries) {
      expect(
        xml,
        contains(entry.key),
        reason: '${entry.key} is not declared, but ${entry.value} still sends it',
      );
    }
  });

  test('every declared data type carries its purposes and both flags', () {
    // Xcode's privacy report skips an incomplete entry in silence, so a
    // half-filled declaration reads as no declaration while looking present.
    final xml =
        File('ios/tolinku/Sources/tolinku/PrivacyInfo.xcprivacy').readAsStringSync();

    final typeCount =
        'NSPrivacyCollectedDataType<'.allMatches(xml).length;
    expect(typeCount, greaterThan(0), reason: 'no collected data types declared');

    expect('NSPrivacyCollectedDataTypeLinked'.allMatches(xml).length, typeCount,
        reason: 'a data type does not say whether it is linked to identity');
    expect('NSPrivacyCollectedDataTypeTracking'.allMatches(xml).length, typeCount,
        reason: 'a data type does not say whether it is used for tracking');
    expect('NSPrivacyCollectedDataTypePurposes'.allMatches(xml).length, typeCount,
        reason: 'a data type declares no purpose');

    // NSPrivacyTracking is false, so no individual type may claim otherwise.
    expect(
      RegExp(r'NSPrivacyCollectedDataTypeTracking</key>\s*<true/>').hasMatch(xml),
      isFalse,
      reason: 'a data type is marked as used for tracking while '
          'NSPrivacyTracking is false',
    );
  });

  test('an empty accessed API array means nothing here calls one', () {
    // UserDefaults reaches this package through shared_preferences, which ships
    // its own manifest declaring it with reason 1C8F.1. Repeating it here would
    // claim a call this package does not make. But if anything under ios/ ever
    // reads UserDefaults directly, the array has to stop being empty, and this
    // is what notices.
    final xml =
        File('ios/tolinku/Sources/tolinku/PrivacyInfo.xcprivacy').readAsStringSync();
    final declaresNone =
        RegExp(r'NSPrivacyAccessedAPITypes</key>\s*<array/>').hasMatch(xml);
    if (!declaresNone) return;

    final swift = Directory('ios')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.swift') && !f.path.endsWith('/Package.swift'))
        .map((f) => f.readAsStringSync())
        .join();

    for (final needle in const [
      'UserDefaults',
      'systemUptime',
      'mach_absolute_time',
      'attributesOfItem',
      'volumeAvailableCapacity',
      'activeInputModes',
    ]) {
      expect(
        swift.contains(needle),
        isFalse,
        reason: 'ios/ calls $needle, which is a required reason API, but '
            'NSPrivacyAccessedAPITypes is empty. Declare it with a reason code '
            'or App Store Connect answers the next upload with ITMS-91053.',
      );
    }
  });

  test('the package declares the Flutter framework it builds against', () {
    // Without this the target compiles against no Flutter headers, and
    // `import Flutter` in the plugin fails on the app developer's machine
    // rather than ours.
    final packageSwift = File('ios/tolinku/Package.swift').readAsStringSync();

    expect(packageSwift, contains('swift-tools-version: 5.9'));
    expect(
      packageSwift,
      contains('.package(name: "FlutterFramework", path: "../FlutterFramework")'),
    );
    expect(
      packageSwift,
      contains('.product(name: "FlutterFramework", package: "FlutterFramework")'),
    );
  });
}
