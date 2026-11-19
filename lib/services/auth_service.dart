import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:zcanopy/services/gateway_api.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  factory AuthService() => instance;

  final GatewayApi _api = GatewayApi();

  Box get _store => Hive.box('myStore');

  String? get customerId => _store.get('customerId')?.toString();

  String? get email => _store.get('customerEmail')?.toString();

  String? get firstName => _store.get('customerFirstName')?.toString();

  String? get lastName => _store.get('customerLastName')?.toString();

  String? get phoneNumber => _store.get('customerPhone')?.toString();

  String get displayName {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    final mail = email?.trim() ?? '';
    if (mail.isNotEmpty) return mail.split('@').first;
    return 'Guest User';
  }

  bool get _flagSet => _store.get('isCustomerLoggedIn') == true;

  bool get isSignedIn {
    if (!_flagSet) return false;
    final token = _store.get('sessionID')?.toString();
    if (token == null || token.isEmpty) return false;
    final expiry = _jwtExpiry(token);
    if (expiry != null && expiry.isBefore(DateTime.now())) return false;
    return true;
  }

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    final data = await _api.loginCustomer(email: email, password: password);
    if (data['success'] != true) {
      throw ApiException(401, _message(data, 'Unable to sign in'));
    }
    await _applySession(data, data['customer']);
    return data;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    final data = await _api.registerCustomer(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
    );
    if (data['success'] != true) {
      throw ApiException(400, _message(data, 'Registration failed'));
    }
    return data;
  }

  Future<Map<String, dynamic>> confirmOtp({
    required String email,
    required String otpCode,
  }) async {
    final data = await _api.confirmCustomerOtp(email: email, otpCode: otpCode);
    if (data['success'] != true) {
      throw ApiException(400, _message(data, 'Invalid verification code'));
    }
    await _applySession(data, data['customer']);
    if (email.trim().isNotEmpty) {
      await _store.put('customerEmail', email.trim());
      await _store.put('email', email.trim());
    }
    await refreshProfile();
    return data;
  }

  Future<void> refreshProfile() async {
    if (!_flagSet) return;
    try {
      final profile = await _api.getCustomerProfile();
      await _storeProfile(profile);
    } catch (_) {}
  }

  Future<void> signOut() async {
    if (_flagSet) {
      try {
        await _api.logoutCustomer();
      } catch (_) {}
    }
    await _store.delete('isCustomerLoggedIn');
    await _store.delete('customerId');
    await _store.delete('customerEmail');
    await _store.delete('customerFirstName');
    await _store.delete('customerLastName');
    await _store.delete('customerPhone');
    await _store.delete('userID');
    await _store.delete('username');
    await _store.delete('email');
    await _store.delete('phoneNumber');
    await _store.delete('loginType');
    await _store.delete('sessionID');
    await _store.delete('sessionUuid');
    try {
      await Hive.box('notifications').delete('items');
    } catch (_) {}
    try {
      await _api.ensureCustomerSession(force: true);
    } catch (_) {}
  }

  Future<void> _applySession(
    Map<String, dynamic> data,
    Object? customer,
  ) async {
    final session = data['session'];
    final token = session is Map
        ? (session['sessionToken'] ?? session['token'])?.toString()
        : (data['sessionToken'] ?? data['token'])?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException(401, _message(data, 'Sign in failed'));
    }
    await _store.put('sessionID', token);
    await _store.put('isCustomerLoggedIn', true);
    if (customer is Map) {
      await _storeProfile(Map<String, dynamic>.from(customer));
    }
  }

  Future<void> _storeProfile(Map<String, dynamic> profile) async {
    final id = (profile['id'] ?? profile['customerId'])?.toString() ?? '';
    final mail = profile['email']?.toString() ?? '';
    final first = profile['firstName']?.toString() ?? '';
    final last = profile['lastName']?.toString() ?? '';
    final phone =
        (profile['phoneNumber'] ?? profile['phone'])?.toString() ?? '';

    if (id.isNotEmpty) {
      await _store.put('customerId', id);
      await _store.put('userID', id);
    }
    if (mail.isNotEmpty) {
      await _store.put('customerEmail', mail);
      await _store.put('email', mail);
    }
    if (first.isNotEmpty) await _store.put('customerFirstName', first);
    if (last.isNotEmpty) await _store.put('customerLastName', last);
    if (phone.isNotEmpty) {
      await _store.put('customerPhone', phone);
      await _store.put('phoneNumber', phone);
    }
    final name = '$first $last'.trim();
    if (name.isNotEmpty) await _store.put('username', name);
    await _store.put('loginType', 'email');
  }

  String _message(Map<String, dynamic> data, String fallback) {
    final value = data['message'];
    if (value == null) return fallback;
    if (value is List) return value.join(', ');
    return value.toString();
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
          (int.tryParse(exp) ?? 0) * 1000,
        );
      }
    } catch (_) {}
    return null;
  }
}
