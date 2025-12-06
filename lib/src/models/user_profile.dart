class UserData {
  final String userId;
  final String phoneNumber;
  final String fullName;
  final String email;
  final String profileUrl;

  const UserData({
    required this.userId,
    required this.phoneNumber,
    required this.fullName,
    required this.email,
    required this.profileUrl,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      userId: json['user_id'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      profileUrl: json['profile_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'phone_number': phoneNumber,
      'full_name': fullName,
      'email': email,
      'profile_url': profileUrl,
    };
  }

  static const empty = UserData(
    userId: '',
    phoneNumber: '',
    fullName: '',
    email: '',
    profileUrl: '',
  );
}
