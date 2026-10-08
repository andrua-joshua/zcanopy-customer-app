import 'package:hive/hive.dart';

class ApiConfig {
  ApiConfig._();

  static const String kDefaultBaseUrl =
      'https://api-gateway-production-f9cc.up.railway.app/api';

  static String get baseUrl {
    try {
      final override = Hive.box('myStore').get('apiBaseUrl')?.toString();
      if (override != null && override.isNotEmpty) return override;
    } catch (_) {}
    return kDefaultBaseUrl;
  }

  static String? get sessionToken {
    try {
      return Hive.box('myStore').get('sessionID')?.toString();
    } catch (_) {
      return null;
    }
  }

  static Map<String, String> get headers {
    final token = sessionToken;
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) ...{
        'x-session-id': token,
        'Authorization': 'Bearer $token',
      },
    };
  }
}
