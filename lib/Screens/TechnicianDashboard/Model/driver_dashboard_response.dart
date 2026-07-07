import 'dart:convert';

DriverDashboardResponse driverDashboardResponseFromJson(String str) =>
    DriverDashboardResponse.fromJson(json.decode(str));

DriverStatusResponse driverStatusResponseFromJson(String str) =>
    DriverStatusResponse.fromJson(json.decode(str));

class DriverDashboardResponse {
  final int code;
  final String message;
  final DriverDashboardData? data;

  DriverDashboardResponse({
    required this.code,
    required this.message,
    required this.data,
  });

  factory DriverDashboardResponse.fromJson(Map<String, dynamic> json) {
    return DriverDashboardResponse(
      code: _toInt(json['code']),
      message: json['message']?.toString() ?? '',
      data: json['data'] == null
          ? null
          : DriverDashboardData.fromJson(
              Map<String, dynamic>.from(json['data'] as Map),
            ),
    );
  }
}

class DriverDashboardData {
  final DashboardDriver driver;
  final DashboardWallet wallet;
  final DashboardStats stats;
  final DashboardBookings bookings;

  DriverDashboardData({
    required this.driver,
    required this.wallet,
    required this.stats,
    required this.bookings,
  });

  factory DriverDashboardData.fromJson(Map<String, dynamic> json) {
    return DriverDashboardData(
      driver: DashboardDriver.fromJson(
        Map<String, dynamic>.from((json['driver'] ?? {}) as Map),
      ),
      wallet: DashboardWallet.fromJson(
        Map<String, dynamic>.from((json['wallet'] ?? {}) as Map),
      ),
      stats: DashboardStats.fromJson(
        Map<String, dynamic>.from((json['stats'] ?? {}) as Map),
      ),
      bookings: DashboardBookings.fromJson(
        Map<String, dynamic>.from((json['bookings'] ?? {}) as Map),
      ),
    );
  }
}

class DashboardDriver {
  final String id;
  final String fullName;
  final String mobileNumber;
  final String countryCode;
  final String status;
  final bool isOnline;
  final double rating;
  final int totalRides;
  final String profilePhoto;
  final String city;
  final String state;
  final String rejectionReason;
  final String suspensionReason;

  DashboardDriver({
    required this.id,
    required this.fullName,
    required this.mobileNumber,
    required this.countryCode,
    required this.status,
    required this.isOnline,
    required this.rating,
    required this.totalRides,
    required this.profilePhoto,
    required this.city,
    required this.state,
    required this.rejectionReason,
    required this.suspensionReason,
  });

  factory DashboardDriver.fromJson(Map<String, dynamic> json) {
    return DashboardDriver(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      mobileNumber: json['mobileNumber']?.toString() ?? '',
      countryCode: json['countryCode']?.toString() ?? '+91',
      status: json['status']?.toString() ?? '',
      isOnline: _toBool(json['isOnline']),
      rating: _toDouble(json['rating']),
      totalRides: _toInt(json['totalRides']),
      profilePhoto: json['profilePhoto']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      rejectionReason: json['rejectionReason']?.toString() ?? '',
      suspensionReason: json['suspensionReason']?.toString() ?? '',
    );
  }
}

class DashboardWallet {
  final double balance;
  final double lockedBalance;

  DashboardWallet({
    required this.balance,
    required this.lockedBalance,
  });

  factory DashboardWallet.fromJson(Map<String, dynamic> json) {
    return DashboardWallet(
      balance: _toDouble(json['balance']),
      lockedBalance: _toDouble(json['lockedBalance']),
    );
  }
}

class DashboardStats {
  final double totalEarnings;
  final int totalServices;
  final int upcomingServices;
  final int todaysServices;
  final double todaysEarnings;
  final int onGoingCount;
  final int pendingCount;
  final int completedCount;
  final List<MonthlyRevenuePoint> monthlyRevenue;

