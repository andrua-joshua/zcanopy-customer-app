import 'package:flutter/material.dart';
import 'package:zcanopy/pages/login.dart';
import 'package:zcanopy/services/auth_service.dart';

Future<bool> ensureSignedIn(BuildContext context) async {
  if (AuthService.instance.isSignedIn) return true;
  final result = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => const LoginPage()),
  );
  return result == true && AuthService.instance.isSignedIn;
}
