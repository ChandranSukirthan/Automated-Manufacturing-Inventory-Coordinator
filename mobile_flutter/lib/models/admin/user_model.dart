class UserModel {
  final String id;
  final String? employeeId;
  final String fullName;
  final String email;
  final String role;
  final int roleId;
  final bool isEmailVerified;
  final bool isActive;
  final DateTime createdAt;

  UserModel({
    required this.id,
    this.employeeId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.roleId,
    required this.isEmailVerified,
    required this.isActive,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    int rId = 0;
    String rName = 'FloorWorker';
    if (json['role'] is int) {
      rId = json['role'] as int;
      switch (rId) {
        case 0:
          rName = 'FloorWorker';
          break;
        case 1:
          rName = 'SupplyChainManager';
          break;
        case 2:
          rName = 'QualityInspector';
          break;
        case 3:
          rName = 'ITAdmin';
          break;
        default:
          rName = 'FloorWorker';
      }
    } else if (json['role'] != null) {
      rName = json['role'].toString();
      if (rName.toLowerCase().contains('supply') || rName == '1') {
        rId = 1;
      } else if (rName.toLowerCase().contains('quality') || rName == '2') {
        rId = 2;
      } else if (rName.toLowerCase().contains('admin') || rName == '3') {
        rId = 3;
      } else {
        rId = 0;
      }
    }

    return UserModel(
      id: json['id']?.toString() ?? '',
      employeeId: json['employeeId']?.toString(),
      fullName: json['fullName']?.toString() ?? 'Unnamed User',
      email: json['email']?.toString() ?? '',
      role: rName,
      roleId: rId,
      isEmailVerified: json['isEmailVerified'] == true,
      isActive: json['isActive'] != false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'fullName': fullName,
        'email': email,
        'role': roleId,
        'isEmailVerified': isEmailVerified,
        'isActive': isActive,
      };
}

