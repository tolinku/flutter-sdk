import 'package:flutter_test/flutter_test.dart';
import 'package:tolinku/tolinku.dart';

/// `destroy` is the name every Tolinku SDK uses to tear down. This package
/// shipped it as `dispose`, which is also the ordinary Dart name for it, so
/// both stay. `destroy` exists so an app sharing code across platforms calls
/// one name everywhere.
void main() {
  const config = (apiKey: 'tolk_pub_test', baseUrl: 'https://api.example.com');

  tearDown(() async {
    if (Tolinku.isConfigured) await Tolinku.instance.destroy();
  });

  test('destroy tears the SDK down the same way dispose does', () async {
    Tolinku.configure(apiKey: config.apiKey, baseUrl: config.baseUrl);
    expect(Tolinku.isConfigured, isTrue);

    await Tolinku.instance.destroy();
    expect(Tolinku.isConfigured, isFalse);
  });

  test('dispose still works and is not broken by the alias', () async {
    Tolinku.configure(apiKey: config.apiKey, baseUrl: config.baseUrl);
    await Tolinku.instance.dispose();
    expect(Tolinku.isConfigured, isFalse);
  });

  test('the SDK can be configured again after either name', () async {
    Tolinku.configure(apiKey: config.apiKey, baseUrl: config.baseUrl);
    await Tolinku.instance.destroy();
    Tolinku.configure(apiKey: config.apiKey, baseUrl: config.baseUrl);
    expect(Tolinku.isConfigured, isTrue);

    await Tolinku.instance.dispose();
    Tolinku.configure(apiKey: config.apiKey, baseUrl: config.baseUrl);
    expect(Tolinku.isConfigured, isTrue);
  });
}
