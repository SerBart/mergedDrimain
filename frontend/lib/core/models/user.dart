class User {
  final int id;
  final String username;
  final String role;
  final String? token;

  User({
    required this.id,
    required this.username,
    required this.role,
    this.token,
  });

  User copyWith({int? id, String? username, String? role, String? token}) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      role: role ?? this.role,
      token: token ?? this.token,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] ?? 0,
        username: json['username'] ?? '',
        role: json['role'] ?? 'USER',
        token: json['token'],
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'username': username, 'role': role, 'token': token};
}