import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:movezy_driver_app/Utils/LocationService/location_tracking_service.dart';

class DelayedPermissions extends GeolocatorPlatform {
  final permission = Completer<LocationPermission>();

  @override
  Future<LocationPermission> checkPermission() => permission.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'going offline while startup waits for permissions cancels startup',
    () async {
      final previous = GeolocatorPlatform.instance;
      final permissions = DelayedPermissions();
      GeolocatorPlatform.instance = permissions;
      final service = LocationTrackingService.instance;
      addTearDown(() {
        service.stopTracking();
        GeolocatorPlatform.instance = previous;
      });

      final firstStart = service.startTracking();
      final duplicateStart = service.startTracking();
      expect(identical(firstStart, duplicateStart), isTrue);
      service.stopTracking();
      permissions.permission.complete(LocationPermission.whileInUse);

      expect(await firstStart, isFalse);
      expect(await duplicateStart, isFalse);
      expect(service.isTracking, isFalse);
    },
  );
}
