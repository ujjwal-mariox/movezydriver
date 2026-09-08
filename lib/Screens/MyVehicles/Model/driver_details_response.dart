import 'dart:convert';

/// "2027-03-31T00:00:00.000Z" → "2027-03-31"; dates are shown, never computed on.
String? _dateOnly(dynamic v) => v == null ? null : v.toString().split('T').first;

DriverDetailsResponse driverDetailsResponseFromJson(String str) => DriverDetailsResponse.fromJson(json.decode(str));

class DriverDetailsResponse {
  int? code;
  String? message;
  Data? data;

  DriverDetailsResponse({this.code, this.message, this.data});

  DriverDetailsResponse.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['code'] = code;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class Data {
  List<VehicleItem>? vehicles;
  DriverInfo? driver;
  /// The vehicle currently taking bookings (isPrimary), if any.
  String? activeVehicleId;

  Data({this.vehicles, this.driver, this.activeVehicleId});

  Data.fromJson(Map<String, dynamic> json) {
    if (json['vehicles'] != null) {
      vehicles = (json['vehicles'] as List)
          .map((v) => VehicleItem.fromJson(v))
          .toList();
    }
    driver = json['driver'] != null ? DriverInfo.fromJson(json['driver']) : null;
    activeVehicleId = json['activeVehicleId']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (vehicles != null) {
      data['vehicles'] = vehicles!.map((v) => v.toJson()).toList();
    }
    if (driver != null) {
      data['driver'] = driver!.toJson();
    }
    return data;
  }
}

class VehicleItem {
  String? id;
  String? vehicleNumber;
  String? vehicleType;
  String? vehicleBodyType;
  String? fuelType;
  String? rcFrontImage;
  String? city;
  String? assignedDriverName;
  String? assignedDriverPhone;
  bool? onboardingFeePaid;
  String? onboardingPaymentId;
  String? referralCodeApplied;
  num? referralDiscount;
  num? couponDiscount;
  String? couponCodeApplied;
  String? verificationStatus;
  bool? isPrimary;
  bool? isActive;
  /// Taken off dispatch by the document-expiry check (RC / insurance / PUC).
  bool? dispatchBlocked;
  List<String>? dispatchReasons;
  String? rcExpiryDate;
  String? insuranceExpiryDate;
  String? pucExpiryDate;
  VehicleItem({
    this.id,
    this.vehicleNumber,
    this.vehicleType,
    this.vehicleBodyType,
    this.fuelType,
    this.rcFrontImage,
    this.city,
    this.assignedDriverName,
    this.assignedDriverPhone,
    this.onboardingFeePaid,
    this.onboardingPaymentId,
    this.referralCodeApplied,
    this.referralDiscount,
    this.couponDiscount,
    this.couponCodeApplied,
    this.verificationStatus,
    this.isPrimary,
    this.isActive,
  });

  VehicleItem.fromJson(Map<String, dynamic> json) {
    id = json['_id'];
    vehicleNumber = json['vehicleNumber'];
    vehicleType = json['vehicleType'];
    vehicleBodyType = json['vehicleBodyType'];
    fuelType = json['fuelType'];
    rcFrontImage = json['rcFrontImage'];
    city = json['city'];
    assignedDriverName = json['assignedDriverName'];
    assignedDriverPhone = json['assignedDriverPhone'];
    onboardingFeePaid = json['onboardingFeePaid'];
    onboardingPaymentId = json['onboardingPaymentId'];
    referralCodeApplied = json['referralCodeApplied'];
    referralDiscount = json['referralDiscount'];
    couponDiscount = json['couponDiscount'];
    couponCodeApplied = json['couponCodeApplied'];
    verificationStatus = json['verificationStatus'];
    isPrimary = json['isPrimary'];
    isActive = json['isActive'];
    final block = json['dispatchBlock'];
    dispatchBlocked = block is Map ? block['blocked'] == true : null;
    dispatchReasons = block is Map && block['reasons'] is List
        ? (block['reasons'] as List).map((e) => e.toString()).toList()
        : null;
    rcExpiryDate = _dateOnly(json['rcExpiryDate']);
    insuranceExpiryDate = _dateOnly(json['insuranceExpiryDate']);
    pucExpiryDate = _dateOnly(json['pucExpiryDate']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['_id'] = id;
    data['vehicleNumber'] = vehicleNumber;
    data['vehicleType'] = vehicleType;
    data['vehicleBodyType'] = vehicleBodyType;
    data['fuelType'] = fuelType;
    data['rcFrontImage'] = rcFrontImage;
    data['city'] = city;
    data['assignedDriverName'] = assignedDriverName;
    data['assignedDriverPhone'] = assignedDriverPhone;
    data['onboardingFeePaid'] = onboardingFeePaid;
    data['onboardingPaymentId'] = onboardingPaymentId;
    data['referralCodeApplied'] = referralCodeApplied;
    data['referralDiscount'] = referralDiscount;
    data['couponDiscount'] = couponDiscount;
    data['couponCodeApplied'] = couponCodeApplied;
    data['verificationStatus'] = verificationStatus;
    data['isPrimary'] = isPrimary;
    data['isActive'] = isActive;
    return data;
  }
}

class DriverInfo {
  String? fullName;
  String? mobileNumber;
  bool? onboardingFeePaid;
  String? profilePhoto;

  DriverInfo({this.fullName, this.mobileNumber, this.onboardingFeePaid, this.profilePhoto});

  DriverInfo.fromJson(Map<String, dynamic> json) {
    fullName = json['fullName'];
    mobileNumber = json['mobileNumber'];
    onboardingFeePaid = json['onboardingFeePaid'];
    profilePhoto = json['profilePhoto'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['fullName'] = fullName;
    data['mobileNumber'] = mobileNumber;
    data['onboardingFeePaid'] = onboardingFeePaid;
    data['profilePhoto'] = profilePhoto;
    return data;
  }
}
