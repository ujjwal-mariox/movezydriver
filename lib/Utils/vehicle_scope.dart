import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// One vehicle at a time.
///
/// A partner with several vehicles sees the dashboard, earnings and trip
/// history for the vehicle that is currently active — the one taking
/// bookings. This holds the selection the partner makes from the chip in
/// those screens (a specific vehicle, or all of them) and turns it into the
/// query the server expects. With a single vehicle nothing is shown or sent.
class VehicleScopeOption {
  final String id;
  final String vehicleNumber;
  final bool isActive;
  final String status;

  const VehicleScopeOption({
    required this.id,
    required this.vehicleNumber,
    required this.isActive,
    required this.status,
  });

  factory VehicleScopeOption.fromJson(Map<String, dynamic> json) {
    return VehicleScopeOption(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      vehicleNumber: (json['vehicleNumber'] ?? '').toString(),
      isActive: json['isPrimary'] == true || json['isActive'] == true,
      status: (json['verificationStatus'] ?? '').toString(),
    );
  }
}

class VehicleScope {
  VehicleScope._();
  static final VehicleScope instance = VehicleScope._();

  /// Explicit selection; null = whatever the server treats as active.
  String? vehicleId;
  bool allVehicles = false;

  List<VehicleScopeOption> vehicles = const [];
  String? activeVehicleId;

  bool get hasChoice => vehicles.length > 1;

  Map<String, String> get queryParams {
    if (!hasChoice) return const {};
    if (allVehicles) return const {'allVehicles': 'true'};
    if (vehicleId != null) return {'vehicleId': vehicleId!};
    return const {};
  }

  String get label {
    if (allVehicles) return 'all_vehicles'.tr;
    final id = vehicleId ?? activeVehicleId;
    for (final v in vehicles) {
      if (v.id == id) return v.vehicleNumber;
    }
    return vehicles.isNotEmpty ? vehicles.first.vehicleNumber : '';
  }

  /// Called after every dashboard load — the server tells us which vehicle it
  /// scoped to, so the chip never disagrees with the numbers under it.
  void updateFromDashboard(
    List<VehicleScopeOption> list,
    String? activeId,
    String? scopedId,
  ) {
    vehicles = list;
    activeVehicleId = activeId;
    if (!allVehicles && scopedId != null && scopedId.isNotEmpty) {
      vehicleId = scopedId;
    }
    if (vehicleId != null && !vehicles.any((v) => v.id == vehicleId)) {
      vehicleId = null;
    }
  }

  /// Back to "follow the active vehicle" — used after the partner switches
  /// vehicles so every screen moves with them.
  void reset() {
    vehicleId = null;
    allVehicles = false;
  }
}

/// Returns true when the selection changed.
Future<bool> showVehicleScopeSheet(BuildContext context) async {
  final scope = VehicleScope.instance;
  final before = '${scope.vehicleId}|${scope.allVehicles}';
  await showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final current = scope.allVehicles ? 'ALL' : (scope.vehicleId ?? scope.activeVehicleId);
      Widget row({
        required String title,
        String? subtitle,
        required bool selected,
        required VoidCallback onTap,
        IconData icon = Icons.local_shipping_outlined,
      }) {
        return ListTile(
          leading: Icon(icon, color: selected ? Theme.of(ctx).primaryColor : Colors.grey.shade600),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: subtitle == null ? null : Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: selected ? Icon(Icons.check_circle, color: Theme.of(ctx).primaryColor) : null,
          onTap: onTap,
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('select_vehicle'.tr,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('vehicle_scope_hint'.tr,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ),
            const SizedBox(height: 8),
            ...scope.vehicles.map(
              (v) => row(
                title: v.vehicleNumber,
                subtitle: v.isActive ? 'active_vehicle'.tr : null,
                selected: !scope.allVehicles && v.id == current,
                onTap: () {
                  scope.allVehicles = false;
                  scope.vehicleId = v.id;
                  Navigator.pop(ctx);
                },
              ),
            ),
            row(
              title: 'all_vehicles'.tr,
              icon: Icons.layers_outlined,
              selected: scope.allVehicles,
              onTap: () {
                scope.allVehicles = true;
                scope.vehicleId = null;
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
  return before != '${scope.vehicleId}|${scope.allVehicles}';
}

/// Small pill showing which vehicle the screen is scoped to. Renders nothing
/// for partners with one vehicle.
class VehicleScopeChip extends StatelessWidget {
  final VoidCallback onChanged;
  final double trailingGap;
  final bool light;

  const VehicleScopeChip({
    super.key,
    required this.onChanged,
    this.trailingGap = 0,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    final scope = VehicleScope.instance;
    if (!scope.hasChoice) return const SizedBox.shrink();
    final fg = light ? Colors.white : const Color(0xFF1F2937);
    final bg = light ? Colors.white.withOpacity(0.18) : const Color(0xFFEEF2FF);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            if (await showVehicleScopeSheet(context)) onChanged();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: light ? Colors.white54 : const Color(0xFFC7D2FE)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_shipping_outlined, size: 14, color: fg),
                const SizedBox(width: 6),
                Text(
                  scope.label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
                ),
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down, size: 16, color: fg),
              ],
            ),
          ),
        ),
        if (trailingGap > 0) SizedBox(width: trailingGap),
      ],
    );
  }
}
