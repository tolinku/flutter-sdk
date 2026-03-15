import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tolinku/tolinku.dart';
import 'package:tolinku/src/http_client.dart';

/// A mock HTTP client that captures requests instead of making real ones.
class MockHttpClient implements TolinkuHttpClient {
  final List<Map<String, dynamic>> capturedBatches = [];
  int postBatchCallCount = 0;
  bool shouldFail = false;

  @override
  Future<Map<String, dynamic>> postBatch(
    String path, {
    required List<Map<String, dynamic>> events,
    bool authenticated = true,
  }) async {
    postBatchCallCount++;
    if (shouldFail) {
      throw const TolinkuException('Network error');
    }
    capturedBatches.add({
      'path': path,
      'events': events.map((e) => Map<String, dynamic>.from(e)).toList(),
    });
    return {'ok': true};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient mockClient;
  late Ecommerce ecommerce;
  String? userId;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockClient = MockHttpClient();
    userId = null;
    ecommerce = Ecommerce(mockClient, () => userId);
  });

  tearDown(() async {
    await ecommerce.dispose();
  });

  group('Queuing', () {
    test('queues events without immediate flush', () async {
      await ecommerce.viewItem(items: [TolinkuItem(itemId: 'sku_1')]);
      expect(mockClient.postBatchCallCount, equals(0));
    });

    test('flushes at batch size (10)', () async {
      for (int i = 0; i < 10; i++) {
        await ecommerce.viewItem(items: [TolinkuItem(itemId: 'sku_$i')]);
      }
      expect(mockClient.postBatchCallCount, equals(1));
      expect(mockClient.capturedBatches[0]['events'].length, equals(10));
    });

    test('sends to correct endpoint', () async {
      await ecommerce.viewItem(items: [TolinkuItem(itemId: 'sku_1')]);
      await ecommerce.flush();
      expect(mockClient.capturedBatches[0]['path'], equals('/v1/api/analytics/ecommerce/batch'));
    });

    test('flush is no-op when empty', () async {
      await ecommerce.flush();
      expect(mockClient.postBatchCallCount, equals(0));
    });
  });

  group('Purchase', () {
    test('includes all fields', () async {
      await ecommerce.purchase(
        transactionId: 'order_123',
        revenue: 49.99,
        currency: 'USD',
        couponCode: 'SAVE10',
        discount: 5.0,
        shipping: 4.99,
        tax: 3.75,
        items: [TolinkuItem(itemId: 'sku_1', itemName: 'T-Shirt', price: 24.99, quantity: 2)],
      );
      await ecommerce.flush();

      final event = mockClient.capturedBatches[0]['events'][0] as Map<String, dynamic>;
      expect(event['event_type'], equals('purchase'));
      expect(event['transaction_id'], equals('order_123'));
      expect(event['revenue'], equals(49.99));
      expect(event['currency'], equals('USD'));
      expect(event['coupon_code'], equals('SAVE10'));
      expect(event['discount'], equals(5.0));
      expect(event['shipping'], equals(4.99));
      expect(event['tax'], equals(3.75));
      expect((event['items'] as List).length, equals(1));
    });
  });

  group('User ID', () {
    test('injects user_id when set', () async {
      userId = 'user_456';
      await ecommerce.viewItem(items: [TolinkuItem(itemId: 'sku_1')]);
      await ecommerce.flush();

      final event = mockClient.capturedBatches[0]['events'][0] as Map<String, dynamic>;
      expect(event['user_id'], equals('user_456'));
    });

    test('does not inject user_id when null', () async {
      userId = null;
      await ecommerce.viewItem(items: [TolinkuItem(itemId: 'sku_1')]);
      await ecommerce.flush();

      final event = mockClient.capturedBatches[0]['events'][0] as Map<String, dynamic>;
      expect(event.containsKey('user_id'), isFalse);
    });
  });

  group('Cart ID lifecycle', () {
    test('auto-generates cart_id on addToCart', () async {
      await ecommerce.addToCart(items: [TolinkuItem(itemId: 'sku_1')]);
      await ecommerce.flush();

      final event = mockClient.capturedBatches[0]['events'][0] as Map<String, dynamic>;
      expect(event['cart_id'], isNotNull);
      expect(event['cart_id'], isA<String>());
      expect((event['cart_id'] as String).isNotEmpty, isTrue);
    });

    test('reuses cart_id across cart events', () async {
      await ecommerce.addToCart(items: [TolinkuItem(itemId: 'sku_1')]);
      await ecommerce.viewCart();
      await ecommerce.beginCheckout();
      await ecommerce.flush();

      final events = mockClient.capturedBatches[0]['events'] as List;
      final cartIds = events
          .map((e) => (e as Map<String, dynamic>)['cart_id'])
          .where((id) => id != null)
          .toSet();
      expect(cartIds.length, equals(1));
    });

    test('clears cart_id after purchase', () async {
      await ecommerce.addToCart(items: [TolinkuItem(itemId: 'sku_1')]);
      await ecommerce.purchase(transactionId: 'order_1', revenue: 10, currency: 'USD');
      await ecommerce.addToCart(items: [TolinkuItem(itemId: 'sku_2')]);
      await ecommerce.flush();

      final events = mockClient.capturedBatches[0]['events'] as List;
      final firstCartId = (events[0] as Map<String, dynamic>)['cart_id'];
      final lastCartId = (events[2] as Map<String, dynamic>)['cart_id'];
      expect(firstCartId, isNot(equals(lastCartId)));
    });

    test('persists cart_id to SharedPreferences', () async {
      await ecommerce.addToCart(items: [TolinkuItem(itemId: 'sku_1')]);

      final prefs = await SharedPreferences.getInstance();
      final storedCartId = prefs.getString('tolinku_ecom_cart_id');
      expect(storedCartId, isNotNull);
    });

    test('clears SharedPreferences after purchase', () async {
      await ecommerce.addToCart(items: [TolinkuItem(itemId: 'sku_1')]);
      await ecommerce.purchase(transactionId: 't', revenue: 1, currency: 'USD');

      final prefs = await SharedPreferences.getInstance();
      final storedCartId = prefs.getString('tolinku_ecom_cart_id');
      expect(storedCartId, isNull);
    });
  });

  group('All 13 event types', () {
    test('tracks all event types', () async {
      await ecommerce.viewItem(items: [TolinkuItem(itemId: 'a')]);
      await ecommerce.addToCart(items: [TolinkuItem(itemId: 'a')]);
      await ecommerce.removeFromCart(items: [TolinkuItem(itemId: 'a')]);
      await ecommerce.addToWishlist(items: [TolinkuItem(itemId: 'a')]);
      await ecommerce.viewCart();
      await ecommerce.addPaymentInfo();
      await ecommerce.beginCheckout();
      await ecommerce.purchase(transactionId: 't', revenue: 1, currency: 'USD');
      await ecommerce.refund(transactionId: 't', revenue: 1);
      await ecommerce.search(searchTerm: 'shoes');
      // Flushed at 10
      await ecommerce.share(itemId: 'a');
      await ecommerce.rate(itemId: 'a', rating: 5);
      await ecommerce.spendCredits(revenue: 10, currency: 'USD');
      await ecommerce.flush();

      final allTypes = <String>[];
      for (final batch in mockClient.capturedBatches) {
        for (final event in batch['events'] as List) {
          allTypes.add((event as Map<String, dynamic>)['event_type'] as String);
        }
      }

      expect(allTypes, contains('view_item'));
      expect(allTypes, contains('add_to_cart'));
      expect(allTypes, contains('remove_from_cart'));
      expect(allTypes, contains('add_to_wishlist'));
      expect(allTypes, contains('view_cart'));
      expect(allTypes, contains('add_payment_info'));
      expect(allTypes, contains('begin_checkout'));
      expect(allTypes, contains('purchase'));
      expect(allTypes, contains('refund'));
      expect(allTypes, contains('search'));
      expect(allTypes, contains('share'));
      expect(allTypes, contains('rate'));
      expect(allTypes, contains('spend_credits'));
    });
  });

  group('Error recovery', () {
    test('re-queues events on flush failure', () async {
      mockClient.shouldFail = true;

      await ecommerce.viewItem(items: [TolinkuItem(itemId: 'sku_1')]);
      await ecommerce.viewItem(items: [TolinkuItem(itemId: 'sku_2')]);

      try {
        await ecommerce.flush();
      } catch (_) {}

      // Events re-queued, retry should work
      mockClient.shouldFail = false;
      await ecommerce.flush();

      expect(mockClient.capturedBatches.length, equals(1));
      expect(mockClient.capturedBatches[0]['events'].length, equals(2));
    });
  });

  group('Search and Rate', () {
    test('search sends search_term in properties', () async {
      await ecommerce.search(searchTerm: 'blue shoes');
      await ecommerce.flush();

      final event = mockClient.capturedBatches[0]['events'][0] as Map<String, dynamic>;
      expect(event['event_type'], equals('search'));
      expect((event['properties'] as Map)['search_term'], equals('blue shoes'));
    });

    test('rate sends rating as string in properties', () async {
      await ecommerce.rate(itemId: 'sku_1', rating: 4.5, maxRating: 5);
      await ecommerce.flush();

      final event = mockClient.capturedBatches[0]['events'][0] as Map<String, dynamic>;
      expect((event['properties'] as Map)['rating'], equals('4.5'));
      expect((event['properties'] as Map)['max_rating'], equals('5.0'));
    });
  });
}
