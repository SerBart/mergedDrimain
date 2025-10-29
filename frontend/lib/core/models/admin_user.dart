class AdminUser {
  final int id;
  final String username;
  final Set<String> roles;
  final int? dzialId;
  final String? dzialNazwa;
  final Set<String> modules;
  final String? email;

  AdminUser({
    required this.id,
    required this.username,
    required this.roles,
    this.dzialId,
    this.dzialNazwa,
    required this.modules,
    this.email,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: (json['id'] as num?)?.toInt() ?? 0,
        username: json['username'] as String? ?? '',
        roles: ((json['roles'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet(),
        dzialId: (json['dzialId'] as num?)?.toInt(),
        dzialNazwa: json['dzialNazwa'] as String?,
        modules: ((json['modules'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet(),
        email: json['email'] as String?,
      );
}
