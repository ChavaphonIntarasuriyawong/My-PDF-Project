class UserModel {
  final String uid;
  final String name;
  final String email;
  final String avatarUrl;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.avatarUrl = '',
  });

  UserModel copyWith({String? uid, String? name, String? email, String? avatarUrl}) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'email': email,
    'avatarUrl': avatarUrl,
  };
}
