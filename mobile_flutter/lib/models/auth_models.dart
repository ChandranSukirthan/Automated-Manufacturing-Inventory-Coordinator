class UserSummary {
  const UserSummary({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });

  final String id;
  final String fullName;
  final String email;
  final String role;

  bool get isQualityInspector => role == 'QualityInspector';

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
    id: json['id']?.toString() ?? '',
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: _normalizeRole(json['role']),
  );

  static String _normalizeRole(dynamic value) {
    final normalized = value.toString().toLowerCase().replaceAll(
      RegExp(r'[\s_-]'),
      '',
    );

    return switch (normalized) {
      '0' || 'floorworker' => 'FloorWorker',
      '1' || 'supplychainmanager' => 'SupplyChainManager',
      '2' || 'qualityinspector' => 'QualityInspector',
      '3' || 'itadmin' => 'ITAdmin',
      _ => value is String ? value : '',
    };
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final UserSummary user;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    accessToken: json['accessToken'] as String? ?? '',
    refreshToken: json['refreshToken'] as String? ?? '',
    user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
  );
}
