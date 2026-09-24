import 'dart:typed_data';

class UserProfile {
  final String fullName;
  final String username;
  final String employeeId;
  final String role;
  final bool isOnline;
  final DateTime? lastLoginAt;
  final DateTime? lastLogoutAt;
  final Uint8List? profileImageBytes;

  const UserProfile({
    required this.fullName,
    required this.username,
    required this.employeeId,
    required this.role,
    this.isOnline = false,
    this.lastLoginAt,
    this.lastLogoutAt,
    this.profileImageBytes,
  });

  String get initials {
    final names = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((name) => name.isNotEmpty)
        .toList();
    return names.take(2).map((name) => name[0].toUpperCase()).join();
  }

  bool get isFloorWorker => role == 'Factory / Floor Worker';
  bool get isAdmin => role == 'IT / System Admin';
  bool get isManager => role == 'Supply Chain Manager';
  bool get canViewManagerDashboard => isAdmin || isManager;
  bool get canApproveFinancialActions => isAdmin || isManager;

  UserProfile copyWith({
    String? fullName,
    String? username,
    String? employeeId,
    String? role,
    bool? isOnline,
    DateTime? lastLoginAt,
    DateTime? lastLogoutAt,
    Uint8List? profileImageBytes,
    bool removeProfileImage = false,
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      employeeId: employeeId ?? this.employeeId,
      role: role ?? this.role,
      isOnline: isOnline ?? this.isOnline,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastLogoutAt: lastLogoutAt ?? this.lastLogoutAt,
      profileImageBytes: removeProfileImage
          ? null
          : profileImageBytes ?? this.profileImageBytes,
    );
  }
}
