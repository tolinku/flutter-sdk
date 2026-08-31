import 'package:flutter/material.dart';
import 'package:tolinku/tolinku.dart';

/// Minimal integration, and the build target CI uses to compile the native side.
///
/// The package ships Kotlin on Android to read the Play Install Referrer and
/// Swift on iOS to report the timezone. Neither is exercised by `flutter test`,
/// which runs Dart on the host, so an app that actually builds for both is the
/// only way a mistake in either shows up before a user hits it.
void main() {
  Tolinku.configure(apiKey: 'tolk_pub_your_key');
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomePage());
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _status = 'Not claimed yet';

  @override
  void initState() {
    super.initState();
    _claim();
  }

  /// Call once on the first launch after install.
  ///
  /// Tries the Play Install Referrer, then falls back to device signals, which
  /// are the only mechanism on iOS. Both are collected by the SDK.
  Future<void> _claim() async {
    try {
      final link = await Tolinku.instance.deferred.claimDeferredLink(
        appspaceId: 'YOUR_APPSPACE_ID',
      );
      if (!mounted) return;
      setState(() {
        _status = link == null
            ? 'Nothing waiting for this device'
            : 'Claimed ${link.deepLinkPath}';
      });
    } on TolinkuException catch (e) {
      // A 403 here means the Appspace ID is wrong, which is worth seeing rather
      // than swallowing. A first launch should not fail on it either.
      if (!mounted) return;
      setState(() => _status = 'Claim failed: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tolinku')),
      body: Center(child: Text(_status)),
    );
  }
}
