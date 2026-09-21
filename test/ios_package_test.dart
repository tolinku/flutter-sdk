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