  DashboardStats({
    required this.totalEarnings,
    required this.totalServices,
    required this.upcomingServices,
    required this.todaysServices,
    required this.todaysEarnings,
    required this.onGoingCount,
    required this.pendingCount,
    required this.completedCount,
    required this.monthlyRevenue,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalEarnings: _toDouble(json['totalEarnings']),
      totalServices: _toInt(json['totalServices']),
      upcomingServices: _toInt(json['upcomingServices']),
      todaysServices: _toInt(json['todaysServices']),
      todaysEarnings: _toDouble(json['todaysEarnings']),
      onGoingCount: _toInt(json['onGoingCount']),
      pendingCount: _toInt(json['pendingCount']),
      completedCount: _toInt(json['completedCount']),
      monthlyRevenue: _toList(json['monthlyRevenue'])
          .map((item) => MonthlyRevenuePoint.fromJson(item))
          .toList(),
    );
  }
}

class MonthlyRevenuePoint {
  final String month;
  final double amount;

  MonthlyRevenuePoint({
    required this.month,
    required this.amount,
  });

  factory MonthlyRevenuePoint.fromJson(Map<String, dynamic> json) {
    return MonthlyRevenuePoint(
      month: json['month']?.toString() ?? '',
      amount: _toDouble(json['amount']),
    );
  }
}

class DashboardBookings {
  final DashboardBooking? current;
  final List<DashboardBooking> pending;
  final List<DashboardBooking> completed;

  DashboardBookings({
    required this.current,
    required this.pending,
    required this.completed,
  });

  factory DashboardBookings.fromJson(Map<String, dynamic> json) {
    return DashboardBookings(
      current: json['current'] == null
          ? null
          : DashboardBooking.fromJson(
              Map<String, dynamic>.from((json['current']) as Map),
            ),
      pending: _toList(json['pending'])
          .map((item) => DashboardBooking.fromJson(item))
          .toList(),
      completed: _toList(json['completed'])
          .map((item) => DashboardBooking.fromJson(item))
          .toList(),
    );
  }
}

class DashboardBooking {
  final String id;
  final String bookingNumber;
  final String serviceType;
  final String status;
  final BookingLocation pickup;
  final BookingLocation drop;
  final String pickupAddress;
  final String dropAddress;
  final String scheduledAt;
  final bool isScheduled;
  final String createdAt;
  final String completedAt;
  final String assignedAt;
  final double distanceKm;
  final int durationMin;
  final double estimatedFare;
  final double baseFare;
  final double addonTotal;
  final String customerName;
  final String vehicleTypeName;
  final String vehicleTypeIcon;
  final String paymentMethod;
  final String goodsType;
  final String goodsDescription;
  final String otp;
  final List<BookingAddon> addons;
  final BookingLoadingUnloading? loadingUnloading;

  DashboardBooking({
    required this.id,
    required this.bookingNumber,
    required this.serviceType,
    required this.status,
    required this.pickup,
    required this.drop,
    required this.pickupAddress,
    required this.dropAddress,
    required this.scheduledAt,
    required this.isScheduled,
    required this.createdAt,
    required this.completedAt,
    required this.assignedAt,
    required this.distanceKm,
    required this.durationMin,
    required this.estimatedFare,
    required this.baseFare,
    required this.addonTotal,
    required this.customerName,
    required this.vehicleTypeName,
    required this.vehicleTypeIcon,
    required this.paymentMethod,
    required this.goodsType,
    required this.goodsDescription,
    required this.otp,
    required this.addons,
    required this.loadingUnloading,
  });

