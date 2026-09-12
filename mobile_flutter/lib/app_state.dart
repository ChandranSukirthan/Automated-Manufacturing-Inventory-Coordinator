import 'package:flutter/foundation.dart';

import 'models/auth_models.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/session_storage.dart';

class AppState extends ChangeNotifier {
  AppState({required this.auth, required this.storage});

  final AuthService auth;
  final SessionStorage storage;

  AuthSession? session;
  bool isLoading = true;
  String? error;

  bool get isAuthenticated => session != null;

  Future<void> restore() async {
    session = await storage.read();
    isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      session = await auth.login(email.trim(), password);
      return true;
    } on ApiException catch (exception) {
      error = exception.message;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await auth.logout();
    session = null;
    notifyListeners();
  }

  Future<void> expireSession() async {
    await storage.clear();
    session = null;
    notifyListeners();
  }
}
