class DriverProfile {
  const DriverProfile({
    required this.driverId,
    required this.companyId,
    required this.fullName,
    required this.licenseNumber,
    required this.isActive,
    this.email,
    this.phoneNumber,
    this.nrcNumber,
    this.licenseClass,
    this.licenseExpiry,
    this.profilePhoto,
    this.status,
    this.stats = const {},
    this.companyName,
    this.createdAt,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      driverId: json['driver_id'] as int? ?? 0,
      companyId: json['company_id'] as int? ?? 0,
      fullName: (json['full_name'] as String?) ?? 'Unknown driver',
      licenseNumber: (json['license_number'] as String?) ?? 'Unknown license',
      isActive: json['is_active'] as bool? ?? true,
      email: json['email'] as String?,
      phoneNumber: (json['phone'] ?? json['phone_number']) as String?,
      nrcNumber: (json['nrcNumber'] ?? json['nrc_number']) as String?,
      licenseClass: (json['licenseClass'] ?? json['license_class']) as String?,
      licenseExpiry: (json['licenseExpiry'] ?? json['license_expiry']) is String
          ? DateTime.tryParse((json['licenseExpiry'] ?? json['license_expiry']) as String)?.toLocal()
          : null,
      profilePhoto: (json['profilePhoto'] ?? json['profile_photo_url']) as String?,
      status: json['status'] as String?,
      stats: json['stats'] is Map<String, dynamic>
          ? json['stats'] as Map<String, dynamic>
          : const {},
      companyName: json['company_name'] as String?,
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
          : null,
    );
  }

  final int driverId;
  final int companyId;
  final String fullName;
  final String licenseNumber;
  final bool isActive;
  final String? email;
  final String? phoneNumber;
  final String? nrcNumber;
  final String? licenseClass;
  final DateTime? licenseExpiry;
  final String? profilePhoto;
  final String? status;
  final Map<String, dynamic> stats;
  final String? companyName;
  final DateTime? createdAt;
}
