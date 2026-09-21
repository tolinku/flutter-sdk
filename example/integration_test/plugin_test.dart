import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tolinku/tolinku.dart';

/// The iOS plugin answering on a running device, rather than merely being
/// linked into one.
///
/// Everything else that checks the native side checks the build: the app
/// compiles, and the plugin's code is present in the binary. Neither runs a
/// single line of it. That gap matters more here than it would elsewhere,
/// because [readPlatformSignals] is written never to throw: a plugin that is
/// missing, unregistered, or built into a package the app cannot reach returns
/// exactly the same empty result as a device with nothing to report. A method
/// channel with nobody on the other end is silence, not an error.
///
/// So this is the only check that can tell a working plugin from an absent one.
/// It runs under both dependency managers, since Swift Package Manager and
/// CocoaPods register plugins by different routes.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the platform answers with the signals only it can report', (tester) async {
    final signals = await readPlatformSignals();

    final timezone = signals.timezone;
    final osVersion = signals.osVersion;

    expect(
      timezone,
      isNotNull,
      reason: 'nothing came back, so the plugin did not answer. On a Swift '
          'Package Manager build this usually means the package built but was '
          'never registered.',
    );

    // An IANA identifier, which is the form deferred matching compares against
    // and the whole reason this is read natively. Dart offers an abbreviation
    // here, and an abbreviation can never equal the stored value.
    expect(timezone, isNotEmpty);
    expect(
      timezone,
      contains('/'),
      reason: 'expected an IANA identifier such as America/New_York, got "$timezone"',
    );

    // Leading digits, not the prose Platform.operatingSystemVersion returns.
    expect(osVersion, isNotNull);
    expect(
      RegExp(r'^\d+').hasMatch(osVersion ?? ''),
      isTrue,
      reason: 'expected a version starting with digits, got "$osVersion"',
    );
  });
}
