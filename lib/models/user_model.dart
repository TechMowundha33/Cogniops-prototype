class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // 'student' | 'developer'
  final int xp;
  final int streak;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.xp = 0,
    this.streak = 0,
    required this.createdAt,
  });

  bool get isStudent => role == 'student';
  bool get isDeveloper => role == 'developer';
  String get avatarLetter => name.isNotEmpty ? name[0].toUpperCase() : 'U';

  UserModel copyWith({int? xp, int? streak}) => UserModel(
    id: id, name: name, email: email, role: role,
    xp: xp ?? this.xp, streak: streak ?? this.streak, createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'email': email, 'role': role,
    'xp': xp, 'streak': streak, 'createdAt': createdAt.toIso8601String(),
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'], name: json['name'], email: json['email'], role: json['role'],
    xp: json['xp'] ?? 0, streak: json['streak'] ?? 0,
    createdAt: DateTime.parse(json['createdAt']),
  );
}
