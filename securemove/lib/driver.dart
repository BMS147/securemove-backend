class DriverProfile {
  const DriverProfile({
    required this.driverId,
    required this.companyId,
    required this.fullName,
    required this.licenseNumber,
    required this.isActive,
    this.email,
    this.phoneNumber,
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
      phoneNumber: json['phone_number'] as String?,
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
  final String? companyName;
  final DateTime? createdAt;
}
