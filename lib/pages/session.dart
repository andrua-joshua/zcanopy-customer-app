import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/services/gateway_api.dart';

class SessionService {
  static String? getSessionID() {
    final box = Hive.box('myStore');
    return box.get('sessionID')?.toString();
  }

  static Future<bool> validateSession() async {
    final box = Hive.box('myStore');

    if (box.get('loginType') == 'google') return true;

    try {
      return await GatewayApi().validateSession();
    } catch (e) {
      debugPrint('Session validation error: $e');
      return false;
    }
  }
}
