import 'dart:async';
import 'dart:convert' as convert;
import 'package:http/http.dart' as http_client;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

/// Offline service for storing trip data locally and syncing when online
class OfflineService extends GetxService {
  static const String _pendingTripsKey = 'pending_trips';
  static const String _pendingUploadsKey = 'pending_uploads';
  
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  final RxBool isSyncing = false.obs;
  final RxInt pendingCount = 0.obs;
  final RxBool isOffline = false.obs;
  
  SharedPreferences? _prefs;
  
  Future<OfflineService> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadPendingCount();
    _setupConnectivityListener();
    return this;
  }

  void _setupConnectivityListener() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final offline = results.contains(ConnectivityResult.none);
      isOffline.value = offline;
      
      // Auto-sync when coming back online
      if (!offline && pendingCount.value > 0) {
        syncPendingData();
      }
    });
  }

  void _loadPendingCount() {
    final trips = _prefs?.getStringList(_pendingTripsKey) ?? [];
    final uploads = _prefs?.getStringList(_pendingUploadsKey) ?? [];
    pendingCount.value = trips.length + uploads.length;
  }

  /// Store trip completion data locally when offline
  Future<bool> storeTripCompletion(TripCompletionData data) async {
    try {
      final trips = _prefs?.getStringList(_pendingTripsKey) ?? [];
      trips.add(jsonEncode(data.toJson()));
      await _prefs?.setStringList(_pendingTripsKey, trips);
      _loadPendingCount();
      return true;
    } catch (e) {
      print('Error storing trip: $e');
      return false;
    }
  }

  /// Store document upload data locally when offline
  Future<bool> storeDocumentUpload(DocumentUploadData data) async {
    try {
      final uploads = _prefs?.getStringList(_pendingUploadsKey) ?? [];
      uploads.add(jsonEncode(data.toJson()));
      await _prefs?.setStringList(_pendingUploadsKey, uploads);
      _loadPendingCount();
      return true;
    } catch (e) {
      print('Error storing document: $e');
      return false;
    }
  }

  /// Sync all pending data when online
  Future<SyncResult> syncPendingData() async {
    if (isSyncing.value) {
      return SyncResult(success: false, message: 'Already syncing');
    }

    // Check if online
    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.none)) {
      return SyncResult(success: false, message: 'No network connection');
    }

    isSyncing.value = true;
    int syncedTrips = 0;
    int syncedDocs = 0;
    List<String> errors = [];

    try {
      // Sync trips
      final trips = _prefs?.getStringList(_pendingTripsKey) ?? [];
      List<String> remainingTrips = [];
      
      for (final tripJson in trips) {
        try {
          final data = TripCompletionData.fromJson(jsonDecode(tripJson));
          final success = await _syncTrip(data);
          if (success) {
            syncedTrips++;
          } else {
            remainingTrips.add(tripJson);
          }
        } catch (e) {
          errors.add('Trip sync error: $e');
          remainingTrips.add(tripJson);
        }
      }
      await _prefs?.setStringList(_pendingTripsKey, remainingTrips);

      // Sync document uploads
      final uploads = _prefs?.getStringList(_pendingUploadsKey) ?? [];
      List<String> remainingUploads = [];
      
      for (final uploadJson in uploads) {
        try {
          final data = DocumentUploadData.fromJson(jsonDecode(uploadJson));
          final success = await _syncDocument(data);
          if (success) {
            syncedDocs++;
          } else {
            remainingUploads.add(uploadJson);
          }
        } catch (e) {
          errors.add('Document sync error: $e');
          remainingUploads.add(uploadJson);
        }
      }
      await _prefs?.setStringList(_pendingUploadsKey, remainingUploads);

      _loadPendingCount();

      return SyncResult(
        success: errors.isEmpty,
        message: 'Synced $syncedTrips trips and $syncedDocs documents',
        syncedTrips: syncedTrips,
        syncedDocs: syncedDocs,
        errors: errors,
      );
    } finally {
      isSyncing.value = false;
    }
  }

  /// Replay a locally-saved completion against the real endpoints, in the
  /// same order the live screen uses: start (if the trip was still PICKED),
  /// complete (with the delivery OTP the driver already entered), then cash
  /// collection for COD. Returns true ONLY on a server-confirmed completion —
  /// the previous placeholder returned true after a fake delay, which would
  /// have deleted saved trips without the server ever hearing about them.
  Future<bool> _syncTrip(TripCompletionData data) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${Prefs.accessToken}',
      };

      if (data.needsStart) {
        await http_client
            .post(Uri.parse(ApiUrls.driverStartTripUrl(data.tripId)),
                headers: headers)
            .timeout(const Duration(seconds: 20));
      }

      final res = await http_client
          .post(
            Uri.parse(ApiUrls.driverCompleteTripUrl(data.tripId)),
            headers: headers,
            body: data.deliveryOtp == null
                ? null
                : convert.jsonEncode({'otp': data.deliveryOtp}),
          )
          .timeout(const Duration(seconds: 20));
      final body = convert.jsonDecode(res.body);
      final code = body is Map ? body['code'] : null;
      final already = body is Map &&
          body['message']?.toString() == 'booking_already_completed';
      if (code != 1 && code != 200 && !already) {
        // A server REFUSAL (bad OTP, wrong state) is terminal for auto-sync —
        // retrying forever cannot fix it. Keep it stored so it stays visible
        // in the pending count rather than vanishing.
        print('Offline trip ${data.tripId} refused by server: ${body is Map ? body['message'] : res.statusCode}');
        return false;
      }

      if (data.owesCash) {
        await http_client
            .post(Uri.parse(ApiUrls.driverCollectCashUrl(data.tripId)),
                headers: headers)
            .timeout(const Duration(seconds: 20));
      }
      return true;
    } catch (e) {
      print('Offline trip sync failed (will retry): $e');
      return false;
    }
  }

  Future<bool> _syncDocument(DocumentUploadData data) async {
    // No upload replay is implemented. Returning false keeps the record
    // stored and visible in the pending count — the placeholder returned a
    // fake true, which deleted the stored upload without sending anything.
    return false;
  }

  /// Get list of pending trips
  List<TripCompletionData> getPendingTrips() {
    final trips = _prefs?.getStringList(_pendingTripsKey) ?? [];
    return trips
        .map((json) => TripCompletionData.fromJson(jsonDecode(json)))
        .toList();
  }

  /// Clear all pending data (use with caution)
  Future<void> clearAllPending() async {
    await _prefs?.remove(_pendingTripsKey);
    await _prefs?.remove(_pendingUploadsKey);
    _loadPendingCount();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}

