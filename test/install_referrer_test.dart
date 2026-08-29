import 'package:test/test.dart';
import 'package:tolinku/src/install_referrer.dart';

/// The Play referrer is a shared string: a developer's own campaign parameters
/// sit beside ours, so the token has to be found among the pairs rather than
/// taken as the whole value.
void main() {
  group('parseInstallReferrer', () {
    test('reads the token when it is the only pair', () {
      expect(parseInstallReferrer('tolk_token=ABC123'), 'ABC123');
    });

    test("reads the token beside a developer's own parameters", () {
      expect(
        parseInstallReferrer('utm_source=newsletter&tolk_token=ABC123&utm_medium=email'),
        'ABC123',
      );
    });

    test('reads the token when it is last', () {
      expect(parseInstallReferrer('utm_source=x&tolk_token=ABC123'), 'ABC123');
    });

    test('tolerates a percent encoded referrer', () {
      expect(parseInstallReferrer('tolk_token%3DABC123'), 'ABC123');
    });

    test('returns null for an organic install', () {
      expect(parseInstallReferrer('utm_source=google-play&utm_medium=organic'), isNull);
    });

    test('returns null for nothing at all', () {
      expect(parseInstallReferrer(null), isNull);
      expect(parseInstallReferrer(''), isNull);
      expect(parseInstallReferrer('   '), isNull);
    });

    test('returns null rather than an empty token', () {
      expect(parseInstallReferrer('tolk_token='), isNull);
      expect(parseInstallReferrer('utm_source=x&tolk_token=&utm_medium=y'), isNull);
    });

    test('does not mistake a similarly named parameter for ours', () {
      expect(parseInstallReferrer('my_tolk_token=NOPE'), isNull);
      expect(parseInstallReferrer('tolk_token_other=NOPE'), isNull);
    });

    test('survives malformed percent encoding', () {
      expect(parseInstallReferrer('tolk_token=ABC%ZZ'), 'ABC%ZZ');
    });
  });
}
