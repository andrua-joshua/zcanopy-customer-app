import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/pages/network.dart';
import 'package:zcanopy/services/cloudinary_service.dart';

/// Central API Service for all backend communications
/// This service wires up all Flutter app methods to the microservices backend
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final database = Hive.box('myStore');
  
  // Base URL for the gateway API
  static const String _baseUrl = 'http://127.0.0.1:4000';
  
  // Get session ID from local storage
  String? get _sessionID => database.get('sessionID');
  String? get _userID => database.get('userID');
  
  // Helper method to build URL with session
  String _buildUrl(String endpoint) {
    return '$_baseUrl$endpoint';
  }

  // ==================== CUSTOMER SESSION ====================

  /// Ensure an anonymous customer session exists.
  ///
  /// Customers never sign up or log in — they are tracked by a `sessionID`
  /// issued by the backend (auth service `IssueCustomerSession`). If one is
  /// already stored locally it is reused; otherwise a new one is requested and
  /// persisted to Hive under `sessionID`.
  Future<String?> ensureCustomerSession({String deviceId = ''}) async {
    final existing = _sessionID;
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    try {
      final response = await http.post(
        Uri.parse(_buildUrl('/customer/session')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deviceId': deviceId}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = (data['sessionToken'] ?? data['sessionId'])?.toString();
        if (token != null && token.isNotEmpty) {
          await database.put('sessionID', token);
          return token;
        }
      } else {
        print('Issue customer session failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Ensure customer session error: $e');
    }
    return null;
  }

  // ==================== AUTHENTICATION METHODS ====================

  /// Sign up a new user
  /// Backend: auth.signup (User Service)
  Future<Map<String, dynamic>> signup({
    required String email,
    required String username,
    required String password,
    String fromFirebase = '0',
    String photoURL = '',
    String phoneNumber = '',
    String accountType = '',
  }) async {
    try {
      final payload = {
        'email': email,
        'username': username,
        'password': password,
        'fromFirebase': fromFirebase,
        'photoURL': photoURL,
        'phoneNumber': phoneNumber,
        'accountType': accountType,
      };

      final response = await NetworkService.post(
        _buildUrl('/auth/signup'),
        payload,
      );
      return response;
    } catch (e) {
      print('Signup error: $e');
      rethrow;
    }
  }

  /// Login user
  /// Backend: auth.loginUser (User Service)
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    required String deviceId,
    String? fcmToken,
    String? oldFcmToken,
  }) async {
    try {
      final payload = {
        'username': username,
        'password': password,
        'deviceId': deviceId,
        if (fcmToken != null) 'fcmToken': fcmToken,
        if (oldFcmToken != null) 'oldFcmToken': oldFcmToken,
      };

      final response = await NetworkService.post(
        _buildUrl('/auth/login-to-account'),
        payload,
      );
      return response;
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  /// Set up a broker account from the signup flow
  /// Takes the broker code, a new password and the device id, updates the
  /// broker entity and returns a session that logs the broker straight in.
  /// Backend: auth.SetupBroker -> broker.SetupBrokerAccount
  Future<Map<String, dynamic>> setupBrokerAccount({
    required String brokerCode,
    required String password,
    required String deviceId,
  }) async {
    try {
      final payload = {
        'brokerCode': brokerCode,
        'password': password,
        'deviceId': deviceId,
      };

      final response = await NetworkService.post(
        _buildUrl('/auth/broker/setup'),
        payload,
      );
      return response;
    } catch (e) {
      print('Setup broker account error: $e');
      rethrow;
    }
  }

  /// Request email verification OTP
  /// Backend: auth.request-email-otp (User Service)
  Future<Map<String, dynamic>> requestEmailOTP({
    required String userId,
  }) async {
    try {
      final payload = {'userID': userId};
      final response = await NetworkService.post(
        _buildUrl('/gate-way/get-email-verification-code'),
        payload,
      );
      return response;
    } catch (e) {
      print('Request email OTP error: $e');
      rethrow;
    }
  }

  /// Verify email OTP
  /// Backend: auth.verifyEmailOtp (User Service)
  Future<Map<String, dynamic>> verifyEmailOTP({
    required String email,
    required String code,
    required String userId,
  }) async {
    try {
      final payload = {
        'email': email,
        'code': code,
        'userID': userId,
      };
      final response = await NetworkService.post(
        _buildUrl('/gate-way/verify-email-otp'),
        payload,
      );
      return response;
    } catch (e) {
      print('Verify email OTP error: $e');
      rethrow;
    }
  }

  /// Request phone verification OTP
  /// Backend: auth.verify-phone-otp (User Service)
  Future<Map<String, dynamic>> requestPhoneOTP({
    required String userId,
  }) async {
    try {
      final payload = {'userID': userId};
      final response = await NetworkService.post(
        _buildUrl('/auth/get-phone-verification-code'),
        payload,
      );
      return response;
    } catch (e) {
      print('Request phone OTP error: $e');
      rethrow;
    }
  }

  /// Verify phone OTP
  /// Backend: auth.verify-phone-otp (User Service)
  Future<Map<String, dynamic>> verifyPhoneOTP({
    required String verificationID,
    required String userId,
    required String code,
  }) async {
    try {
      final payload = {
        'verificationID': verificationID,
        'userID': userId,
        'code': code,
      };
      final response = await NetworkService.post(
        _buildUrl('/gate-way/verify-phone-otp'),
        payload,
      );
      return response;
    } catch (e) {
      print('Verify phone OTP error: $e');
      rethrow;
    }
  }

  /// Resend phone OTP
  Future<Map<String, dynamic>> resendPhoneOTP({
    required String verificationID,
    required String userId,
  }) async {
    try {
      final payload = {
        'verificationID': verificationID,
        'userID': userId,
      };
      final response = await NetworkService.post(
        _buildUrl('/gate-way/resend-phone-otp'),
        payload,
      );
      return response;
    } catch (e) {
      print('Resend phone OTP error: $e');
      rethrow;
    }
  }

  /// Check session validity
  Future<Map<String, dynamic>> checkSessionValidity({
    required String userId,
    required String sessionId,
  }) async {
    try {
      final payload = {
        'userID': userId,
        'sessionID': sessionId,
      };
      final response = await NetworkService.post(
        _buildUrl('/gate-way/check-session-id-validity'),
        payload,
      );
      return response;
    } catch (e) {
      print('Check session validity error: $e');
      rethrow;
    }
  }

  /// Update account type
  /// Backend: auth.update-account-type (User Service)
  Future<Map<String, dynamic>> updateAccountType({
    required String userId,
    required String accountType,
    String? phoneNumber,
  }) async {
    try {
      final payload = {
        'userId': userId,
        'accountType': accountType,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
      };
      final response = await NetworkService.post(
        _buildUrl('/auth/update-account-type'),
        payload,
      );
      return response;
    } catch (e) {
      print('Update account type error: $e');
      rethrow;
    }
  }

  /// Request password reset OTP
  /// Backend: users.request-reset-password-otp (User Service)
  Future<Map<String, dynamic>> requestPasswordResetOTP({
    required String email,
  }) async {
    try {
      final payload = {'email': email};
      final response = await NetworkService.post(
        _buildUrl('/users/request-reset-password-otp'),
        payload,
      );
      return response;
    } catch (e) {
      print('Request password reset OTP error: $e');
      rethrow;
    }
  }

  /// Request account deletion OTP
  /// Backend: users.request-account-deletion-otp (User Service)
  Future<Map<String, dynamic>> requestAccountDeletionOTP({
    required String userId,
    String? email,
    String? phoneNumber,
  }) async {
    try {
      final payload = {
        'userId': userId,
        if (email != null) 'email': email,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
      };
      final response = await NetworkService.post(
        _buildUrl('/users/request-account-deletion-otp'),
        payload,
      );
      return response;
    } catch (e) {
      print('Request account deletion OTP error: $e');
      rethrow;
    }
  }

  // ==================== USER PROFILE METHODS ====================

  /// Get user by ID
  /// Backend: users.get-user-by-id (User Service)
  Future<Map<String, dynamic>> getUserById(String userId) async {
    try {
      final response = await NetworkService.get(
        _buildUrl('/users/get-user-by-id?id=$userId'),
      );
      return response;
    } catch (e) {
      print('Get user by ID error: $e');
      rethrow;
    }
  }

  /// Get user by email
  /// Backend: users.get-user-by-email (User Service)
  Future<Map<String, dynamic>> getUserByEmail(String email) async {
    try {
      final response = await NetworkService.get(
        _buildUrl('/users/get-user-by-email?email=$email'),
      );
      return response;
    } catch (e) {
      print('Get user by email error: $e');
      rethrow;
    }
  }

  /// Get user by username
  /// Backend: users.get-user-by-username (User Service)
  Future<Map<String, dynamic>> getUserByUsername(String username) async {
    try {
      final response = await NetworkService.get(
        _buildUrl('/users/get-user-by-username?username=$username'),
      );
      return response;
    } catch (e) {
      print('Get user by username error: $e');
      rethrow;
    }
  }

  /// Save user info
  /// Backend: users.save-user-info (User Service)
  Future<Map<String, dynamic>> saveUserInfo({
    required String userId,
    String? username,
    String? email,
    String? phoneNumber,
    String? photoURL,
    String? accountType,
    String? subscriptionPackage,
  }) async {
    try {
      final payload = {
        'userId': userId,
        if (username != null) 'username': username,
        if (email != null) 'email': email,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (photoURL != null) 'photoURL': photoURL,
        if (accountType != null) 'accountType': accountType,
        if (subscriptionPackage != null) 'subscriptionPackage': subscriptionPackage,
      };
      final response = await NetworkService.post(
        _buildUrl('/users/save-user-info'),
        payload,
      );
      return response;
    } catch (e) {
      print('Save user info error: $e');
      rethrow;
    }
  }

  /// Update user field
  /// Backend: users.update-user-field (User Service)
  Future<Map<String, dynamic>> updateUserField({
    required String id,
    required Map<String, dynamic> fields,
  }) async {
    try {
      final payload = {'id': id, ...fields};
      final response = await NetworkService.post(
        _buildUrl('/users/update-user-field'),
        payload,
      );
      return response;
    } catch (e) {
      print('Update user field error: $e');
      rethrow;
    }
  }

  /// Get user subscription details
  /// Backend: users.get-subscription-details (User Service)
  Future<Map<String, dynamic>> getUserSubscriptionDetails(String userId) async {
    try {
      final payload = {'userId': userId};
      final response = await NetworkService.post(
        _buildUrl('/users/get-subscription-details'),
        payload,
      );
      return response;
    } catch (e) {
      print('Get subscription details error: $e');
      rethrow;
    }
  }

  /// Delete user account
  /// Backend: users.delete-by-id (User Service)
  Future<Map<String, dynamic>> deleteUserAccount(String userId) async {
    try {
      final response = await NetworkService.post(
        _buildUrl('/users/delete-by-id'),
        {'id': userId},
      );
      return response;
    } catch (e) {
      print('Delete user account error: $e');
      rethrow;
    }
  }

  /// Logout user
  Future<Map<String, dynamic>> logout(String userId) async {
    try {
      final response = await NetworkService.post(
        _buildUrl('/users/logout-user'),
        {'userID': userId},
      );
      return response;
    } catch (e) {
      print('Logout error: $e');
      rethrow;
    }
  }

  // ==================== PROPERTY/LISTING METHODS ====================

  /// Get all properties for a user
  Future<Map<String, dynamic>> getProperties({
    required String userId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await NetworkService.get(
        _buildUrl('/listings/get_properties?user_id=$userId&page=$page&limit=$limit'),
      );
      return response;
    } catch (e) {
      print('Get properties error: $e');
      rethrow;
    }
  }

  /// Get property by ID
  Future<Map<String, dynamic>> getPropertyById(String propertyId) async {
    try {
      final response = await NetworkService.get(
        _buildUrl('/listings/get_property_by_id?id=$propertyId'),
      );
      return response;
    } catch (e) {
      print('Get property by ID error: $e');
      rethrow;
    }
  }

  /// Create new property listing.
  /// Backend: property.CreateProperty (Property Service)
  /// Required by the backend: brokersUniqueCode (userID). All other fields are
  /// optional but we send the full property payload including the
  /// Google-resolved subCounty/district pair.
  Future<Map<String, dynamic>> createProperty({
    required String userId,
    required String title,
    required String description,
    required String propertyType,
    required String location,
    required double lat,
    required double lng,
    required List<String> imageUrl,
    String? videoUrl,
    String? subCounty,
    String? district,
  }) async {
    try {
      final payload = {
        'brokersUniqueCode': userId,
        'title': title,
        'description': description,
        'propertyType': propertyType,
        'location': location,
        'lat': lat,
        'lng': lng,
        'imageUrl': imageUrl,
        if (videoUrl != null) 'videoUrl': videoUrl,
        'subCounty': subCounty ?? '',
        'district': district ?? '',
      };
      final response = await NetworkService.post(
        _buildUrl('/properties'),
        payload,
      );
      return response;
    } catch (e) {
      print('Create property error: $e');
      rethrow;
    }
  }

  /// Update property
  Future<Map<String, dynamic>> updateProperty({
    required String propertyId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final response = await NetworkService.post(
        _buildUrl('/properties/$propertyId'),
        updates,
      );
      return response;
    } catch (e) {
      print('Update property error: $e');
      rethrow;
    }
  }

  /// Delete property
  Future<Map<String, dynamic>> deleteProperty(String propertyId) async {
    try {
      final response = await NetworkService.post(
        _buildUrl('/properties/$propertyId/delete'),
        {},
      );
      return response;
    } catch (e) {
      print('Delete property error: $e');
      rethrow;
    }
  }

  /// Get property clients
  Future<Map<String, dynamic>> getPropertyClients(String propertyId) async {
    try {
      final response = await NetworkService.get(
        _buildUrl('/listings/get_property_clients?property_id=$propertyId'),
      );
      return response;
    } catch (e) {
      print('Get property clients error: $e');
      rethrow;
    }
  }

  // ==================== BOOKING METHODS ====================

  /// Get user bookings
  Future<Map<String, dynamic>> getBookings({
    required String userId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await NetworkService.get(
        _buildUrl('/bookings/get_bookings?user_id=$userId&page=$page&limit=$limit'),
      );
      return response;
    } catch (e) {
      print('Get bookings error: $e');
      rethrow;
    }
  }

  /// Create booking
  Future<Map<String, dynamic>> createBooking({
    required String userId,
    required String propertyId,
    required String date,
    String? phone,
    String? notes,
  }) async {
    try {
      final payload = {
        'userId': userId,
        'propertyId': propertyId,
        'date': date,
        if (phone != null) 'phone': phone,
        if (notes != null) 'notes': notes,
      };
      final response = await NetworkService.post(
        _buildUrl('/bookings/create_booking'),
        payload,
      );
      return response;
    } catch (e) {
      print('Create booking error: $e');
      rethrow;
    }
  }

  /// Update booking status
  Future<Map<String, dynamic>> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    try {
      final payload = {
        'bookingId': bookingId,
        'status': status,
      };
      final response = await NetworkService.post(
        _buildUrl('/bookings/update_booking_status'),
        payload,
      );
      return response;
    } catch (e) {
      print('Update booking status error: $e');
      rethrow;
    }
  }

  /// Cancel booking
  Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    try {
      final response = await NetworkService.post(
        _buildUrl('/bookings/cancel_booking'),
        {'bookingId': bookingId},
      );
      return response;
    } catch (e) {
      print('Cancel booking error: $e');
      rethrow;
    }
  }

  // ==================== PAYMENT METHODS ====================

  /// Get payment access token
  /// Backend: payment.access-token (Payment Service)
  Future<Map<String, dynamic>> getPaymentAccessToken() async {
    try {
      final response = await NetworkService.get(
        _buildUrl('/payment/access-token'),
      );
      return response;
    } catch (e) {
      print('Get payment access token error: $e');
      rethrow;
    }
  }

  /// Initiate mobile money payment
  /// Backend: payment.mobile-money-initiate-payment (Payment Service)
  Future<Map<String, dynamic>> initiateMobileMoneyPayment({
    required String phoneNumber,
    required String amount,
    required String userId,
  }) async {
    try {
      final payload = {
        'phoneNumber': phoneNumber,
        'amount': amount,
        'userId': userId,
      };
      final response = await NetworkService.post(
        _buildUrl('/payment/initiate_payment'),
        payload,
      );
      return response;
    } catch (e) {
      print('Initiate mobile money payment error: $e');
      rethrow;
    }
  }

  /// Get payment status
  /// Backend: payment.get-payment-status (Payment Service)
  Future<Map<String, dynamic>> getPaymentStatus(String transactionId) async {
    try {
      final response = await NetworkService.get(
        _buildUrl('/payment/get_payment_status?transaction_id=$transactionId'),
      );
      return response;
    } catch (e) {
      print('Get payment status error: $e');
      rethrow;
    }
  }

  /// Get transaction records
  Future<Map<String, dynamic>> getTransactionRecords({
    required String userId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await NetworkService.get(
        _buildUrl('/payment/get_transaction_records?user_id=$userId&page=$page&limit=$limit'),
      );
      return response;
    } catch (e) {
      print('Get transaction records error: $e');
      rethrow;
    }
  }

  // ==================== FAVORITE METHODS ====================

  /// Get user favorites
  Future<Map<String, dynamic>> getFavorites({
    required String userId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await NetworkService.get(
        _buildUrl('/users/get-favourites?id=$userId&page=$page&limit=$limit'),
      );
      return response;
    } catch (e) {
      print('Get favorites error: $e');
      rethrow;
    }
  }

  /// Add to favorites
  Future<Map<String, dynamic>> addToFavorites({
    required String userId,
    required String propertyId,
  }) async {
    try {
      final payload = {
        'userId': userId,
        'propertyId': propertyId,
      };
      final response = await NetworkService.post(
        _buildUrl('/users/add-favourite'),
        payload,
      );
      return response;
    } catch (e) {
      print('Add to favorites error: $e');
      rethrow;
    }
  }

  /// Remove from favorites
  Future<Map<String, dynamic>> removeFromFavorites({
    required String userId,
    required String propertyId,
  }) async {
    try {
      final payload = {
        'userId': userId,
        'propertyId': propertyId,
      };
      final response = await NetworkService.post(
        _buildUrl('/users/remove-favourite'),
        payload,
      );
      return response;
    } catch (e) {
      print('Remove from favorites error: $e');
      rethrow;
    }
  }

  // ==================== NOTIFICATION METHODS ====================

  /// Get notifications
  Future<Map<String, dynamic>> getNotifications({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await NetworkService.get(
        _buildUrl('/notifications/get_notifications?user_id=$userId&page=$page&limit=$limit'),
      );
      return response;
    } catch (e) {
      print('Get notifications error: $e');
      rethrow;
    }
  }

  /// Mark notification as read
  Future<Map<String, dynamic>> markNotificationAsRead(String notificationId) async {
    try {
      final response = await NetworkService.post(
        _buildUrl('/notifications/mark_as_read'),
        {'notificationId': notificationId},
      );
      return response;
    } catch (e) {
      print('Mark notification as read error: $e');
      rethrow;
    }
  }

  /// Update FCM token
  Future<Map<String, dynamic>> updateFCMToken({
    required String userId,
    required String fcmToken,
  }) async {
    try {
      final payload = {
        'userId': userId,
        'fcmToken': fcmToken,
      };
      final response = await NetworkService.post(
        _buildUrl('/users/update_fcm_token'),
        payload,
      );
      return response;
    } catch (e) {
      print('Update FCM token error: $e');
      rethrow;
    }
  }

  // ==================== LOCATION METHODS ====================

  /// Get current location string from coordinates
  Future<Map<String, dynamic>> getCurrentLocation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await NetworkService.get(
        _buildUrl('/gate-way/get-current-location?lat=$latitude&longitude=$longitude'),
      );
      return response;
    } catch (e) {
      print('Get current location error: $e');
      rethrow;
    }
  }

  // ==================== SEARCH/EXPLORER METHODS ====================

  /// Search properties
  Future<Map<String, dynamic>> searchProperties({
    required String query,
    String? location,
    double? minPrice,
    double? maxPrice,
    int? bedrooms,
    int? bathrooms,
    String? propertyType,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      String url = _buildUrl('/listings/search?query=$query&page=$page&limit=$limit');
      if (location != null) url += '&location=$location';
      if (minPrice != null) url += '&minPrice=$minPrice';
      if (maxPrice != null) url += '&maxPrice=$maxPrice';
      if (bedrooms != null) url += '&bedrooms=$bedrooms';
      if (bathrooms != null) url += '&bathrooms=$bathrooms';
      if (propertyType != null) url += '&propertyType=$propertyType';

      final response = await NetworkService.get(url);
      return response;
    } catch (e) {
      print('Search properties error: $e');
      rethrow;
    }
  }

  /// Get nearby properties
  Future<Map<String, dynamic>> getNearbyProperties({
    required double latitude,
    required double longitude,
    double radius = 10,
    int limit = 20,
  }) async {
    try {
      final response = await NetworkService.get(
        _buildUrl('/listings/nearby?lat=$latitude&longitude=$longitude&radius=$radius&limit=$limit'),
      );
      return response;
    } catch (e) {
      print('Get nearby properties error: $e');
      rethrow;
    }
  }

  /// Get customer properties with pagination
  Future<Map<String, dynamic>> getCustomerProperties({
    required String sessionToken,
    double? latitude,
    double? longitude,
    double radiusKm = 10,
    int page = 1,
    int limit = 10,
    String? propertyType,
  }) async {
    try {
      String url = '/customer/properties?sessionToken=$sessionToken&page=$page&limit=$limit';
      if (latitude != null) url += '&lat=$latitude';
      if (longitude != null) url += '&lng=$longitude';
      url += '&radiusKm=$radiusKm';
      if (propertyType != null) url += '&propertyType=$propertyType';

      final response = await NetworkService.get(_buildUrl(url));
      return response;
    } catch (e) {
      print('Get customer properties error: $e');
      rethrow;
    }
  }

  /// Initiate property access payment
  /// Backend: property.CreateCustomerBooking (Property Service)
  Future<Map<String, dynamic>> initiatePropertyAccessPayment({
    required String sessionToken,
    required String propertyId,
    required double amount,
    String? customerEmail,
    String? customerPhone,
    String? customerName,
    String? date,
    String? reason,
    String? status,
  }) async {
    try {
      final payload = {
        'sessionToken': sessionToken,
        'propertyId': propertyId,
        'amount': amount,
        if (customerEmail != null) 'customerEmail': customerEmail,
        if (customerPhone != null) 'customerPhone': customerPhone,
        if (customerName != null) 'customerName': customerName,
        if (date != null) 'date': date,
        if (reason != null) 'reason': reason,
        if (status != null) 'status': status,
      };

      final response = await NetworkService.post(
        _buildUrl('/customer/properties/access-payment'),
        payload,
      );
      return response;
    } catch (e) {
      print('Initiate property access payment error: $e');
      rethrow;
    }
  }

  /// Get broker properties for customer
  Future<Map<String, dynamic>> getBrokerPropertiesForCustomer({
    required String sessionToken,
    required String brokerCode,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await NetworkService.get(
        _buildUrl('/customer/broker-properties?sessionToken=$sessionToken&brokerCode=$brokerCode&page=$page&limit=$limit'),
      );
      return response;
    } catch (e) {
      print('Get broker properties for customer error: $e');
      rethrow;
    }
  }

  /// Create customer booking
  Future<Map<String, dynamic>> createCustomerBooking({
    required String sessionToken,
    required String propertyId,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    required String date,
    required double amount,
    String? reason,
    String? status,
  }) async {
    try {
      final payload = {
        'sessionToken': sessionToken,
        'propertyId': propertyId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        if (customerEmail != null) 'customerEmail': customerEmail,
        'date': date,
        'amount': amount,
        if (reason != null) 'reason': reason,
        if (status != null) 'status': status,
      };

      final response = await NetworkService.post(
        _buildUrl('/customer/bookings'),
        payload,
      );
      return response;
    } catch (e) {
      print('Create customer booking error: $e');
      rethrow;
    }
  }

  /// Get property details for customer
  Future<Map<String, dynamic>> getPropertyDetailsForCustomer({
    required String sessionToken,
    required String propertyId,
  }) async {
    try {
      final response = await NetworkService.get(
        _buildUrl('/customer/properties/${propertyId}/details?sessionToken=$sessionToken'),
      );
      return response;
    } catch (e) {
      print('Get property details for customer error: $e');
      rethrow;
    }
  }

  /// Retrieve a customer's bookings using the unique code issued after a
  /// successful payment for an item, plus the customer's phone number.
  /// Backend: customer.bookings (retrieval by code + phone)
  Future<Map<String, dynamic>> getCustomerBookingsByCode({
    required String code,
    required String phoneNumber,
  }) async {
    try {
      final payload = {
        'code': code,
        'phoneNumber': phoneNumber,
      };
      final response = await NetworkService.post(
        _buildUrl('/customer/bookings/retrieve'),
        payload,
      );
      return response;
    } catch (e) {
      print('Get customer bookings by code error: $e');
      rethrow;
    }
  }

  /// Retrieve a customer's previous payments using the unique code issued
  /// after a successful payment, plus the customer's phone number.
  /// Backend: customer.payments (retrieval by code + phone)
  Future<Map<String, dynamic>> getCustomerPaymentsByCode({
    required String code,
    required String phoneNumber,
  }) async {
    try {
      final payload = {
        'code': code,
        'phoneNumber': phoneNumber,
      };
      final response = await NetworkService.post(
        _buildUrl('/customer/payments/retrieve'),
        payload,
      );
      return response;
    } catch (e) {
      print('Get customer payments by code error: $e');
      rethrow;
    }
  }

  // ==================== SUBSCRIPTION METHODS ====================

  /// Get the current broker's details (active tier + expiry)
  /// Backend: brokers.GetBrokerById (Broker Service)
  Future<Map<String, dynamic>> getBroker(String brokerId) async {
    try {
      final response = await NetworkService.get(
        _buildUrl('/brokers/$brokerId'),
      );
      return response;
    } catch (e) {
      print('Get broker error: $e');
      rethrow;
    }
  }

  /// Get subscription packages
  Future<Map<String, dynamic>> getSubscriptionPackages() async {
    try {
      final response = await NetworkService.get(
        _buildUrl('/subscriptions/get_packages'),
      );
      return response;
    } catch (e) {
      print('Get subscription packages error: $e');
      rethrow;
    }
  }

  /// Subscribe the broker to a tier via mobile money.
  /// Backend: brokers.ProcessSubscriptionPayment (Broker Service)
  Future<Map<String, dynamic>> subscribeToPackage({
    required String userId,
    required String packageId,
    required String paymentMethod,
    String? phoneNumber,
  }) async {
    try {
      final payload = {
        'tier': packageId,
        'phoneNumber': phoneNumber,
        'paymentMethod': paymentMethod,
      };
      final response = await NetworkService.post(
        _buildUrl('/brokers/$userId/subscribe'),
        payload,
      );
      return response;
    } catch (e) {
      print('Subscribe to package error: $e');
      rethrow;
    }
  }

  /// Cancel subscription
  Future<Map<String, dynamic>> cancelSubscription(String userId) async {
    try {
      final response = await NetworkService.post(
        _buildUrl('/subscriptions/cancel'),
        {'userId': userId},
      );
      return response;
    } catch (e) {
      print('Cancel subscription error: $e');
      rethrow;
    }
  }

  /// Get the broker dashboard (broker-code, tier, wallet balance, phone,
  /// minimum withdrawal, messages and bookings).
  /// Backend: brokers.GetBrokerDashboard (Broker Service)
  Future<Map<String, dynamic>> getBrokerDashboard({
    required String brokerId,
  }) async {
    try {
      final response = await NetworkService.get(
        _buildUrl('/brokers/dashboard/$brokerId'),
      );
      return response;
    } catch (e) {
      print('Get broker dashboard error: $e');
      rethrow;
    }
  }

  /// Log the broker out and revoke the active session.
  /// Backend: brokers.LogoutBroker (Broker Service)
  Future<Map<String, dynamic>> logoutBroker({
    required String brokerCode,
    String? sessionId,
  }) async {
    try {
      final payload = {
        'brokerCode': brokerCode,
        if (sessionId != null) 'sessionId': sessionId,
      };
      final response = await NetworkService.post(
        _buildUrl('/brokers/logout-user'),
        payload,
      );
      return response;
    } catch (e) {
      print('Logout broker error: $e');
      rethrow;
    }
  }

  /// Deactivate (unsubscribe) the broker account.
  /// Backend: brokers.UnsubscribeBroker (Broker Service)
  Future<Map<String, dynamic>> unsubscribeBroker({
    required String brokerCode,
    String? password,
    String? googleId,
    String? sessionId,
  }) async {
    try {
      final payload = {
        'brokerCode': brokerCode,
        if (password != null) 'password': password,
        if (googleId != null) 'googleId': googleId,
        if (sessionId != null) 'sessionId': sessionId,
      };
      final response = await NetworkService.post(
        _buildUrl('/brokers/unsubscribe-user'),
        payload,
      );
      return response;
    } catch (e) {
      print('Unsubscribe broker error: $e');
      rethrow;
    }
  }

  /// Submit broker feedback.
  /// Backend: brokers.SubmitBrokerFeedback (Broker Service)
  Future<Map<String, dynamic>> submitBrokerFeedback({
    required String brokerCode,
    required String email,
    required String phone,
    required String content,
  }) async {
    try {
      final payload = {
        'brokerCode': brokerCode,
        'email': email,
        'phone': phone,
        'content': content,
      };
      final response = await NetworkService.post(
        _buildUrl('/brokers/feedback/submit'),
        payload,
      );
      return response;
    } catch (e) {
      print('Submit broker feedback error: $e');
      rethrow;
    }
  }

  /// Withdraw funds from the broker wallet to mobile money.
  /// Backend: brokers.Withdraw (Broker Service)
  Future<Map<String, dynamic>> withdrawBroker({
    required double amount,
    required String phoneNumber,
    required String provider,
    String? payeeName,
  }) async {
    try {
      final payload = {
        'amount': amount,
        'phoneNumber': phoneNumber,
        'provider': provider,
        if (payeeName != null) 'payeeName': payeeName,
      };
      final response = await NetworkService.post(
        _buildUrl('/brokers/withdraw'),
        payload,
      );
      return response;
    } catch (e) {
      print('Withdraw broker error: $e');
      rethrow;
    }
  }

  // ==================== HELPER METHODS ====================

  /// Check if user is logged in
  bool get isLoggedIn => _userID != null && _sessionID != null;

  /// Get current user ID
  String? get currentUserId => _userID;

  /// Get current session ID
  String? get currentSessionId => _sessionID;

  /// Clear local session
  Future<void> clearSession() async {
    await database.clear();
  }
}
