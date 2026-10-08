import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:zcanopy/config/api_config.dart';
import 'package:zcanopy/services/endpoints.dart';
import 'package:zcanopy/utils/property_normalizer.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class GatewayApi {
  GatewayApi._();

  static final GatewayApi instance = GatewayApi._();

  factory GatewayApi() => instance;

  Box get _store => Hive.box('myStore');

  String? get sessionToken => ApiConfig.sessionToken;

  // ==================== TRANSPORT ====================

  Future<Map<String, dynamic>> _send(
    String method,
    Uri uri, {
    Object? body,
    bool retryOnUnauthorized = true,
  }) async {
    final headers = Map<String, String>.from(ApiConfig.headers);
    http.Response response;

    try {
      if (method == 'GET') {
        response = await http.get(uri, headers: headers).timeout(
              const Duration(seconds: 30),
            );
      } else {
        response = await http.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ).timeout(const Duration(seconds: 45));
      }
    } catch (e) {
      throw ApiException(0, 'Network error: $e');
    }

    if (response.statusCode == 401 && retryOnUnauthorized) {
      final fresh = await ensureCustomerSession(force: true);
      if (fresh != null) {
        return _send(method, uri,
            body: body, retryOnUnauthorized: false);
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _messageOf(response.body));
    }

    return _shape(uri, method, decode(response.body));
  }

  Future<Map<String, dynamic>> _put(Uri uri, {Object? body}) async {
    final response = await http.put(
      uri,
      headers: ApiConfig.headers,
      body: body == null ? null : jsonEncode(body),
    ).timeout(const Duration(seconds: 45));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _messageOf(response.body));
    }
    return decode(response.body);
  }

  static Map<String, dynamic> decode(String raw) {
    if (raw.trim().isEmpty) return {'success': true};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      decoded.putIfAbsent('success', () => true);
      return decoded;
    }
    if (decoded is List) return {'items': decoded, 'success': true};
    return {'data': decoded, 'success': true};
  }

  static const List<String> _listKeys = [
    'properties',
    'items',
    'data',
    'results',
    'bookings',
    'transactions',
    'notifications',
    'favorites',
    'comments',
  ];

  Map<String, dynamic> _withProperties(Map<String, dynamic> data) {
    if (data['properties'] is List) {
      data['properties'] = normalizeProperties(data['properties']);
      return data;
    }
    for (final key in _listKeys) {
      if (data[key] is List) {
        data['properties'] = normalizeProperties(data[key]);
        return data;
      }
    }
    return data;
  }

  Map<String, dynamic> _withList(Map<String, dynamic> data, String key) {
    if (data[key] is List) return data;
    for (final candidate in _listKeys) {
      if (data[candidate] is List) {
        data[key] = data[candidate];
        return data;
      }
    }
    data[key] = data[key] is List ? data[key] : <dynamic>[];
    return data;
  }

  Map<String, dynamic> _withDetails(Map<String, dynamic> data) {
    final nested = data['property'];
    if (nested is Map) {
      return normalizeProperty(Map<String, dynamic>.from(nested));
    }
    if (data.containsKey('properties') && data['properties'] is List) {
      final list = normalizeProperties(data['properties']);
      if (list.isNotEmpty) return list.first;
    }
    return normalizeProperty(data);
  }

  Map<String, dynamic> _shape(Uri uri, String method, Map<String, dynamic> data) {
    final path = uri.path;
    final isRetrieve = method == 'POST' && path.contains('retrieve');
    if (method != 'GET' && !isRetrieve) return data;

    bool has(String segment) => path.contains(segment);

    if (has('/properties/details')) return _withDetails(data);
    if (has('/searches')) return _withList(data, 'searches');
    if (has('/favorites')) {
      final out = _withProperties(data);
      out['properties'] ??= <dynamic>[];
      out['favorites'] = out['properties'];
      return out;
    }
    if (has('/comments')) return _withList(data, 'comments');
    if (has('/notifications')) return _withList(data, 'notifications');
    if (has('transaction')) return _withList(data, 'transactions');
    if (has('/bookings') || path.endsWith('/bookings')) {
      return _withList(data, 'bookings');
    }
    if (has('/search') ||
        has('/nearby') ||
        has('/featured') ||
        has('/customer/properties') ||
        has('get_properties') ||
        has('broker-properties')) {
      return _withProperties(data);
    }
    return data;
  }

  String _messageOf(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['message'] != null) {
        final message = data['message'];
        if (message is List) return message.join(', ');
        return message.toString();
      }
    } catch (_) {}
    return body.isEmpty ? 'Request failed' : body;
  }

  // ==================== SESSION ====================

  /// The gateway rejects empty `deviceId` values (HTTP 500), so reuse a
  /// persisted id and only generate one the first time it's needed.
  String _deviceId() {
    try {
      final existing = _store.get('deviceId')?.toString();
      if (existing != null && existing.isNotEmpty) return existing;
    } catch (_) {}
    final rand = Random.secure();
    final suffix =
        List.generate(16, (_) => rand.nextInt(16).toRadixString(16)).join();
    final generated = 'zcanopy-${DateTime.now().millisecondsSinceEpoch}-$suffix';
    try {
      _store.put('deviceId', generated);
    } catch (_) {}
    return generated;
  }

  Future<String?> ensureCustomerSession(
      {String deviceId = '', bool force = false}) async {
    if (!force) {
      final existing = sessionToken;
      if (existing != null && existing.isNotEmpty) return existing;
    }

    final data = await _send(
      'POST',
      Endpoints.uri(Endpoints.customerSession),
      body: {
        'deviceId': deviceId.isEmpty ? _deviceId() : deviceId,
        'ttlSeconds': 604800,
      },
      retryOnUnauthorized: false,
    );

    final token =
        (data['sessionToken'] ?? data['sessionId'])?.toString();
    if (token != null && token.isNotEmpty) {
      await _store.put('sessionID', token);
      final sessionId = data['sessionId']?.toString();
      if (sessionId != null && sessionId.isNotEmpty) {
        await _store.put('sessionUuid', sessionId);
      }
      return token;
    }
    return null;
  }

  Future<bool> validateSession() async {
    final token = sessionToken;
    if (token == null || token.isEmpty) {
      final fresh = await ensureCustomerSession();
      return fresh != null && fresh.isNotEmpty;
    }

    final expiry = _jwtExpiry(token);
    if (expiry == null) return true;

    if (expiry.isAfter(DateTime.now().add(const Duration(seconds: 60)))) {
      return true;
    }

    final fresh = await ensureCustomerSession(force: true);
    return fresh != null && fresh.isNotEmpty;
  }

  DateTime? _jwtExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 3) return null;
      final payload = base64Url.normalize(parts[1]);
      final data = jsonDecode(utf8.decode(base64Url.decode(payload)));
      final exp = data['exp'];
      if (exp is int) return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      if (exp is String) {
        return DateTime.fromMillisecondsSinceEpoch(
            (int.tryParse(exp) ?? 0) * 1000);
      }
    } catch (_) {}
    return null;
  }

  Future<void> logoutSession() async {
    final token = sessionToken;
    if (token == null || token.isEmpty) return;
    try {
      await _send(
        'POST',
        Endpoints.uri(Endpoints.logoutUser),
        body: {'userID': token},
        retryOnUnauthorized: false,
      );
    } catch (_) {}
    await _store.delete('sessionID');
    await _store.delete('sessionUuid');
  }

  // ==================== PROPERTIES ====================

  Future<Map<String, dynamic>> getCustomerProperties({
    int page = 1,
    int limit = 12,
    double? lat,
    double? lng,
    double radiusKm = 25,
    String? propertyType,
  }) {
    return _send('GET', Endpoints.uri(Endpoints.customerProperties, {
      'page': page,
      'limit': limit,
      'lat': lat,
      'lng': lng,
      'radiusKm': radiusKm,
      'propertyType': propertyType,
    }));
  }

  Future<Map<String, dynamic>> getPropertyDetails({required String propertyId}) {
    return _send('GET',
        Endpoints.uri(Endpoints.customerPropertyDetails, {'propertyId': propertyId}));
  }

  Future<Map<String, dynamic>> searchProperties({
    String? query,
    String? location,
    String? propertyType,
    String? subCounty,
    String? district,
    num? minPrice,
    num? maxPrice,
    double? lat,
    double? lng,
    double? radiusKm,
    int page = 1,
    int limit = 12,
  }) {
    return _send('GET', Endpoints.uri(Endpoints.listingsSearch, {
      'query': query,
      'location': location,
      'propertyType': propertyType,
      'subCounty': subCounty,
      'district': district,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'lat': lat,
      'lng': lng,
      'radiusKm': radiusKm,
      'page': page,
      'limit': limit,
      'sessionToken': sessionToken,
    }));
  }

  Future<Map<String, dynamic>> getNearbyProperties({
    required double lat,
    required double long,
    double radiusKm = 25,
    String? propertyType,
    int page = 1,
    int limit = 20,
  }) {
    return _send('GET', Endpoints.uri(Endpoints.listingsNearby, {
      'lat': lat,
      'long': long,
      'radiusKm': radiusKm,
      'propertyType': propertyType,
      'page': page,
      'limit': limit,
      'sessionToken': sessionToken,
    }));
  }

  Future<Map<String, dynamic>> getFeaturedProperties({int limit = 6}) {
    return _send('GET',
        Endpoints.uri(Endpoints.featuredProperties, {'limit': limit}));
  }

  Future<Map<String, dynamic>> getBrokerPropertiesForCustomer({
    required String brokerCode,
    int page = 1,
    int limit = 12,
  }) {
    return _send('GET', Endpoints.uri(Endpoints.customerBrokerProperties, {
      'brokerCode': brokerCode,
      'page': page,
      'limit': limit,
      'sessionToken': sessionToken,
    }));
  }

  Future<Map<String, dynamic>> getOwnerProperties({
    required String brokerCode,
    int page = 1,
    int limit = 50,
    String? location,
    String? propertyType,
  }) {
    return _send('GET', Endpoints.uri(Endpoints.listingsProperties, {
      'brokerCode': brokerCode,
      'page': page,
      'limit': limit,
      'location': location,
      'propertyType': propertyType,
      'sessionToken': sessionToken,
    }));
  }

  Future<Map<String, dynamic>> resolveLocationName({
    required double lat,
    required double long,
  }) {
    return _send('GET',
        Endpoints.uri(Endpoints.resolveLocationName, {'lat': lat, 'long': long}));
  }

  Future<Map<String, dynamic>> getCurrentLocation({
    required double lat,
    required double long,
  }) {
    return _send('GET',
        Endpoints.uri(Endpoints.currentLocation, {'lat': lat, 'long': long}));
  }

  // ==================== FAVORITES ====================

  Future<Map<String, dynamic>> toggleFavorite({
    required String propertyId,
    String? propertyTitle,
    String? propertyLocation,
    String? brokerCode,
    String? imageUrl,
    num? price,
  }) {
    return _send(
      'POST',
      Endpoints.uri(Endpoints.favoritesToggle),
      body: {
        'propertyId': propertyId,
        if (propertyTitle != null) 'propertyTitle': propertyTitle,
        if (propertyLocation != null) 'propertyLocation': propertyLocation,
        if (brokerCode != null) 'brokerCode': brokerCode,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (price != null) 'price': price,
      },
    );
  }

  Future<Map<String, dynamic>> getFavorites({int page = 1, int limit = 50}) {
    return _send(
        'GET', Endpoints.uri(Endpoints.favorites, {'page': page, 'limit': limit}));
  }

  // ==================== COMMENTS ====================

  Future<Map<String, dynamic>> addComment({
    required String propertyId,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    required String comment,
    num? rating,
  }) {
    return _send(
      'POST',
      Endpoints.uri(Endpoints.comments),
      body: {
        'propertyId': propertyId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        if (customerEmail != null && customerEmail.isNotEmpty)
          'customerEmail': customerEmail,
        'comment': comment,
        if (rating != null) 'rating': rating,
      },
    );
  }

  Future<Map<String, dynamic>> getPropertyComments({
    required String propertyId,
    int page = 1,
    int limit = 10,
  }) {
    return _send(
        'GET',
        Endpoints.uri(Endpoints.propertyComments(propertyId),
            {'page': page, 'limit': limit}));
  }

  // ==================== SEARCH HISTORY ====================

  Future<Map<String, dynamic>> recordSearch({
    String? query,
    String? location,
    num? radius,
    String? propertyType,
    Map<String, dynamic>? filters,
    List<String>? resultPropertyIds,
    int? resultCount,
    num? minPrice,
    num? maxPrice,
    String? subCounty,
    String? district,
  }) {
    return _send(
      'POST',
      Endpoints.uri(Endpoints.searchRecord),
      body: {
        if (query != null) 'query': query,
        if (location != null) 'location': location,
        if (radius != null) 'radius': radius,
        if (propertyType != null) 'propertyType': propertyType,
        if (filters != null) 'filters': filters,
        if (resultPropertyIds != null)
          'resultPropertyIds': resultPropertyIds,
        if (resultCount != null) 'resultCount': resultCount,
        if (minPrice != null) 'minPrice': minPrice,
        if (maxPrice != null) 'maxPrice': maxPrice,
        if (subCounty != null) 'subCounty': subCounty,
        if (district != null) 'district': district,
        'sessionToken': sessionToken,
      },
    );
  }

  Future<Map<String, dynamic>> retrieveSearches({
    int page = 1,
    int limit = 10,
  }) {
    return _send(
      'POST',
      Endpoints.uri(Endpoints.searchesRetrieve),
      body: {'sessionToken': sessionToken, 'page': page, 'limit': limit},
    );
  }

  Future<Map<String, dynamic>> getSearches({
    int page = 1,
    int limit = 10,
  }) {
    return _send(
        'GET', Endpoints.uri(Endpoints.searches, {'page': page, 'limit': limit}));
  }

  // ==================== BOOKINGS ====================

  Future<Map<String, dynamic>> getCustomerBookings({
    int page = 1,
    int limit = 10,
  }) {
    return _send(
        'GET', Endpoints.uri(Endpoints.customerBookings, {'page': page, 'limit': limit}));
  }

  Future<Map<String, dynamic>> getBookingsBySession() {
    return _send(
        'GET', Endpoints.uri(Endpoints.bookingsBySession, {'sessionToken': sessionToken}));
  }

  Future<Map<String, dynamic>> getBookingsByPhone({
    required String customerPhone,
    int page = 1,
    int limit = 10,
  }) {
    return _send('GET', Endpoints.uri(Endpoints.customerBookingsPhone, {
      'customerPhone': customerPhone,
      'page': page,
      'limit': limit,
    }));
  }

  Future<Map<String, dynamic>> getLegacyBookings({
    required String brokerCode,
    int page = 1,
    int limit = 10,
  }) {
    return _send('GET', Endpoints.uri(Endpoints.legacyBookings, {
      'user_id': brokerCode,
      'page': page,
      'limit': limit,
    }));
  }

  Future<Map<String, dynamic>> retrieveBooking({
    required String code,
    required String phoneNumber,
  }) {
    return _send(
      'POST',
      Endpoints.uri(Endpoints.bookingsRetrieve),
      body: {'code': code, 'phoneNumber': phoneNumber},
    );
  }

  Future<Map<String, dynamic>> retrieveBookingByCode({
    required String bookingCode,
    required String customerPhone,
  }) {
    return _send(
      'POST',
      Endpoints.uri(Endpoints.bookingsRetrieveByCode),
      body: {'bookingCode': bookingCode, 'customerPhone': customerPhone},
    );
  }

  Future<Map<String, dynamic>> createBooking({
    required String propertyId,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    required String date,
    num amount = 0,
    String reason = 'property_access',
    String status = 'pending',
  }) {
    return _send(
      'POST',
      Endpoints.uri(Endpoints.customerBookings),
      body: {
        'propertyId': propertyId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        if (customerEmail != null && customerEmail.isNotEmpty)
          'customerEmail': customerEmail,
        'date': date,
        'amount': amount,
        'reason': reason,
        'status': status,
      },
    );
  }

  Future<Map<String, dynamic>> declineBooking({
    required String transactionCode,
  }) {
    return _send(
      'POST',
      Endpoints.uri(Endpoints.declineBooking),
      body: {'bookingId': transactionCode},
    );
  }

  // ==================== PAYMENTS ====================

  Future<Map<String, dynamic>> getTransactions({
    int page = 1,
    int limit = 20,
  }) {
    return _send(
        'GET', Endpoints.uri(Endpoints.transactions, {'page': page, 'limit': limit}));
  }

  Future<Map<String, dynamic>> getTransactionRecords({
    required String userId,
    int page = 1,
    int limit = 20,
  }) {
    return _send('GET', Endpoints.uri(Endpoints.transactionRecords, {
      'user_id': userId,
      'page': page,
      'limit': limit,
    }));
  }

  Future<Map<String, dynamic>> initiatePayment({
    required String phoneNumber,
    required num amount,
    required String userId,
  }) {
    return _send(
      'POST',
      Endpoints.uri(Endpoints.initiatePayment),
      body: {
        'phoneNumber': phoneNumber,
        'amount': amount,
        'userId': userId,
      },
    );
  }

  Future<Map<String, dynamic>> initiatePropertyAccessPayment({
    required String propertyId,
    required num amount,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? date,
    String reason = 'property_access',
    String status = 'pending',
  }) {
    return _send(
      'POST',
      Endpoints.uri(Endpoints.accessPayment),
      body: {
        'propertyId': propertyId,
        'amount': amount,
        if (customerName != null && customerName.isNotEmpty)
          'customerName': customerName,
        if (customerPhone != null && customerPhone.isNotEmpty)
          'customerPhone': customerPhone,
        if (customerEmail != null && customerEmail.isNotEmpty)
          'customerEmail': customerEmail,
        if (date != null) 'date': date,
        'reason': reason,
        'status': status,
      },
    );
  }

  Future<Map<String, dynamic>> retrievePayment({
    required String code,
    String? phoneNumber,
  }) {
    return _send(
      'POST',
      Endpoints.uri(Endpoints.paymentsRetrieve),
      body: {
        'code': code,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phoneNumber': phoneNumber,
      },
    );
  }

  // ==================== NOTIFICATIONS ====================

  Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    int limit = 50,
    String? brokerCode,
    String? type,
    bool? read,
  }) {
    return _send('GET', Endpoints.uri(Endpoints.notifications, {
      'sessionToken': sessionToken,
      'brokerCode': brokerCode,
      'page': page,
      'limit': limit,
      'type': type,
      'read': read == null ? null : read.toString(),
    }));
  }

  Future<Map<String, dynamic>> markNotificationsRead({
    String? id,
    List<String>? ids,
    bool all = false,
  }) {
    return _send(
      'POST',
      Endpoints.uri(Endpoints.markNotificationsRead),
      body: {
        'sessionToken': sessionToken,
        if (id != null) 'id': id,
        if (ids != null && ids.isNotEmpty) 'ids': ids,
        'all': all,
      },
    );
  }

  // ==================== SUBSCRIPTIONS ====================

  Future<Map<String, dynamic>> getSubscriptionPackages() {
    return _send('GET', Endpoints.uri(Endpoints.subscriptionPackages));
  }

  Future<Map<String, dynamic>> getSubscriptionDetails({
    required String brokerCode,
  }) {
    return _send(
        'GET', Endpoints.uri(Endpoints.subscriptionDetails, {'brokerCode': brokerCode}));
  }

  Future<Map<String, dynamic>> getBrokerDashboard() {
    return _send('GET', Endpoints.uri(Endpoints.brokerDashboard));
  }

  Future<Map<String, dynamic>> subscribeBroker({
    required String brokerId,
    required String tier,
    String? phoneNumber,
    String? paymentMethod,
  }) {
    return _send(
      'POST',
      Endpoints.uri('/brokers/$brokerId${Endpoints.brokerSubscribeSuffix}'),
      body: {
        'tier': tier,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
      },
    );
  }

  Future<Map<String, dynamic>> cancelSubscription({
    required String brokerCode,
    String? password,
    String? emailOtp,
    String? sessionId,
  }) {
    return _send(
      'POST',
      Endpoints.uri(Endpoints.subscriptionCancel),
      body: {
        'brokerCode': brokerCode,
        if (password != null) 'password': password,
        if (emailOtp != null) 'emailOtp': emailOtp,
        if (sessionId != null) 'sessionId': sessionId,
      },
    );
  }

  // ==================== PHONE OTP / ACCOUNT TYPE ====================

  Future<Map<String, dynamic>> requestPhoneOTP({required String userId}) {
    return _send('POST', Endpoints.uri('/auth/get-phone-verification-code'),
        body: {'userID': userId});
  }

  Future<Map<String, dynamic>> verifyPhoneOTP({
    required String verificationId,
    required String userId,
    required String code,
  }) {
    return _send('POST', Endpoints.uri('/gate-way/verify-phone-otp'),
        body: {'verificationID': verificationId, 'userID': userId, 'code': code});
  }

  Future<Map<String, dynamic>> resendPhoneOTP({
    required String verificationId,
    required String userId,
  }) {
    return _send('POST', Endpoints.uri('/gate-way/resend-phone-otp'),
        body: {'verificationID': verificationId, 'userID': userId});
  }

  Future<Map<String, dynamic>> updateAccountType({
    required String userId,
    required String accountType,
    String? phoneNumber,
  }) {
    return _send('POST', Endpoints.uri('/auth/update-account-type'),
        body: {
          'userId': userId,
          'accountType': accountType,
          if (phoneNumber != null) 'phoneNumber': phoneNumber,
        });
  }

  Future<Map<String, dynamic>> getBroker(String brokerId) {
    return _send('GET', Endpoints.uri('/brokers/$brokerId'));
  }

  // ==================== FEEDBACK / ACCOUNT ====================

  Future<Map<String, dynamic>> submitFeedback({
    String? brokerCode,
    required String email,
    required String phone,
    required String content,
  }) {
    return _send(
      'POST',
      Endpoints.uri(Endpoints.feedbackSubmit),
      body: {
        if (brokerCode != null && brokerCode.isNotEmpty)
          'brokerCode': brokerCode,
        'email': email,
        'phone': phone,
        'content': content,
      },
    );
  }

  Future<Map<String, dynamic>> requestAccountDeletionOtp({
    required String userId,
  }) {
    return _send('POST', Endpoints.uri(Endpoints.accountDeletionOtp),
        body: {'userId': userId});
  }

  Future<Map<String, dynamic>> deleteUserAccount({
    required String userId,
  }) {
    return _send('POST', Endpoints.uri(Endpoints.deleteUserAccount),
        body: {'userID': userId});
  }

  Future<Map<String, dynamic>> changePasswordOtp({
    String? email,
    String? phoneNumber,
  }) {
    return _send(
      'POST',
      Endpoints.uri(Endpoints.changePasswordOtp),
      body: {
        if (email != null) 'email': email,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
      },
    );
  }

  Future<Map<String, dynamic>> updateUserField({
    required String id,
    required Map<String, dynamic> fields,
  }) {
    return _send('POST', Endpoints.uri(Endpoints.updateUserField),
        body: {'id': id, 'fields': fields});
  }

  Future<Map<String, dynamic>> saveUserInfo({
    required String userId,
    String? username,
    String? email,
    String? phoneNumber,
    String? location,
    String? photoURL,
  }) {
    return _send(
      'POST',
      Endpoints.uri(Endpoints.saveUserInfo),
      body: {
        'userId': userId,
        if (username != null) 'username': username,
        if (email != null) 'email': email,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (location != null) 'location': location,
        if (photoURL != null) 'photoURL': photoURL,
      },
    );
  }

  // ==================== PROPERTIES (OWNER) ====================

  Future<Map<String, dynamic>> createProperty({
    required String brokerCode,
    required String title,
    required String description,
    required String propertyType,
    required String location,
    required num price,
    num? brokerBookingFee,
    List<String> imageUrl = const [],
    List<String> videoUrl = const [],
    double? lat,
    double? lng,
    String? subCounty,
    String? district,
  }) {
    return _send(
      'POST',
      Endpoints.uri(Endpoints.properties),
      body: {
        'brokersUniqueCode': brokerCode,
        'title': title,
        'description': description,
        'propertyType': propertyType,
        'location': location,
        'price': price,
        if (brokerBookingFee != null) 'brokerBookingFee': brokerBookingFee,
        'imageUrl': imageUrl,
        'videoUrl': videoUrl,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (subCounty != null) 'subCounty': subCounty,
        if (district != null) 'district': district,
      },
    );
  }

  Future<Map<String, dynamic>> updateProperty({
    required String propertyId,
    required Map<String, dynamic> updates,
  }) async {
    final response = await _send('POST',
        Endpoints.uri('${Endpoints.properties}/$propertyId'),
        body: updates);
    return response;
  }

  Future<Map<String, dynamic>> deleteProperty({
    required String propertyId,
  }) {
    return _send('POST',
        Endpoints.uri('${Endpoints.properties}/$propertyId/delete'));
  }

  Future<Map<String, dynamic>> updatePropertyAvailability({
    required String propertyId,
    required bool isAvailable,
  }) {
    return _put(Endpoints.uri('${Endpoints.properties}/$propertyId/availability'),
        body: {'isAvailable': isAvailable});
  }

  // ==================== UPLOAD ====================

  Future<Map<String, dynamic>> presignUpload({
    required String filename,
    required String contentType,
    String folder = 'properties',
  }) {
    return _send(
      'POST',
      Endpoints.uri(Endpoints.uploadPresign),
      body: {
        'filename': filename,
        'contentType': contentType,
        'folder': folder,
      },
    );
  }
}
