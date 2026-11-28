import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tolinku/src/http_client.dart';
import 'package:tolinku/src/message_presenter.dart';
import 'package:tolinku/src/messages.dart';

void main() {
  late List<Uri> requested;

  Map<String, dynamic> eventMessage(String id, String? triggerValue) => {
        'id': id,
        'name': id,
        'trigger': 'event',
        'trigger_value': triggerValue,
        'priority': 1,
      };

  Messages messages(List<Map<String, dynamic>> items) {
    return Messages(TolinkuHttpClient(
      baseUrl: 'https://myapp.tolinku.com',
      apiKey: 'tolk_pub_test',
      httpClient: MockClient((request) async {
        requested.add(request.url);
        return http.Response(
          jsonEncode({'messages': items}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    ));
  }

  setUp(() => requested = []);

  group('triggerValue', () {
    test('is sent as trigger_value', () async {
      await messages([]).fetch(trigger: 'event', triggerValue: 'purchase');
      final query = requested.single.queryParameters;
      expect(query['trigger'], 'event');
      expect(query['trigger_value'], 'purchase');
    });

    test('is not sent when not given', () async {
      await messages([]).fetch(trigger: 'event');
      expect(requested.single.queryParameters.containsKey('trigger_value'),
          isFalse);
    });

    test('filters what an older server returns, keeping messages that name none',
        () async {
      final result = await messages([
        eventMessage('purchase', 'purchase'),
        eventMessage('signup', 'signup'),
        eventMessage('any', null),
        eventMessage('empty', ''),
      ]).fetch(trigger: 'event', triggerValue: 'purchase');
      expect(result.map((m) => m.id), ['purchase', 'any', 'empty']);
    });

    test('filters nothing when not given', () async {
      final result = await messages([
        eventMessage('purchase', 'purchase'),
        eventMessage('signup', 'signup'),
      ]).fetch(trigger: 'event');
      expect(result.map((m) => m.id), ['purchase', 'signup']);
    });
  });

  group('close memory', () {
    final now = DateTime(2026, 11, 27, 12);

    test('no dismissDays does not remember the close', () {
      expect(TolinkuMessagePresenter.stillDismissed(now, null, now), isFalse);
      expect(
        TolinkuMessagePresenter.stillDismissed(
            now.subtract(const Duration(days: 400)), null, now),
        isFalse,
      );
    });

    test('zero dismissDays does not remember the close', () {
      expect(TolinkuMessagePresenter.stillDismissed(now, 0, now), isFalse);
    });

    test('dismissDays hides for that many days', () {
      expect(
        TolinkuMessagePresenter.stillDismissed(
            now.subtract(const Duration(days: 2)), 3, now),
        isTrue,
      );
      expect(
        TolinkuMessagePresenter.stillDismissed(
            now.subtract(const Duration(days: 3)), 3, now),
        isFalse,
      );
    });

    test('never closed is not dismissed', () {
      expect(TolinkuMessagePresenter.stillDismissed(null, 7, now), isFalse);
    });
  });
}
