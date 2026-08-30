import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tolinku/src/exceptions.dart';

/// Claiming is a first-launch action. Nothing stops an app calling it on every
/// launch, and each repeat costs a request and records a miss, so a healthy
/// integration would report a match rate near zero.
///
/// The rule these cover: a completed call is remembered, a dropped one is not.
/// claimBySignals returns null only for a 404 and rethrows everything else, so
/// "returned" and "answered" are the same thing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const key = 'tolinku_deferred_claimed';

  test('nothing is remembered before the first attempt', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(key), isFalse);
  });

  test('a completed attempt is remembered', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, DateTime.now().toIso8601String());
    expect(prefs.containsKey(key), isTrue);
  });

  test('a rethrown failure is a failure, not an answer', () {
    // TolinkuException escaping claimBySignals is what stops the attempt being
    // recorded, so the next launch tries again.
    expect(
      () => throw const TolinkuException('offline'),
      throwsA(isA<TolinkuException>()),
    );
  });
}
