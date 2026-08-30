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
}
