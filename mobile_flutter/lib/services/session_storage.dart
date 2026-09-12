import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_models.dart';

class SessionStorage {
  static const _sessionKey = 'auth_session';

  Future<void> save(AuthSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _sessionKey,
      jsonEncode({
        'accessToken': session.accessToken,
        'refreshToken': session.refreshToken,
        'user': {
          'id': session.user.id,
          'fullName': session.user.fullName,
          'email': session.user.email,
          'role': session.user.role,
        },
      }),
    );
  }

  Future<AuthSession?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_sessionKey);
    if (value == null) return null;
    try {
      return AuthSession.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
  }
}
