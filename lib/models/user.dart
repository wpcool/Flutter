class User {
  final int id;
  final String username;
  final String? nickname;
  final String? phone;
  final String? email;
  final String? avatar;

  User({
    required this.id,
    required this.username,
    this.nickname,
    this.phone,
    this.email,
    this.avatar,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      nickname: json['nickname'],
      phone: json['phone'],
      email: json['email'],
      avatar: json['avatar'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'nickname': nickname,
      'phone': phone,
      'email': email,
      'avatar': avatar,
    };
  }
}
