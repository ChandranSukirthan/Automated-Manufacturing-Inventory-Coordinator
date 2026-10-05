import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_flutter/services/session_storage.dart';
import 'package:mobile_flutter/models/auth_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const session = AuthSession(accessToken: 'test-access', refreshToken: 'test-refresh',
    user: UserSummary(id: '1', fullName: 'Worker', email: 'worker@example.test', role: 'FloorWorker'));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  test('session tokens are stored securely and cleared on logout', () async {
    final storage = SessionStorage();
    await storage.save(session);
    expect((await SharedPreferences.getInstance()).containsKey('auth_session'), false);
    expect((await storage.read())!.accessToken, session.accessToken);
    await storage.clear();
    expect(await storage.read(), null);
  });
  test('legacy tokens migrate into secure storage and plaintext is removed', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_session', jsonEncode({'accessToken': 'legacy-access',
      'refreshToken': 'legacy-refresh', 'user': {'id': '1', 'role': 'FloorWorker'}}));
    expect((await SessionStorage().read())!.accessToken, 'legacy-access');
    expect(prefs.containsKey('auth_session'), false);
    expect(await const FlutterSecureStorage().read(key: 'auth_session'), isNotNull);
  });
}
