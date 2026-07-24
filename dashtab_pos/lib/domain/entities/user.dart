class User {
  final String id;
  final String tenantId;
  final String username;
  final String? fullName;
  final String? email;

  User({
    required this.id,
    required this.tenantId,
    required this.username,
    this.fullName,
    this.email,
  });

  // Equatable or generic equality methods would go here
}
