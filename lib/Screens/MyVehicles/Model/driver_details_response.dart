import 'dart:convert';

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

  Data({this.vehicles, this.driver});

  Data.fromJson(Map<String, dynamic> json) {
    if (json['vehicles'] != null) {
      vehicles = (json['vehicles'] as List)
          .map((v) => VehicleItem.fromJson(v))
          .toList();
    }
    driver = json['driver'] != null ? DriverInfo.fromJson(json['driver']) : null;
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
  String? verificationStatus;
  bool? isPrimary;
  bool? isActive;

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
    verificationStatus = json['verificationStatus'];
    isPrimary = json['isPrimary'];
    isActive = json['isActive'];
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
