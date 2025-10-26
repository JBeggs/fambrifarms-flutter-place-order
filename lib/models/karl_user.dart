class KarlUser {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String department;
  final String position;
  final List<String> permissions;
  final DateTime? lastLogin;
  final bool isActive;

  const KarlUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.department,
    required this.position,
    required this.permissions,
    this.lastLogin,
    this.isActive = true,
  });

  factory KarlUser.fromJson(Map<String, dynamic> json) {
    return KarlUser(
      id: json['id'] ?? 0,
      name: json['name'] ?? json['first_name'] ?? 'Karl',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['user_type'] ?? json['role'] ?? 'farm_manager',
      department: json['department'] ?? 'Farm Operations',
      position: json['position'] ?? 'Farm Manager',
      permissions: List<String>.from(json['permissions'] ?? ['ALL']),
      lastLogin: json['last_login'] != null 
          ? DateTime.parse(json['last_login']) 
          : null,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'department': department,
      'position': position,
      'permissions': permissions,
      'last_login': lastLogin?.toIso8601String(),
      'is_active': isActive,
    };
  }

  // Karl's specific properties
  bool get isFarmManager => role == 'farm_manager';
  bool get hasFullAccess => permissions.contains('ALL') || permissions.length > 5;
  
  String get displayName => name.isNotEmpty ? name : 'Karl';
  String get initials => name.isNotEmpty 
      ? name.split(' ').map((n) => n[0]).take(2).join().toUpperCase()
      : 'K';

  @override
  String toString() => 'KarlUser(name: $name, email: $email, role: $role)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KarlUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email;

  @override
  int get hashCode => id.hashCode ^ email.hashCode;

  KarlUser copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? department,
    String? position,
    List<String>? permissions,
    DateTime? lastLogin,
    bool? isActive,
  }) {
    return KarlUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      department: department ?? this.department,
      position: position ?? this.position,
      permissions: permissions ?? this.permissions,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
    );
  }
}

