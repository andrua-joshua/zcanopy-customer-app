import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/pages/network.dart';

class SessionService {
  static const bool _devMockSession = true;

  static Future<bool> validateSession() async {
    if (_devMockSession) return true;

    final box = Hive.box('myStore');

    final userId = box.get('userID');
    final sessionId = box.get('sessionID');

    // Google/Firebase users are authenticated by Firebase rather than the
    // backend broker session system, so treat them as always valid.
    if (box.get('loginType') == 'google') return true;

    if (userId == null || sessionId == null) {
      print('No Session data found....');
      return false;
    }

    final payload = {'userId': userId, 'sessionId': sessionId};

    try {
      final response = await NetworkService.post(
        'http://127.0.0.1:4000/gate-way/validate-session',
        payload,
      );

      return response['success'] == true;
    } catch (e) {
      debugPrint('Session validation error: $e');
      return false;
    }
  }
}
