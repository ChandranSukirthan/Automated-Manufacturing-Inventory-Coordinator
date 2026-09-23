import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_models.dart';

class SessionStorage {
  static const _sessionKey = 'auth_session';
  static const _ownedRollsKey = 'owned_rolls_by_user';
  static const _ownedItemsKey = 'owned_items_by_user';
  static const _ownedAlertsKey = 'owned_alerts_by_user';

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

  Future<List<String>> readOwnedRollIds(String email) async {
    final preferences = await SharedPreferences.getInstance();
    final data = preferences.getStringList('$_ownedRollsKey:$email');
    return data ?? <String>[];
  }

  Future<void> addOwnedRollId(String email, String rollId) async {
    final preferences = await SharedPreferences.getInstance();
    final key = '$_ownedRollsKey:$email';
    final ids = preferences.getStringList(key) ?? <String>[];
    if (!ids.contains(rollId)) {
      ids.add(rollId);
      await preferences.setStringList(key, ids);
    }
  }

  Future<List<String>> readOwnedItemIds(String email) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList('$_ownedItemsKey:$email') ?? <String>[];
  }

  Future<void> addOwnedItemId(String email, int itemId) async {
    final preferences = await SharedPreferences.getInstance();
    final key = '$_ownedItemsKey:$email';
    final ids = preferences.getStringList(key) ?? <String>[];
    final value = '$itemId';
    if (!ids.contains(value)) {
      ids.add(value);
      await preferences.setStringList(key, ids);
    }
  }

  Future<List<String>> readOwnedAlertIds(String email) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList('$_ownedAlertsKey:$email') ?? <String>[];
  }

  Future<void> addOwnedAlertId(String email, int alertId) async {
    final preferences = await SharedPreferences.getInstance();
    final key = '$_ownedAlertsKey:$email';
    final ids = preferences.getStringList(key) ?? <String>[];
    final value = '$alertId';
    if (!ids.contains(value)) {
      ids.add(value);
      await preferences.setStringList(key, ids);
    }
  }
}
