import '../../domain/entities/user.dart';

class UserModel extends User {
  UserModel({
    required super.id,
    required super.tenantId,
    required super.username,
    super.fullName,
    super.email,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['userId'] ?? json['id'],
      tenantId: json['tenantId'] ?? '',
      username: json['username'] ?? '',
      fullName: json['fullName'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': id,
      'tenantId': tenantId,
      'username': username,
      'fullName': fullName,
      'email': email,
    };
  }
}
