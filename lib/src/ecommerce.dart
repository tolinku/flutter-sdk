import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'http_client.dart';

/// Maximum number of events to queue before auto-flushing.
const int _batchSize = 10;

/// Maximum queue size to prevent unbounded memory growth.
const int _maxQueueSize = 500;

/// Interval between automatic flushes.
const Duration _flushInterval = Duration(seconds: 5);

/// Storage key for the cart ID.
const String _cartIdKey = 'tolinku_ecom_cart_id';

/// A product item for ecommerce event tracking.
class TolinkuItem {
  const TolinkuItem({
    required this.itemId,
    this.itemName,
    this.itemCategory,
    this.itemBrand,
    this.itemVariant,
    this.itemListName,
    this.itemListId,
    this.itemImageUrl,
    this.price,
    this.quantity = 1,
    this.currency,
    this.couponCode,
    this.discount,
  });

  final String itemId;
  final String? itemName;
  final String? itemCategory;
  final String? itemBrand;
  final String? itemVariant;
  final String? itemListName;
  final String? itemListId;
  final String? itemImageUrl;
  final double? price;
  final int quantity;
  final String? currency;
  final String? couponCode;
  final double? discount;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'item_id': itemId,
      'quantity': quantity,
    };
    if (itemName != null) json['item_name'] = itemName;
    if (itemCategory != null) json['item_category'] = itemCategory;
    if (itemBrand != null) json['item_brand'] = itemBrand;
    if (itemVariant != null) json['item_variant'] = itemVariant;
    if (itemListName != null) json['item_list_name'] = itemListName;
    if (itemListId != null) json['item_list_id'] = itemListId;
    if (itemImageUrl != null) json['item_image_url'] = itemImageUrl;
    if (price != null) json['price'] = price;
    if (currency != null) json['currency'] = currency;
    if (couponCode != null) json['coupon_code'] = couponCode;
    if (discount != null) json['discount'] = discount;
    return json;
  }
}

/// Ecommerce event tracking: purchases, carts, products, revenue.
///
/// Events are queued in memory and sent in batches to
/// `/v1/api/analytics/ecommerce/batch`.
class Ecommerce {
  Ecommerce(this._httpClient, this._getUserId) {
    _startFlushTimer();
  }

  final TolinkuHttpClient _httpClient;
  final String? Function() _getUserId;
  final List<Map<String, dynamic>> _queue = [];
  Timer? _flushTimer;
  bool _disposed = false;
  String? _memoryCartId;

  // ─── Public methods (13 event types) ────────────────────

  Future<void> viewItem({required List<TolinkuItem> items}) async {
    await _enqueue({'event_type': 'view_item', 'items': items.map((i) => i.toJson()).toList()});
  }

  Future<void> addToCart({required List<TolinkuItem> items, String? cartId}) async {
    final resolvedCartId = cartId ?? await _getOrCreateCartId();
    await _enqueue({'event_type': 'add_to_cart', 'cart_id': resolvedCartId, 'items': items.map((i) => i.toJson()).toList()});
  }

  Future<void> removeFromCart({required List<TolinkuItem> items, String? cartId}) async {
    final resolvedCartId = cartId ?? await _getCartId();
    await _enqueue({
      'event_type': 'remove_from_cart',
      if (resolvedCartId != null) 'cart_id': resolvedCartId,
      'items': items.map((i) => i.toJson()).toList(),
    });
  }

  Future<void> addToWishlist({required List<TolinkuItem> items}) async {
    await _enqueue({'event_type': 'add_to_wishlist', 'items': items.map((i) => i.toJson()).toList()});
  }

  Future<void> viewCart() async {
    final cartId = await _getCartId();
    await _enqueue({'event_type': 'view_cart', if (cartId != null) 'cart_id': cartId});
  }

  Future<void> addPaymentInfo({String? cartId}) async {
    final resolvedCartId = cartId ?? await _getCartId();
    await _enqueue({'event_type': 'add_payment_info', if (resolvedCartId != null) 'cart_id': resolvedCartId});
  }

  Future<void> beginCheckout({double? revenue, String? currency, String? cartId, List<TolinkuItem>? items}) async {
    final resolvedCartId = cartId ?? await _getCartId();
    await _enqueue({
      'event_type': 'begin_checkout',
      if (revenue != null) 'revenue': revenue,
      if (currency != null) 'currency': currency,
      if (resolvedCartId != null) 'cart_id': resolvedCartId,
      if (items != null) 'items': items.map((i) => i.toJson()).toList(),
    });
  }

