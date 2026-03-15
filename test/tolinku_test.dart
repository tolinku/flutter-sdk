import 'package:flutter_test/flutter_test.dart';
import 'package:tolinku/tolinku.dart';

void main() {
  group('CreateReferralResponse model', () {
    test('fromJson parses all fields', () {
      final json = {
        'referral_code': 'ABC123',
        'referral_url': 'https://example.com/ref/ABC123',
        'referral_id': 'doc_123',
      };

      final response = CreateReferralResponse.fromJson(json);

      expect(response.referralCode, equals('ABC123'));
      expect(response.referralUrl, equals('https://example.com/ref/ABC123'));
      expect(response.referralId, equals('doc_123'));
    });

    test('fromJson handles null referral_url', () {
      final json = {
        'referral_code': 'XYZ',
        'referral_url': null,
        'referral_id': 'doc_456',
      };

      final response = CreateReferralResponse.fromJson(json);

      expect(response.referralCode, equals('XYZ'));
      expect(response.referralUrl, isNull);
      expect(response.referralId, equals('doc_456'));
    });

    test('toJson round-trips correctly', () {
      final original = CreateReferralResponse(
        referralCode: 'ABC123',
        referralUrl: 'https://example.com/ref/ABC123',
        referralId: 'doc_123',
      );

      final json = original.toJson();
      final restored = CreateReferralResponse.fromJson(json);

      expect(restored.referralCode, equals(original.referralCode));
      expect(restored.referralUrl, equals(original.referralUrl));
      expect(restored.referralId, equals(original.referralId));
    });
  });

  group('ReferralDetails model', () {
    test('fromJson parses all fields', () {
      final json = {
        'referrer_id': 'user_1',
        'status': 'pending',
        'milestone': 'signed_up',
        'milestone_history': [],
        'reward_type': 'credit',
        'reward_value': '10',
        'reward_claimed': false,
        'created_at': '2024-01-01T00:00:00Z',
      };

      final details = ReferralDetails.fromJson(json);

      expect(details.referrerId, equals('user_1'));
      expect(details.status, equals('pending'));
      expect(details.milestone, equals('signed_up'));
      expect(details.milestoneHistory, isEmpty);
      expect(details.rewardType, equals('credit'));
      expect(details.rewardValue, equals('10'));
      expect(details.rewardClaimed, isFalse);
      expect(details.createdAt, equals(DateTime.utc(2024, 1, 1)));
    });

    test('toJson round-trips correctly', () {
      final original = ReferralDetails(
        referrerId: 'user_1',
        status: 'pending',
        milestone: 'signed_up',
        milestoneHistory: [],
        rewardType: 'credit',
        rewardValue: '10',
        rewardClaimed: false,
      );

      final json = original.toJson();
      final restored = ReferralDetails.fromJson(json);

      expect(restored.referrerId, equals(original.referrerId));
      expect(restored.status, equals(original.status));
      expect(restored.milestone, equals(original.milestone));
      expect(restored.rewardClaimed, equals(original.rewardClaimed));
    });
  });

  group('LeaderboardEntry model', () {
    test('fromJson parses correctly', () {
      final json = {
        'referrer_id': 'user_1',
        'referrer_name': 'Alice',
        'total': 15,
        'completed': 10,
        'pending': 5,
        'total_reward_value': '100.00',
      };

      final entry = LeaderboardEntry.fromJson(json);

      expect(entry.referrerId, equals('user_1'));
      expect(entry.referrerName, equals('Alice'));
      expect(entry.total, equals(15));
      expect(entry.completed, equals(10));
      expect(entry.pending, equals(5));
      expect(entry.totalRewardValue, equals('100.00'));
    });

    test('toJson round-trips correctly', () {
      final original = LeaderboardEntry(
        referrerId: 'user_1',
        referrerName: 'Alice',
        total: 15,
        completed: 10,
        pending: 5,
      );

      final json = original.toJson();
      final restored = LeaderboardEntry.fromJson(json);

      expect(restored.referrerId, equals(original.referrerId));
      expect(restored.referrerName, equals(original.referrerName));
      expect(restored.total, equals(original.total));
      expect(restored.completed, equals(original.completed));
      expect(restored.pending, equals(original.pending));
    });
  });

  group('DeferredLink model', () {
    test('fromJson parses correctly', () {
      final json = {
        'deep_link_path': '/product/123',
        'appspace_id': 'app_001',
        'referrer_id': 'user_42',
        'referral_code': 'ABC',
      };

      final link = DeferredLink.fromJson(json);

      expect(link.deepLinkPath, equals('/product/123'));
      expect(link.appspaceId, equals('app_001'));
      expect(link.referrerId, equals('user_42'));
      expect(link.referralCode, equals('ABC'));
    });

    test('fromJson handles response without referral fields', () {
      final json = <String, dynamic>{
        'deep_link_path': '/home',
        'appspace_id': 'app_001',
      };

      final link = DeferredLink.fromJson(json);

      expect(link.deepLinkPath, equals('/home'));
      expect(link.appspaceId, equals('app_001'));
      expect(link.referrerId, isNull);
      expect(link.referralCode, isNull);
    });

    test('toJson omits null fields', () {
      const link = DeferredLink(deepLinkPath: '/test', appspaceId: 'app_001');
      final json = link.toJson();

      expect(json['deep_link_path'], equals('/test'));
      expect(json['appspace_id'], equals('app_001'));
      expect(json.containsKey('referrer_id'), isFalse);
      expect(json.containsKey('referral_code'), isFalse);
    });
  });

  group('TolinkuMessage model', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'msg_1',
        'name': 'welcome_banner',
        'title': 'Welcome',
        'body': 'Thanks for signing up!',
        'trigger': 'first_open',
        'trigger_value': null,
        'background_color': '#FF5733',
        'priority': 1,
        'dismiss_days': 7,
      };

      final message = TolinkuMessage.fromJson(json);

      expect(message.id, equals('msg_1'));
      expect(message.name, equals('welcome_banner'));
      expect(message.title, equals('Welcome'));
      expect(message.body, equals('Thanks for signing up!'));
      expect(message.trigger, equals('first_open'));
      expect(message.triggerValue, isNull);
      expect(message.backgroundColor, equals('#FF5733'));
      expect(message.priority, equals(1));
      expect(message.dismissDays, equals(7));
    });

    test('fromJson handles minimal required fields', () {
      final json = {
        'id': 'msg_2',
        'name': 'minimal_message',
        'trigger': 'app_launch',
        'priority': 0,
      };

      final message = TolinkuMessage.fromJson(json);

      expect(message.id, equals('msg_2'));
      expect(message.name, equals('minimal_message'));
      expect(message.title, isNull);
      expect(message.body, isNull);
      expect(message.trigger, equals('app_launch'));
      expect(message.triggerValue, isNull);
      expect(message.backgroundColor, isNull);
      expect(message.priority, equals(0));
      expect(message.dismissDays, isNull);
    });

    test('toJson round-trips correctly', () {
      final original = TolinkuMessage(
        id: 'msg_1',
        name: 'test_message',
        title: 'Hello',
        body: 'World',
        trigger: 'first_open',
        priority: 2,
      );

      final json = original.toJson();
      final restored = TolinkuMessage.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.title, equals(original.title));
      expect(restored.body, equals(original.body));
      expect(restored.trigger, equals(original.trigger));
      expect(restored.priority, equals(original.priority));
    });

    test('toJson omits null fields', () {
      final message = TolinkuMessage(
        id: 'msg_1',
        name: 'test',
        trigger: 'first_open',
        priority: 1,
      );

      final json = message.toJson();

      expect(json.containsKey('title'), isFalse);
      expect(json.containsKey('body'), isFalse);
      expect(json.containsKey('trigger_value'), isFalse);
      expect(json.containsKey('background_color'), isFalse);
      expect(json.containsKey('dismiss_days'), isFalse);
      expect(json.containsKey('id'), isTrue);
      expect(json.containsKey('name'), isTrue);
      expect(json.containsKey('trigger'), isTrue);
      expect(json.containsKey('priority'), isTrue);
    });
  });

  group('TolinkuException', () {
    test('toString without status code', () {
      const exception = TolinkuException('Something went wrong');
      expect(exception.toString(), equals('TolinkuException: Something went wrong'));
    });

    test('toString with status code', () {
      const exception = TolinkuException('Not found', statusCode: 404);
      expect(exception.toString(), equals('TolinkuException(404): Not found'));
    });

    test('implements Exception', () {
      const exception = TolinkuException('test');
      expect(exception, isA<Exception>());
    });
  });

  group('TolinkuItem model', () {
    test('toJson includes all fields', () {
      final item = TolinkuItem(
        itemId: 'sku_1',
        itemName: 'T-Shirt',
        itemCategory: 'Apparel',
        itemBrand: 'Tolinku',
        itemVariant: 'Red / L',
        itemListName: 'Search Results',
        itemListId: 'search_results',
        itemImageUrl: 'https://example.com/img.jpg',
        price: 24.99,
        quantity: 2,
        currency: 'USD',
        couponCode: 'SAVE10',
        discount: 5.0,
      );
      final json = item.toJson();

      expect(json['item_id'], equals('sku_1'));
      expect(json['item_name'], equals('T-Shirt'));
      expect(json['item_category'], equals('Apparel'));
      expect(json['item_brand'], equals('Tolinku'));
      expect(json['item_variant'], equals('Red / L'));
      expect(json['item_list_name'], equals('Search Results'));
      expect(json['item_list_id'], equals('search_results'));
      expect(json['item_image_url'], equals('https://example.com/img.jpg'));
      expect(json['price'], equals(24.99));
      expect(json['quantity'], equals(2));
      expect(json['currency'], equals('USD'));
      expect(json['coupon_code'], equals('SAVE10'));
      expect(json['discount'], equals(5.0));
    });

    test('toJson omits null optional fields', () {
      final item = TolinkuItem(itemId: 'sku_1');
      final json = item.toJson();

      expect(json['item_id'], equals('sku_1'));
      expect(json['quantity'], equals(1));
      expect(json.containsKey('item_name'), isFalse);
      expect(json.containsKey('price'), isFalse);
      expect(json.containsKey('currency'), isFalse);
      expect(json.containsKey('item_variant'), isFalse);
      expect(json.containsKey('item_image_url'), isFalse);
      expect(json.containsKey('coupon_code'), isFalse);
      expect(json.containsKey('discount'), isFalse);
    });

    test('toJson always includes quantity', () {
      final item = TolinkuItem(itemId: 'sku_1');
      final json = item.toJson();
      expect(json.containsKey('quantity'), isTrue);
      expect(json['quantity'], equals(1));
    });

    test('toJson uses correct snake_case keys', () {
      final item = TolinkuItem(
        itemId: 'sku_1',
        itemName: 'Test',
        itemCategory: 'Cat',
        itemBrand: 'Brand',
        itemVariant: 'Var',
        itemListName: 'List',
        itemListId: 'list_1',
        itemImageUrl: 'https://img.jpg',
        couponCode: 'CODE',
      );
      final json = item.toJson();

      // Verify snake_case (not camelCase)
      expect(json.containsKey('item_id'), isTrue);
      expect(json.containsKey('itemId'), isFalse);
      expect(json.containsKey('item_name'), isTrue);
      expect(json.containsKey('itemName'), isFalse);
      expect(json.containsKey('item_category'), isTrue);
      expect(json.containsKey('item_brand'), isTrue);
      expect(json.containsKey('item_variant'), isTrue);
      expect(json.containsKey('item_list_name'), isTrue);
      expect(json.containsKey('item_list_id'), isTrue);
      expect(json.containsKey('item_image_url'), isTrue);
      expect(json.containsKey('coupon_code'), isTrue);
    });
  });

  group('Tolinku client ecommerce', () {
    test('ecommerce accessor available after configure', () async {
      Tolinku.configure(
        apiKey: 'tolk_pub_test_key',
        baseUrl: 'https://links.example.com',
      );

      expect(Tolinku.instance.ecommerce, isA<Ecommerce>());

      await Tolinku.instance.dispose();
    });
  });

  group('Tolinku client', () {
    test('throws when accessed before configure', () {
      // Reset state by checking if already configured and disposing.
      if (Tolinku.isConfigured) {
        Tolinku.instance.dispose();
      }

      expect(
        () => Tolinku.instance,
        throwsA(isA<TolinkuException>()),
      );
    });

    test('isConfigured returns false before configure', () {
      if (Tolinku.isConfigured) {
        Tolinku.instance.dispose();
      }
      expect(Tolinku.isConfigured, isFalse);
    });

    test('configure creates a usable instance', () async {
      Tolinku.configure(
        apiKey: 'tolk_pub_test_key',
        baseUrl: 'https://links.example.com',
      );

      expect(Tolinku.isConfigured, isTrue);
      expect(Tolinku.instance, isA<Tolinku>());
      expect(Tolinku.instance.analytics, isA<Analytics>());
      expect(Tolinku.instance.referrals, isA<Referrals>());
      expect(Tolinku.instance.deferred, isA<Deferred>());
      expect(Tolinku.instance.messages, isA<Messages>());

      // Clean up.
      await Tolinku.instance.dispose();
    });

    test('dispose resets the singleton', () async {
      Tolinku.configure(
        apiKey: 'tolk_pub_test_key',
        baseUrl: 'https://links.example.com',
      );

      await Tolinku.instance.dispose();

      expect(Tolinku.isConfigured, isFalse);
      expect(
        () => Tolinku.instance,
        throwsA(isA<TolinkuException>()),
      );
    });

    test('reconfigure replaces existing instance', () async {
      Tolinku.configure(
        apiKey: 'tolk_pub_key_1',
        baseUrl: 'https://links1.example.com',
      );

      final first = Tolinku.instance;

      // Dispose the first instance before reconfiguring.
      await Tolinku.instance.dispose();

      Tolinku.configure(
        apiKey: 'tolk_pub_key_2',
        baseUrl: 'https://links2.example.com',
      );

      final second = Tolinku.instance;
      expect(identical(first, second), isFalse);

      // Clean up.
      await Tolinku.instance.dispose();
    });
  });
}
