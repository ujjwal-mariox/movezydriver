import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/CommonWidgets/network_indicator.dart';
import 'package:movezy_driver_app/CommonWidgets/panic_button.dart';
import 'package:movezy_driver_app/CommonWidgets/slider_button_widget.dart';
import 'package:movezy_driver_app/Screens/HelpSupportScreen/help_support_screen.dart';
import 'package:movezy_driver_app/Screens/VerifyRideScreen/verify_ride_screen.dart';
import 'package:movezy_driver_app/Screens/ChatScreen/chat_screen.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/dashboard_api_service.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/Model/driver_dashboard_response.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';

class BookingDetailPage extends StatefulWidget {
  final DashboardBooking booking;
  const BookingDetailPage({super.key, required this.booking});

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  final DashboardApiService _apiService = DashboardApiService();
  bool _isArriving = false;

  DashboardBooking get booking => widget.booking;

  LatLng get pickupLatLng => LatLng(booking.pickup.lat, booking.pickup.lng);
  LatLng get dropLatLng => LatLng(booking.drop.lat, booking.drop.lng);

  bool get _hasValidCoords =>
      booking.pickup.lat != 0 && booking.pickup.lng != 0 &&
      booking.drop.lat != 0 && booking.drop.lng != 0;

  LatLngBounds get _mapBounds {
    final minLat = booking.pickup.lat < booking.drop.lat ? booking.pickup.lat : booking.drop.lat;
    final maxLat = booking.pickup.lat > booking.drop.lat ? booking.pickup.lat : booking.drop.lat;
    final minLng = booking.pickup.lng < booking.drop.lng ? booking.pickup.lng : booking.drop.lng;
    final maxLng = booking.pickup.lng > booking.drop.lng ? booking.pickup.lng : booking.drop.lng;
    return LatLngBounds(
      LatLng(minLat - 0.01, minLng - 0.01),
      LatLng(maxLat + 0.01, maxLng + 0.01),
    );
  }

  /// Raise a real support ticket for this booking (the button was a
  /// non-interactive Container before — it did nothing).
  Future<void> _raiseTicket() async {
    final resp = await _apiService.raiseTicket(
      category: 'Order Issue',
      subject: 'Issue with booking ${booking.id}',
      message: 'Driver raised a ticket from the booking screen.',
      bookingId: booking.id,
    );
    if (!mounted) return;
    final ok = resp != null && (resp['code'] == 1 || resp['code'] == 200);
    Fluttertoast.showToast(
      msg: ok ? 'Ticket raised. Support will contact you.' : 'Could not raise ticket. Try again.',
    );
  }

  Future<void> _markArrived() async {
    setState(() => _isArriving = true);
    final resp = await _apiService.arrivedAtPickup(booking.id);
    if (!mounted) return;
    setState(() => _isArriving = false);

    if (resp != null && (resp['code'] == 1 || resp['code'] == 200)) {
      Fluttertoast.showToast(msg: 'marked_arrived'.tr);
      pushTo(
        context,
        VerifyRideScreen(
          bookingId: booking.id,
          bookingNumber: booking.bookingNumber,
          earnings: booking.estimatedFare.toStringAsFixed(0),
        ),
      );
    } else {
      Fluttertoast.showToast(msg: resp?['message']?.toString() ?? "Failed to mark arrived");
    }
  }

