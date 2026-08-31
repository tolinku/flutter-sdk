import 'dart:io';
import 'package:test/test.dart';
import 'package:tolinku/src/http_client.dart';

/// tolinkuSdkVersion is sent in the User-Agent on every request, so a drift
/// from the published version silently misreports which SDK is in the field.
/// It sat at 0.1.0 through two releases before this guard existed.
void main() {
  test('tolinkuSdkVersion matches pubspec', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final declared = pubspec
        .firstWhere((l) => l.startsWith('version:'))
        .split(':')[1]
        .trim();
    expect(tolinkuSdkVersion, declared);
  });

  test('the iOS podspec matches pubspec', () {
    // CocoaPods resolves the iOS side by this version. Drift here is the same
    // failure the test above exists for, one build system further out.
    final podspec = File('ios/tolinku.podspec').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final declared = pubspec
        .firstWhere((l) => l.startsWith('version:'))
        .split(':')[1]
        .trim();

    final match = RegExp(r"s\.version\s*=\s*'([^']+)'").firstMatch(podspec);
    expect(match, isNotNull, reason: 'no s.version in the podspec');
    expect(match!.group(1), declared);
  });
}
