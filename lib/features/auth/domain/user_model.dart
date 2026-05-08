class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.role = 'user',
  });

  UserModel copyWith({String? uid, String? name, String? email, String? role}) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'email': email, 'role': role};

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'user',
    );
  }
}
