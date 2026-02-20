class UserModel {
  final int id;
  final String name;
  final String phoneNumber;
  final bool faceEnrolled;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.faceEnrolled,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as int,
        name: json['name'] as String,
        phoneNumber: json['phone_number'] as String,
        faceEnrolled: json['face_enrolled'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
