import '../models/auth_models.dart';
import 'api_client.dart';
import 'session_storage.dart';

class AuthService {
  AuthService(this.api, this.storage);

  final ApiClient api;
  final SessionStorage storage;

  Future<String> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    final data = await api.post('/auth/register', {
      'fullName': fullName,
      'email': email,
      'password': password,
      'role': role,
    }) as Map<String, dynamic>;
    return data['message'] as String? ?? 'Registration successful.';
  }

  Future<String> verifyOtp({
    required String email,
    required String code,
  }) async {
    final data = await api.post('/auth/verify-otp', {
      'email': email,
      'code': code,
    }) as Map<String, dynamic>;
    return data['message'] as String? ?? 'Email verified successfully.';
  }

  Future<String> resendOtp(String email) async {
    final data = await api.post('/auth/resend-otp', {
      'email': email,
    }) as Map<String, dynamic>;
    return data['message'] as String? ?? 'A new code has been sent.';
  }

  Future<AuthSession> login(String email, String password) async {
    final data = await api.post('/auth/login', {
      'email': email,
      'password': password,
    });
    final session = AuthSession.fromJson(data as Map<String, dynamic>);
    await storage.save(session);
    return session;
  }

  Future<void> logout() => storage.clear();
}
