class AppUser {
  AppUser({
    required this.id,
    required this.username,
    this.email,
    this.firstName,
    this.lastName,
    this.role = 'public',
    this.organization,
    this.phone,
    this.pseudonym,
    this.city,
    this.region,
    this.profession,
    this.bio,
    this.profilePhotoUrl,
    this.profileStats,
    this.consentAnalytics = false,
  });

  final int id;
  final String username;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String role;
  final String? organization;
  final String? phone;
  final String? pseudonym;
  final String? city;
  final String? region;
  final String? profession;
  final String? bio;
  final String? profilePhotoUrl;
  final Map<String, dynamic>? profileStats;
  final bool consentAnalytics;

  String get displayName {
    final full = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    return full.isNotEmpty ? full : username;
  }

  bool get isAdmin => role == 'admin';
  bool get isAgent => role == 'agent' || isAdmin;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      role: json['role'] as String? ?? 'public',
      organization: json['organization'] as String?,
      phone: json['phone'] as String?,
      pseudonym: json['pseudonym'] as String?,
      city: json['city'] as String?,
      region: json['region'] as String?,
      profession: json['profession'] as String?,
      bio: json['bio'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      profileStats: json['profile_stats'] as Map<String, dynamic>?,
      consentAnalytics: json['consent_analytics'] as bool? ?? false,
    );
  }
}