  Future<void> purchase({
    required String transactionId,
    required double revenue,
    required String currency,
    List<TolinkuItem>? items,
    String? cartId,
    String? couponCode,
    double? discount,
    double? shipping,
    double? tax,
  }) async {
    final resolvedCartId = cartId ?? await _getCartId();
    await _enqueue({
      'event_type': 'purchase',
      'transaction_id': transactionId,
      'revenue': revenue,
      'currency': currency,
      if (resolvedCartId != null) 'cart_id': resolvedCartId,
      if (couponCode != null) 'coupon_code': couponCode,
      if (discount != null) 'discount': discount,
      if (shipping != null) 'shipping': shipping,
      if (tax != null) 'tax': tax,
      if (items != null) 'items': items.map((i) => i.toJson()).toList(),
    });
    await _clearCartId();
  }

  Future<void> refund({
    required String transactionId,
    required double revenue,
    String? currency,
    List<TolinkuItem>? items,
  }) async {
    await _enqueue({
      'event_type': 'refund',
      'transaction_id': transactionId,
      'revenue': revenue,
      if (currency != null) 'currency': currency,
      if (items != null) 'items': items.map((i) => i.toJson()).toList(),
    });
  }

  Future<void> search({required String searchTerm}) async {
    await _enqueue({'event_type': 'search', 'properties': {'search_term': searchTerm}});
  }

  Future<void> share({String? itemId, String? url, String? method}) async {
    final props = <String, String>{};
    if (itemId != null) props['item_id'] = itemId;
    if (url != null) props['url'] = url;
    if (method != null) props['method'] = method;
    await _enqueue({'event_type': 'share', 'properties': props});
  }

  Future<void> rate({required String itemId, required double rating, double? maxRating}) async {
    final props = <String, String>{'item_id': itemId, 'rating': rating.toString()};
    if (maxRating != null) props['max_rating'] = maxRating.toString();
    await _enqueue({'event_type': 'rate', 'properties': props});
  }

  Future<void> spendCredits({required double revenue, required String currency}) async {
    await _enqueue({'event_type': 'spend_credits', 'revenue': revenue, 'currency': currency});
  }

  // ─── Flush & Dispose ───────────────────────────────────

  Future<void> flush() async {
    if (_queue.isEmpty) return;

    final events = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();

    try {
      final result = await _httpClient.postBatch(
        '/v1/api/analytics/ecommerce/batch',
        events: events,
      );
      final errors = result['errors'] as List<dynamic>?;
      if (errors != null && errors.isNotEmpty) {
        _debugLog('Ecommerce batch partial failure: $errors');
      }
      _debugLog('Flushed ${events.length} ecommerce events');
    } catch (e) {
      _queue.insertAll(0, events);
      while (_queue.length > _maxQueueSize) {
        _queue.removeAt(0);
      }
      _debugLog('Failed to flush ecommerce events: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    try {
      await flush();
    } catch (_) {
      // Best-effort flush on dispose.
    }
  }

  // ─── Private ───────────────────────────────────────────

  Future<void> _enqueue(Map<String, dynamic> event) async {
    // Inject user_id
    final userId = _getUserId();
    if (userId != null) event['user_id'] = userId;

    _queue.add(event);

    if (_queue.length > _maxQueueSize) {
      _queue.removeAt(0);
    }

    if (_queue.length >= _batchSize) {
      await flush();
    }
  }

  void _startFlushTimer() {
    _flushTimer = Timer.periodic(_flushInterval, (_) {
      if (_queue.isNotEmpty && !_disposed) {
        flush().catchError((_) {
          // Swallow errors from timer-triggered flushes.
        });
      }
    });
  }

  // ─── Cart ID lifecycle (SharedPreferences + memory fallback) ─

  Future<String> _getOrCreateCartId() async {
    final existing = await _getCartId();
    if (existing != null) return existing;

    final cartId = _generateId();
    await _setCartId(cartId);
    return cartId;
  }

  Future<String?> _getCartId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_cartIdKey);
      if (stored != null) return stored;
    } catch (_) { /* ignore */ }
    return _memoryCartId;
  }

  Future<void> _setCartId(String cartId) async {
    _memoryCartId = cartId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cartIdKey, cartId);
    } catch (_) { /* memory fallback already set */ }
  }

  Future<void> _clearCartId() async {
    _memoryCartId = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cartIdKey);
    } catch (_) { /* ignore */ }
  }

  String _generateId() {
    // UUID v4 using dart:math Random.secure() for proper entropy
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  void _debugLog(String message) {
    if (isTolinkuDebugMode) {
      // ignore: avoid_print
      print('[TolinkuSDK Ecommerce] $message');
    }
  }
}
