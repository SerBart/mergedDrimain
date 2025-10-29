class User {
  final int id;
  final String username;
  final String role;
  final String? token;
  final Set<String> modules;

  User({
    required this.id,
    required this.username,
    required this.role,
    this.token,
    this.modules = const {},
  });

  User copyWith({int? id, String? username, String? role, String? token, Set<String>? modules}) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      role: role ?? this.role,
      token: token ?? this.token,
      modules: modules ?? this.modules,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] ?? 0,
        username: json['username'] ?? '',
        role: json['role'] ?? 'USER',
        token: json['token'],
        modules: ((json['modules'] as List?) ?? const []).map((e) => e.toString()).toSet(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'role': role,
        'token': token,
        'modules': modules.toList(),
      };
}