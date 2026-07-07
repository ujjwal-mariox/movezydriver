class DriverProfileBundle {
  final String id;
  final String fullName;
  final String mobileNumber;
  final String countryCode;
  final String email;
  final String city;
  final String state;
  final String status;
  final bool isOnline;
  final bool isActive;
  final double rating;
  final int totalRides;
  final String profilePhoto;
  final String createdAt;
  final List<String> languages;
  final DriverProfileStats stats;
  final DriverLicenseInfo license;
  final bool isKycVerified;

  DriverProfileBundle({
    required this.id,
    required this.fullName,
    required this.mobileNumber,
    required this.countryCode,
    required this.email,
    required this.city,
    required this.state,
    required this.status,
    required this.isOnline,
    required this.isActive,
    required this.rating,
    required this.totalRides,
    required this.profilePhoto,
    required this.createdAt,
    required this.languages,
    required this.stats,
    required this.license,
    required this.isKycVerified,
  });

  DriverProfileBundle copyWith({
    String? profilePhoto,
  }) {
    return DriverProfileBundle(
      id: id,
      fullName: fullName,
      mobileNumber: mobileNumber,
      countryCode: countryCode,
      email: email,
      city: city,
      state: state,
      status: status,
      isOnline: isOnline,
      isActive: isActive,
      rating: rating,
      totalRides: totalRides,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      createdAt: createdAt,
      languages: languages,
      stats: stats,
      license: license,
      isKycVerified: isKycVerified,
    );
  }

  factory DriverProfileBundle.fromResponses({
    required Map<String, dynamic> profileJson,
    required Map<String, dynamic> detailsJson,
  }) {
    final profileData = Map<String, dynamic>.from(
      (profileJson['data'] ?? {}) as Map,
    );
    final detailsData = Map<String, dynamic>.from(
      (detailsJson['data'] ?? {}) as Map,
    );
    final stats = Map<String, dynamic>.from((profileData['stats'] ?? {}) as Map);
    final kyc = Map<String, dynamic>.from((detailsData['kyc'] ?? {}) as Map);
    final drivingLicense = Map<String, dynamic>.from(
      (kyc['drivingLicense'] ?? {}) as Map,
    );

    return DriverProfileBundle(
      id: profileData['_id']?.toString() ?? '',
      fullName: profileData['fullName']?.toString() ?? '',
      mobileNumber: profileData['mobileNumber']?.toString() ?? '',
      countryCode: profileData['countryCode']?.toString() ?? '+91',
      email: profileData['email']?.toString() ?? '',
      city: profileData['city']?.toString() ?? '',
      state: profileData['state']?.toString() ?? '',
      status: profileData['status']?.toString() ?? '',
      isOnline: _toBool(profileData['isOnline']),
      isActive: _toBool(profileData['isActive']),
      rating: _toDouble(profileData['rating']),
      totalRides: _toInt(profileData['totalRides']),
      profilePhoto: profileData['profilePhoto']?.toString() ?? '',
      createdAt: profileData['createdAt']?.toString() ?? '',
      languages: _toStringList(profileData['languages']),
      stats: DriverProfileStats(
        totalTrips: _toInt(stats['totalTrips']),
        totalEarnings: _toDouble(stats['totalEarnings']),
        totalDistance: _toDouble(stats['totalDistance']),
        totalDurationMin: _toInt(stats['totalDurationMin']),
      ),
      license: DriverLicenseInfo(
        number: drivingLicense['number']?.toString() ?? '',
        expiryDate: drivingLicense['expiryDate']?.toString() ?? '',
      ),
      isKycVerified: _toBool(kyc['isVerified']),
    );
  }
}

class DriverProfileStats {
  final int totalTrips;
  final double totalEarnings;
  final double totalDistance;
  final int totalDurationMin;

  DriverProfileStats({
    required this.totalTrips,
    required this.totalEarnings,
    required this.totalDistance,
    required this.totalDurationMin,
  });
}

class DriverLicenseInfo {
  final String number;
  final String expiryDate;

  DriverLicenseInfo({
    required this.number,
    required this.expiryDate,
  });
}

bool _toBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().toLowerCase().trim() ?? '';
  return normalized == 'true' || normalized == '1';
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _toStringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
  }
  return [];
}