/// Model for trip completion data stored offline
class TripCompletionData {
  final String tripId;
  final String driverId;
  final DateTime completedAt;
  final double fare;
  final String paymentMode;
  final double? tipAmount;
  final String? notes;
  /// Replay context: the delivery OTP the driver already collected, whether
  /// COD cash still has to be marked collected, and whether the trip was
  /// still PICKED (so start must be called before complete).
  final String? deliveryOtp;
  final bool owesCash;
  final bool needsStart;

  TripCompletionData({
    required this.tripId,
    required this.driverId,
    required this.completedAt,
    required this.fare,
    required this.paymentMode,
    this.tipAmount,
    this.notes,
      this.deliveryOtp,
    this.owesCash = false,
    this.needsStart = false,
  });

  Map<String, dynamic> toJson() => {
    'tripId': tripId,
    'driverId': driverId,
    'completedAt': completedAt.toIso8601String(),
    'fare': fare,
    'paymentMode': paymentMode,
    'tipAmount': tipAmount,
    'notes': notes,
        'deliveryOtp': deliveryOtp,
        'owesCash': owesCash,
        'needsStart': needsStart,
  };

  factory TripCompletionData.fromJson(Map<String, dynamic> json) {
    return TripCompletionData(
      tripId: json['tripId'],
      driverId: json['driverId'],
      completedAt: DateTime.parse(json['completedAt']),
      fare: json['fare'].toDouble(),
      paymentMode: json['paymentMode'],
      tipAmount: json['tipAmount']?.toDouble(),
      notes: json['notes'],
      deliveryOtp: json['deliveryOtp'] as String?,
      owesCash: json['owesCash'] == true,
      needsStart: json['needsStart'] == true,
    );
  }
}

/// Model for document upload data stored offline
class DocumentUploadData {
  final String documentType;
  final String driverId;
  final String localFilePath;
  final DateTime createdAt;

  DocumentUploadData({
    required this.documentType,
    required this.driverId,
    required this.localFilePath,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'documentType': documentType,
    'driverId': driverId,
    'localFilePath': localFilePath,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DocumentUploadData.fromJson(Map<String, dynamic> json) {
    return DocumentUploadData(
      documentType: json['documentType'],
      driverId: json['driverId'],
      localFilePath: json['localFilePath'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final String message;
  final int syncedTrips;
  final int syncedDocs;
  final List<String> errors;

  SyncResult({
    required this.success,
    required this.message,
    this.syncedTrips = 0,
    this.syncedDocs = 0,
    this.errors = const [],
  });
}

/// Widget to show sync status
class SyncStatusWidget extends StatelessWidget {
  const SyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final offlineService = Get.find<OfflineService>();
    
    return Obx(() {
      if (offlineService.pendingCount.value == 0) {
        return const SizedBox.shrink();
      }
      
      return GestureDetector(
        onTap: () => offlineService.syncPendingData(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: offlineService.isSyncing.value
                ? Colors.blue.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: offlineService.isSyncing.value
                  ? Colors.blue
                  : Colors.orange,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (offlineService.isSyncing.value)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 16,
                  color: Colors.orange,
                ),
              const SizedBox(width: 6),
              Text(
                offlineService.isSyncing.value
                    ? 'Syncing...'
                    : '${offlineService.pendingCount.value} pending',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: offlineService.isSyncing.value
                      ? Colors.blue
                      : Colors.orange,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
