import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_models.dart';
import 'session_storage.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required this.storage, String? baseUrl, this.onSessionExpired})
    : baseUrl =
          (baseUrl ??
                  const String.fromEnvironment(
                    'API_BASE_URL',
                    defaultValue: 'http://10.0.2.2:5070/api',
                  ))
              .replaceAll(RegExp(r'/$'), '');

  final SessionStorage storage;
  final String baseUrl;
  Future<void> Function()? onSessionExpired;

  Future<dynamic> get(String path) => _request('GET', path);
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _request('POST', path, body);
  Future<dynamic> put(String path, Map<String, dynamic> body) =>
      _request('PUT', path, body);
  Future<dynamic> delete(String path) => _request('DELETE', path);

  Future<dynamic> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
    bool retry = true,
  ]) async {
    final session = await storage.read();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (session != null && session.accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }

    final uri = Uri.parse('$baseUrl$path');
    final encodedBody = body == null ? null : jsonEncode(body);
    http.Response response;
    try {
      response = switch (method) {
        'GET' => await http.get(uri, headers: headers),
        'POST' => await http.post(uri, headers: headers, body: encodedBody),
        'PUT' => await http.put(uri, headers: headers, body: encodedBody),
        'DELETE' => await http.delete(uri, headers: headers),
        _ => throw const ApiException('Unsupported request method.'),
      };
    } catch (_) {
      throw const ApiException(
        'Could not connect to the server. Check the API URL and network.',
      );
    }

    if (response.statusCode == 401 && retry && session != null) {
      final refreshed = await _refresh(session.refreshToken);
      if (refreshed) return _request(method, path, body, false);
      await onSessionExpired?.call();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_message(response), statusCode: response.statusCode);
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  Future<bool> _refresh(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await storage.clear();
        return false;
      }
      final oldSession = await storage.read();
      if (oldSession == null) return false;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await storage.save(
        AuthSession.fromJson({
          ...data,
          'user': {
            'id': oldSession.user.id,
            'fullName': oldSession.user.fullName,
            'email': oldSession.user.email,
            'role': oldSession.user.role,
          },
        }),
      );
      return true;
    } catch (_) {
      await storage.clear();
      return false;
    }
  }

  String _message(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final message = data['message'] as String?;
      if (message != null && message.isNotEmpty) return message;

      final errors = data['errors'];
      if (errors is Map<String, dynamic>) {
        final details = errors.values
            .expand((value) => value is List ? value : [value])
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .toList();
        if (details.isNotEmpty) return details.join('\n');
      }

      return data['title'] as String? ?? 'The request could not be completed.';
    } catch (_) {
      return 'The request could not be completed (${response.statusCode}).';
    }
  }
}