  Future<void> _openDirections() async {
    final lat = booking.pickup.lat;
    final lng = booking.pickup.lng;
    final uri = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callCustomer() async {
    final phone = booking.pickup.contactPhone;
    if (phone.isEmpty) {
      Fluttertoast.showToast(msg: 'no_contact_number'.tr);
      return;
    }
    final uri = Uri.parse("tel:$phone");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color cardBorder = Color(0xFFE6EEF2);
    String serviceLabel = booking.serviceType == "OUTSTATION" ? "Outstation" : "One Way";

    return Scaffold(
      backgroundColor: Colors.grey,
      body: Column(
        children: [
          const NetworkIndicator(),
          commonAppBar(
            height: 100,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.only(left: 16),
                      width: 40, height: 35,
                      alignment: Alignment.center,
                      child: Image.asset("assets/back_arrow.png", color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('on_route'.tr, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                // Map
                if (_hasValidCoords)
                  FlutterMap(
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(
                        bounds: _mapBounds,
                        padding: const EdgeInsets.all(60),
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.movezy.driver',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: pickupLatLng,
                            width: 40, height: 40,
                            child: const Icon(Icons.location_on, color: Colors.green, size: 36),
                          ),
                          Marker(
                            point: dropLatLng,
                            width: 40, height: 40,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 36),
                          ),
                        ],
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [pickupLatLng, dropLatLng],
                            color: AppColors.appColor,
                            strokeWidth: 3,
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Container(color: Colors.grey[300], child: Center(child: Text('map_not_available'.tr))),

                // Panic SOS button
                Positioned(
                  top: 16,
                  right: 16,
                  child: PanicButton(bookingId: booking.id),
                ),

                // Bottom panel
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                      color: Colors.white,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 6),
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(width: MediaQuery.of(context).size.width * 0.25),
                              Column(
                                children: [
                                  Text(serviceLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(booking.vehicleTypeName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
                                ],
                              ),
                              Container(width: MediaQuery.of(context).size.width * 0.03),
                              if (booking.bookingNumber.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.appColor, borderRadius: BorderRadius.circular(20)),
                                  child: Text("#${booking.bookingNumber}", style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Customer + Pickup info
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cardBorder),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
                            ),
                            child: Column(
                              children: [
                                // Status
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 27, width: 27,
                                      child: Image.asset("assets/clock.png", height: 27, width: 27, fit: BoxFit.cover, color: AppColors.appColor),
                                    ),
                                    const SizedBox(width: 10),
                                    Text('status'.tr, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 12)),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: HexColor("#64B161"),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(booking.status, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                                Container(margin: const EdgeInsets.symmetric(vertical: 10), color: Colors.grey, height: 0.4, width: MediaQuery.of(context).size.width - 50),
                                // Customer
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 27, width: 27,
                                      child: Image.asset("assets/profile_circle.png", height: 27, width: 27, fit: BoxFit.cover, color: AppColors.appColor),
                                    ),
                                    const SizedBox(width: 10),
                                    Text('customer'.tr, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 12)),
                                    const Spacer(),
                                    Flexible(child: Text(booking.customerName, style: TextStyle(color: HexColor("#364B63"), fontSize: 12), overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                                Container(margin: const EdgeInsets.symmetric(vertical: 10), color: Colors.grey, height: 0.4, width: MediaQuery.of(context).size.width - 50),
                                // Pickup address
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.place, color: AppColors.greenColor),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(booking.pickup.address, style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500))),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Drop address
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.place, color: Colors.red),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(booking.drop.address, style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Action buttons
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cardBorder),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 3))],
                            ),
                            child: Row(
                              children: [
                                _ActionTile(icon: Icons.call, label: 'contact'.tr, onTap: _callCustomer),
                                _ActionTile(
                                  icon: Icons.chat_bubble_outline,
                                  label: 'Chat',
                                  onTap: () => pushTo(
                                    context,
                                    ChatScreen(
                                      bookingId: booking.id,
                                      customerName: booking.customerName,
                                    ),
                                  ),
                                ),
                                _ActionTile(icon: Icons.directions, label: 'directions'.tr, onTap: _openDirections),
                              ],
                            ),
                          ),
                          const SizedBox(height: 7),

                          // Add-on services (if any)
                          if (booking.addons.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('addon_services'.tr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  ...booking.addons.map((addon) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle_outline, color: AppColors.appColor, size: 16),
                                        const SizedBox(width: 6),
                                        Expanded(child: Text(addon.name, style: const TextStyle(fontSize: 12))),
                                        Text("\u20B9${addon.price.toStringAsFixed(0)} x${addon.quantity}", style: TextStyle(fontSize: 12, color: AppColors.appColor, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  )),
                                  if (booking.loadingUnloading != null && booking.loadingUnloading!.type != "NONE") ...[
                                    const Divider(height: 12),
                                    Row(
                                      children: [
                                        const Icon(Icons.elevator, size: 16, color: Colors.grey),
                                        const SizedBox(width: 6),
                                        Text(booking.loadingUnloading!.type, style: const TextStyle(fontSize: 12)),
                                        const Spacer(),
                                        Text("\u20B9${booking.loadingUnloading!.charge.toStringAsFixed(0)}", style: TextStyle(fontSize: 12, color: AppColors.appColor, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 7),
                          ],

                          // Earnings card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: HexColor("#E1E6EF")),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.currency_rupee, color: AppColors.appColor, size: 20),
                                        const SizedBox(width: 4),
                                        Text(booking.estimatedFare.toStringAsFixed(0), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                    Text('your_estimated_earnings'.tr, style: const TextStyle(fontSize: 13, color: Colors.black)),
                                  ],
                                ),
                                if (booking.addonTotal > 0)
                                  Text("+\u20B9${booking.addonTotal.toStringAsFixed(0)}", style: TextStyle(color: AppColors.appColor, fontWeight: FontWeight.w600, fontSize: 14)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 7),

                          // Payment method
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: HexColor("#E1E6EF")),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.payment, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text('payment'.tr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const Spacer(),
                                Text(booking.paymentMethod, style: TextStyle(fontSize: 12, color: HexColor("#364B63"), fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 7),

                          // Help & Raise Ticket
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => pushTo(context, const HelpSupportScreen()),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 54,
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: cardBorder)),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.headset_mic, color: HexColor("#015EA3"), size: 24),
                                        const SizedBox(width: 8),
                                        Text('help_support'.tr, style: TextStyle(color: HexColor("#015EA3"), fontSize: 14, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: _raiseTicket,
                                  child: Container(
                                    height: 54,
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: cardBorder)),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Image.asset("assets/raise_ticket_icon.png", height: 24),
                                        const SizedBox(width: 8),
                                        Text('raise_ticket'.tr, style: const TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),

                          // At Pickup slider
                          _isArriving
                              ? Container(
                                  height: 50,
                                  decoration: BoxDecoration(color: AppColors.appColor, borderRadius: BorderRadius.circular(20)),
                                  child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
                                )
                              : SliderButtonWidget(
                                  text: 'at_pickup'.tr,
                                  arrowColor: AppColors.appColor,
                                  backgroundColor: AppColors.appColor,
                                  onTap: _markArrived,
                                ),
                          const SizedBox(height: 7),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const Color cardBorder = Color(0xFFE6EEF2);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: cardBorder, width: 1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.appColor, size: 30),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
