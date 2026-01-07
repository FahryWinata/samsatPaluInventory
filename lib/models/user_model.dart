class User {
  final int? id;
  final String name;
  final String? email;
  final String? department;
  final DateTime createdAt;

  User({
    this.id,
    required this.name,
    this.email,
    this.department,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'email': email,
      'department': department,
      'created_at': createdAt.toIso8601String(),
    };
    // Only include 'id' if it's not null (for updates, not inserts)
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      department: map['department'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
