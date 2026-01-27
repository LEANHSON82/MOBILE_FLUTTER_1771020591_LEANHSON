class User {
  final int id;
  final String fullName;
  final double walletBalance;
  final String userId;
  final String? avatarUrl;
  final List<String> roles;

  User({
    required this.id,
    required this.fullName,
    required this.walletBalance,
    required this.userId,
    this.avatarUrl,
    this.roles = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      fullName: json['fullName'] ?? '',
      walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0.0,
      userId: json['userId'] ?? '',
      avatarUrl: json['avatarUrl'],
      roles: (json['roles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
