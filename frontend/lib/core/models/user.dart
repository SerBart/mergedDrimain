class User {
  final int id;
  final String username;
  final String role;
  final String? token;
  final String? email;
  final int? dzialId;
  final String? dzialNazwa;
  final Set<String> modules;

  User({
    required this.id,
    required this.username,
    required this.role,
    this.token,
    this.email,
    this.dzialId,
    this.dzialNazwa,
    this.modules = const {},
  });

  User copyWith({int? id, String? username, String? role, String? token, String? email, int? dzialId, String? dzialNazwa, Set<String>? modules}) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      role: role ?? this.role,
      token: token ?? this.token,
      email: email ?? this.email,
      dzialId: dzialId ?? this.dzialId,
      dzialNazwa: dzialNazwa ?? this.dzialNazwa,
      modules: modules ?? this.modules,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] ?? 0,
        username: json['username'] ?? '',
        role: json['role'] ?? (json['roles'] is List && (json['roles'] as List).contains('ROLE_ADMIN') ? 'ADMIN' : 'USER'),
        token: json['token'],
        email: json['email'],
        dzialId: json['dzialId'] is num ? (json['dzialId'] as num).toInt() : null,
        dzialNazwa: json['dzialNazwa']?.toString(),
        modules: ((json['modules'] as List?) ?? const []).map((e) => e.toString()).toSet(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'role': role,
        'token': token,
        'email': email,
        'dzialId': dzialId,
        'dzialNazwa': dzialNazwa,
        'modules': modules.toList(),
      };
}