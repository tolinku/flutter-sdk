import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tolinku/src/tolinku_client.dart';

/// The other four SDKs flush queued events when the app leaves the foreground:
/// the web SDK on `beforeunload`, React Native through `AppState`, iOS on
/// `willResignActive`, and Android through `ActivityLifecycleCallbacks`. This
/// package used to be the exception, and asked the app to implement
/// `WidgetsBindingObserver` and call `flush()` instead. An app that did not
/// lost whatever was still queued on every background, silently, having been
/// told that batching was handled for it.
///
/// These tests cover the two parts that can regress: which lifecycle states
/// count as leaving the foreground, and whether the observer is attached and
/// detached with the SDK's own lifetime.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shouldFlushForLifecycle', () {
    test('flushes once the app is off screen or going away', () {
      expect(shouldFlushForLifecycle(AppLifecycleState.hidden), isTrue);
      expect(shouldFlushForLifecycle(AppLifecycleState.paused), isTrue);
      expect(shouldFlushForLifecycle(AppLifecycleState.detached), isTrue);
    });

    test('does not flush while the app is still in front', () {
      expect(shouldFlushForLifecycle(AppLifecycleState.resumed), isFalse);
      // inactive is an interruption the app usually returns from straight
      // away, such as the notification shade or an incoming call. Flushing
      // there would send a part-full batch on every one of them.
      expect(shouldFlushForLifecycle(AppLifecycleState.inactive), isFalse);
    });

    test('covers every lifecycle state, so a new one cannot be missed', () {
      // Compared as a set of names rather than positionally: the declaration
      // order of AppLifecycleState is not part of its contract, and a test
      // that depends on it fails when the order changes rather than when the
      // behaviour does.
      //
      // If Flutter adds a state, this fails and someone has to decide which
      // side it belongs on, instead of it silently defaulting to "no flush"
      // and quietly dropping a batch.
      final flushes = {
        for (final s in AppLifecycleState.values)
          if (shouldFlushForLifecycle(s)) s.name,
      };
      expect(
        flushes,
        equals({'hidden', 'paused', 'detached'}),
        reason: 'AppLifecycleState.values is now ${AppLifecycleState.values}',
      );
    });
  });

  group('observer lifetime', () {
    tearDown(() async {
      if (Tolinku.isConfigured) await Tolinku.instance.dispose();
    });

    test('configure attaches the observer', () {
      Tolinku.configure(apiKey: 'tolk_pub_test');
      expect(Tolinku.instance.hasLifecycleFlusher, isTrue);
    });

    test('dispose detaches it, so a torn down SDK stops observing', () async {
      Tolinku.configure(apiKey: 'tolk_pub_test');
      final instance = Tolinku.instance;
      await instance.dispose();
      expect(instance.hasLifecycleFlusher, isFalse);
    });

    test('a background transition after configure does not throw', () async {
      Tolinku.configure(apiKey: 'tolk_pub_test');
      // Nothing has been tracked, so flush finds an empty queue and makes no
      // request. What this proves is that the observer is really registered
      // with the binding and survives being called.
      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(Tolinku.isConfigured, isTrue);
    });
  });

  group('a failing flush on background', () {
    // Both queues rethrow from flush(), which is right for a caller that
    // awaited it. Nothing awaits the flush started from the lifecycle
    // callback, so if that error were allowed out it would surface as an
    // unhandled asynchronous error: a reported crash, on backgrounding, for a
    // send the app never asked for. These two tests are the pair that matters,
    // because the first is the reason the second is not free.
    http.Client failing() => MockClient(
          (_) async => throw const SocketExceptionStub(),
        );

    tearDown(() async {
      if (Tolinku.isConfigured) await Tolinku.instance.dispose();
    });

    test('flush() still reports the failure to a caller who awaits it', () async {
      Tolinku.configure(apiKey: 'tolk_pub_test', httpClient: failing());
      await Tolinku.instance.track('custom.queued_event');
      await expectLater(Tolinku.instance.flush(), throwsA(isA<Object>()));
    });

    test('the background flush swallows it instead of crashing the app',
        () async {
      Tolinku.configure(apiKey: 'tolk_pub_test', httpClient: failing());
      await Tolinku.instance.track('custom.queued_event');

      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      // Long enough for the client's retries and backoff to finish and for the
      // error to be thrown. An unhandled asynchronous error reaches the test
      // binding and fails this test, so completing is the assertion.
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(Tolinku.isConfigured, isTrue);
    });
  });
}

/// Stands in for a socket failure without depending on dart:io in a test that
/// otherwise does not need it.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
  @override
  String toString() => 'SocketExceptionStub: connection refused';
}