  factory DashboardBooking.fromJson(Map<String, dynamic> json) {
    return DashboardBooking(
      id: json['id']?.toString() ?? '',
      bookingNumber: json['bookingNumber']?.toString() ?? '',
      serviceType: json['serviceType']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      pickup: BookingLocation.fromJson(
        json['pickup'] is Map ? Map<String, dynamic>.from(json['pickup'] as Map) : {},
      ),
      drop: BookingLocation.fromJson(
        json['drop'] is Map ? Map<String, dynamic>.from(json['drop'] as Map) : {},
      ),
      pickupAddress: json['pickupAddress']?.toString() ?? '',
      dropAddress: json['dropAddress']?.toString() ?? '',
      scheduledAt: json['scheduledAt']?.toString() ?? '',
      isScheduled: _toBool(json['isScheduled']),
      createdAt: json['createdAt']?.toString() ?? '',
      completedAt: json['completedAt']?.toString() ?? '',
      assignedAt: json['assignedAt']?.toString() ?? '',
      distanceKm: _toDouble(json['distanceKm']),
      durationMin: _toInt(json['durationMin']),
      estimatedFare: _toDouble(json['estimatedFare']),
      baseFare: _toDouble(json['baseFare']),
      addonTotal: _toDouble(json['addonTotal']),
      customerName: json['customerName']?.toString() ?? '',
      vehicleTypeName: json['vehicleTypeName']?.toString() ?? '',
      vehicleTypeIcon: json['vehicleTypeIcon']?.toString() ?? '',
      paymentMethod: json['paymentMethod']?.toString() ?? 'CASH',
      goodsType: json['goodsType']?.toString() ?? '',
      goodsDescription: json['goodsDescription']?.toString() ?? '',
      otp: json['otp']?.toString() ?? '',
      addons: _toList(json['addons'])
          .map((item) => BookingAddon.fromJson(item))
          .toList(),
      loadingUnloading: json['loadingUnloading'] != null && json['loadingUnloading'] is Map
          ? BookingLoadingUnloading.fromJson(
              Map<String, dynamic>.from(json['loadingUnloading'] as Map),
            )
          : null,
    );
  }
}

class BookingLocation {
  final String address;
  final double lat;
  final double lng;
  final String contactName;
  final String contactPhone;

  BookingLocation({
    required this.address,
    required this.lat,
    required this.lng,
    required this.contactName,
    required this.contactPhone,
  });

  factory BookingLocation.fromJson(Map<String, dynamic> json) {
    return BookingLocation(
      address: json['address']?.toString() ?? '',
      lat: _toDouble(json['lat']),
      lng: _toDouble(json['lng']),
      contactName: json['contactName']?.toString() ?? '',
      contactPhone: json['contactPhone']?.toString() ?? '',
    );
  }
}

class BookingAddon {
  final String name;
  final double price;
  final int quantity;

  BookingAddon({
    required this.name,
    required this.price,
    required this.quantity,
  });

  factory BookingAddon.fromJson(Map<String, dynamic> json) {
    return BookingAddon(
      name: json['name']?.toString() ?? '',
      price: _toDouble(json['price']),
      quantity: _toInt(json['quantity']),
    );
  }
}

class BookingLoadingUnloading {
  final String type;
  final int? pickupFloor;
  final int? dropFloor;
  final double charge;

  BookingLoadingUnloading({
    required this.type,
    this.pickupFloor,
    this.dropFloor,
    required this.charge,
  });

  factory BookingLoadingUnloading.fromJson(Map<String, dynamic> json) {
    return BookingLoadingUnloading(
      type: json['type']?.toString() ?? 'NONE',
      pickupFloor: json['pickupFloor'] != null ? _toInt(json['pickupFloor']) : null,
      dropFloor: json['dropFloor'] != null ? _toInt(json['dropFloor']) : null,
      charge: _toDouble(json['charge']),
    );
  }
}

class DriverStatusResponse {
  final int code;
  final String message;
  final DriverStatusData? data;

  DriverStatusResponse({
    required this.code,
    required this.message,
    required this.data,
  });

  factory DriverStatusResponse.fromJson(Map<String, dynamic> json) {
    return DriverStatusResponse(
      code: _toInt(json['code']),
      message: json['message']?.toString() ?? '',
      data: json['data'] == null
          ? null
          : DriverStatusData.fromJson(
              Map<String, dynamic>.from(json['data'] as Map),
            ),
    );
  }
}

class DriverStatusData {
  final bool isOnline;
  final String status;
  final String reason;

  DriverStatusData({
    required this.isOnline,
    required this.status,
    required this.reason,
  });

  factory DriverStatusData.fromJson(Map<String, dynamic> json) {
    return DriverStatusData(
      isOnline: _toBool(json['isOnline']),
      status: json['status']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
    );
  }
}

List<Map<String, dynamic>> _toList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  return <Map<String, dynamic>>[];
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool _toBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  final normalized = value?.toString().toLowerCase() ?? '';
  return normalized == 'true' || normalized == '1';
}
