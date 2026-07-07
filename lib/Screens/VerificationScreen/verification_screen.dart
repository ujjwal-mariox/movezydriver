import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/CommonWidgets/button_widget.dart';
import 'package:movezy_driver_app/Screens/ChatScreen/chat_screen.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/technician_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen>
    with TickerProviderStateMixin {
  late AnimationController _gearController;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _gearController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    // Poll onboarding status so the driver advances automatically once approved
    // (previously this screen was static and never checked the backend).
    _checkStatus();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkStatus(),
    );
  }

  Future<void> _checkStatus() async {
    try {
      final response = await http.get(
        Uri.parse(ApiUrls.onboardingStatusUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return;

      final body = json.decode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      final status = (data?['driver']?['status'] ?? '').toString();

      // active/approved → onboarding done, go to the dashboard.
      if (status == 'active' || status == 'approved') {
        _statusTimer?.cancel();
        if (mounted) {
          replaceRoute(context, TechnicianDashboard());
        }
      }
    } catch (_) {
      // Transient errors are fine — the next poll retries.
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _gearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FA),
      body: Column(
        children: [
          // App bar
          Container(
            height: 95,
            padding: const EdgeInsets.only(top: 38),
            color: AppColors.appColor,
            child: Center(
              child: Text(
                'verification'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          // Grey banner area
          Container(
            width: 312,
            height: 136,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Image.asset(
                'assets/app_icon.png',
                height: 80,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.local_shipping,
                  size: 60,
                  color: AppColors.appColor,
                ),
              ),
            ),
          ),

          const Spacer(flex: 2),

          // Animated gears
          SizedBox(
            height: 160,
            width: 200,
            child: AnimatedBuilder(
              animation: _gearController,
              builder: (context, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Large gear with person icon
                    Positioned(
                      left: 20,
                      top: 10,
                      child: Transform.rotate(
                        angle: _gearController.value * 2 * pi,
                        child: _buildGear(90, withPerson: true),
                      ),
                    ),
                    // Small gear (rotates opposite)
                    Positioned(
                      right: 25,
                      bottom: 15,
                      child: Transform.rotate(
                        angle: -_gearController.value * 2 * pi,
                        child: _buildGear(60, withPerson: false),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // "Verification is Under Process" with info icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    'verification_under_process'.tr,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.info_outline, size: 20, color: Colors.grey.shade500),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50),
            child: Text(
              'verification_under_process_desc'.tr,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 24),

          // Verification timeline (12–24 hrs)
          _buildTimeline(),

          const Spacer(flex: 2),

          // Track Application Status button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: ButtonWidget(
              onTap: () => _showApplicationStatusSheet(context),
              borderRadius: BorderRadius.circular(12),
              text: 'track_application_status'.tr,
              backgroundColor: AppColors.appColor,
            ),
          ),

          const SizedBox(height: 12),

          // Chat with Staff button (secondary)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: ButtonWidget(
              onTap: () => pushTo(
                context,
                const ChatScreen(
                  bookingId: 'support',
                  customerName: 'Movezy Support',
                ),
              ),
              borderRadius: BorderRadius.circular(12),
              text: 'chat_with_staff'.tr,
              backgroundColor: Colors.transparent,
              textStyle: TextStyle(
                color: AppColors.appColor,
                fontWeight: FontWeight.w600,
              ),
              border: Border.all(color: AppColors.appColor, width: 1.4),
            ),
          ),

          const SizedBox(height: 24),

          // Bottom grey area
          Container(
            width: double.infinity,
            height: 121,
            color: const Color(0xFFF5F5F5),
          ),
        ],
      ),
    );
  }

  Widget _buildGear(double size, {required bool withPerson}) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GearPainter(withPerson: withPerson),
    );
  }

  Future<void> _showApplicationStatusSheet(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ApplicationStatusSheet(),
    );
  }

  Widget _buildTimeline() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6ECF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 18, color: AppColors.appColor),
              const SizedBox(width: 8),
              Text(
                'verification_eta'.tr,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTimelineStep(
            label: 'timeline_submitted'.tr,
            sub: 'timeline_submitted_sub'.tr,
            state: _TimelineState.done,
            isFirst: true,
          ),
          _buildTimelineStep(
            label: 'timeline_under_review'.tr,
            sub: 'timeline_under_review_sub'.tr,
            state: _TimelineState.active,
          ),
          _buildTimelineStep(
            label: 'timeline_approved'.tr,
            sub: 'timeline_approved_sub'.tr,
            state: _TimelineState.pending,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required String label,
    required String sub,
    required _TimelineState state,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final Color dotColor;
    final Widget dotChild;
    switch (state) {
      case _TimelineState.done:
        dotColor = const Color(0xFF2ECC71);
        dotChild = const Icon(Icons.check, size: 14, color: Colors.white);
        break;
      case _TimelineState.active:
        dotColor = AppColors.appColor;
        dotChild = const SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
        break;
      case _TimelineState.pending:
        dotColor = const Color(0xFFD1D8E0);
        dotChild = const SizedBox.shrink();
        break;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 4,
                  height: 6,
                  color: isFirst ? Colors.transparent : const Color(0xFFD1D8E0),
                ),
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                  child: dotChild,
                ),
                Expanded(
                  child: Container(
                    width: 4,
                    color: isLast ? Colors.transparent : const Color(0xFFD1D8E0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 6, bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: state == _TimelineState.pending
                          ? Colors.grey.shade500
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _TimelineState { done, active, pending }

class _ApplicationStatusSheet extends StatefulWidget {
  const _ApplicationStatusSheet();

  @override
  State<_ApplicationStatusSheet> createState() => _ApplicationStatusSheetState();
}

class _ApplicationStatusSheetState extends State<_ApplicationStatusSheet> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _driver;
  Map<String, dynamic>? _kyc;
  List<dynamic> _vehicles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await http.get(
        Uri.parse(ApiUrls.onboardingStatusUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'unable_to_load_status'.tr;
        });
        return;
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      setState(() {
        _loading = false;
        _driver = data?['driver'] as Map<String, dynamic>?;
        _kyc = data?['kyc'] as Map<String, dynamic>?;
        _vehicles = (data?['vehicles'] as List?) ?? [];
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'unable_to_load_status'.tr;
      });
    }
  }

  double get _overallProgress {
    if (_driver == null) return 0;
    int done = 0;
    int total = 0;

    // Personal info
    total++;
    if ((_driver?['fullName'] ?? '').toString().isNotEmpty) done++;

    // KYC items
    final aadhaar = _kyc?['aadhaar'] as Map<String, dynamic>?;
    final pan = _kyc?['pan'] as Map<String, dynamic>?;
    final license = _kyc?['drivingLicense'] as Map<String, dynamic>?;
    final selfie = _kyc?['selfie'];

    total += 4;
    if (aadhaar != null && (aadhaar['frontImage'] ?? '').toString().isNotEmpty) done++;
    if (pan != null && (pan['frontImage'] ?? '').toString().isNotEmpty) done++;
    if (selfie != null && selfie.toString().isNotEmpty) done++;
    if (license != null && (license['frontImage'] ?? '').toString().isNotEmpty) done++;

    // Vehicles
    if (_vehicles.isNotEmpty) {
      total++;
      done++;
      total++;
      final allPaid = _vehicles.every((v) => (v as Map)['onboardingFeePaid'] == true);
      if (allPaid) done++;
    } else {
      total += 2;
    }

    // Verification approval
    total++;
    final status = (_driver?['status'] ?? '').toString();
    if (status == 'active' || status == 'approved') done++;

    return done / total;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'application_status'.tr,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close, size: 22),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.error_outline,
                                      color: Colors.grey.shade400, size: 40),
                                  const SizedBox(height: 12),
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 16),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _loading = true;
                                        _error = null;
                                      });
                                      _load();
                                    },
                                    child: Text('retry'.tr),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _buildContent(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ScrollController controller) {
    final status = (_driver?['status'] ?? '').toString();
    final isApproved = status == 'active' || status == 'approved';
    final isRejected = status == 'rejected';

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        // Overall progress bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'overall_progress'.tr,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(_overallProgress * 100).round()}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.appColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _overallProgress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.appColor),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isApproved
                    ? 'application_approved_msg'.tr
                    : isRejected
                        ? 'application_rejected_msg'.tr
                        : 'application_under_review_msg'.tr,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Personal Information section
        _buildSectionHeader('personal_information'.tr),
        _buildStatusRow(
          label: 'owner_name'.tr,
          ok: (_driver?['fullName'] ?? '').toString().isNotEmpty,
        ),
        _buildStatusRow(
          label: 'aadhaar_card'.tr,
          ok: (_kyc?['aadhaar']?['frontImage'] ?? '').toString().isNotEmpty,
        ),
        _buildStatusRow(
          label: 'pan_card'.tr,
          ok: (_kyc?['pan']?['frontImage'] ?? '').toString().isNotEmpty,
        ),
        _buildStatusRow(
          label: 'selfie'.tr,
          ok: (_kyc?['selfie'] ?? '').toString().isNotEmpty,
        ),
        _buildStatusRow(
          label: 'driving_license'.tr,
          ok: (_kyc?['drivingLicense']?['frontImage'] ?? '').toString().isNotEmpty,
        ),

        const SizedBox(height: 20),

        // Vehicles section
        _buildSectionHeader(
          '${'vehicles'.tr} (${_vehicles.length})',
        ),
        if (_vehicles.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'no_vehicles_added'.tr,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          )
        else
          ..._vehicles.map((v) => _buildVehicleRow(v as Map<String, dynamic>)),

        const SizedBox(height: 20),

        // Verification section
        _buildSectionHeader('verification'.tr),
        _buildStatusRow(
          label: 'admin_review'.tr,
          ok: isApproved,
          inProgress: !isApproved && !isRejected,
          rejected: isRejected,
        ),
        if (isRejected &&
            (_driver?['rejectionReason'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEECEC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFFD9534F), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _driver!['rejectionReason'].toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFD9534F),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildStatusRow({
    required String label,
    required bool ok,
    bool inProgress = false,
    bool rejected = false,
  }) {
    final IconData icon;
    final Color color;
    final String statusText;
    if (rejected) {
      icon = Icons.cancel;
      color = const Color(0xFFD9534F);
      statusText = 'rejected'.tr;
    } else if (ok) {
      icon = Icons.check_circle;
      color = const Color(0xFF2ECC71);
      statusText = 'completed'.tr;
    } else if (inProgress) {
      icon = Icons.access_time;
      color = AppColors.appColor;
      statusText = 'in_progress'.tr;
    } else {
      icon = Icons.radio_button_unchecked;
      color = Colors.grey.shade400;
      statusText = 'pending'.tr;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleRow(Map<String, dynamic> v) {
    final vehicleNumber = (v['vehicleNumber'] ?? '').toString();
    final feePaid = v['onboardingFeePaid'] == true;
    final verificationStatus = (v['verificationStatus'] ?? 'pending').toString();
    final assignedPhone = (v['assignedDriverPhone'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6ECF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping, size: 16),
              const SizedBox(width: 6),
              Text(
                vehicleNumber.isNotEmpty ? vehicleNumber : 'vehicle'.tr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (assignedPhone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${'driver_mobile'.tr}: $assignedPhone',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _buildBadge(
                label: feePaid ? 'fee_paid'.tr : 'fee_pending'.tr,
                color: feePaid
                    ? const Color(0xFF2ECC71)
                    : AppColors.appColor,
              ),
              const SizedBox(width: 6),
              _buildBadge(
                label: verificationStatus.replaceAll('_', ' '),
                color: verificationStatus == 'approved'
                    ? const Color(0xFF2ECC71)
                    : verificationStatus == 'rejected'
                        ? const Color(0xFFD9534F)
                        : AppColors.appColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _GearPainter extends CustomPainter {
  final bool withPerson;

  _GearPainter({required this.withPerson});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.7;
    final toothHeight = outerRadius * 0.2;
    final toothCount = 8;

    final paint = Paint()
      ..color = const Color(0xFF2ECC71)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFF27AE60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw gear teeth
    final path = Path();
    for (int i = 0; i < toothCount; i++) {
      final angle = (i / toothCount) * 2 * pi;
      final nextAngle = ((i + 0.5) / toothCount) * 2 * pi;
      final halfTooth = ((i + 0.25) / toothCount) * 2 * pi;
      final threeQuarterTooth = ((i + 0.75) / toothCount) * 2 * pi;

      if (i == 0) {
        path.moveTo(
          center.dx + innerRadius * cos(angle),
          center.dy + innerRadius * sin(angle),
        );
      }

      path.lineTo(
        center.dx + innerRadius * cos(angle),
        center.dy + innerRadius * sin(angle),
      );
      path.lineTo(
        center.dx + (innerRadius + toothHeight) * cos(halfTooth),
        center.dy + (innerRadius + toothHeight) * sin(halfTooth),
      );
      path.lineTo(
        center.dx + (innerRadius + toothHeight) * cos(threeQuarterTooth),
        center.dy + (innerRadius + toothHeight) * sin(threeQuarterTooth),
      );
      path.lineTo(
        center.dx + innerRadius * cos(nextAngle + (0.5 / toothCount) * 2 * pi),
        center.dy + innerRadius * sin(nextAngle + (0.5 / toothCount) * 2 * pi),
      );
    }
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, strokePaint);

    // Draw inner circle
    final innerCirclePaint = Paint()
      ..color = const Color(0xFF2ECC71).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius * 0.55, innerCirclePaint);

    // Draw center hole
    final holePaint = Paint()
      ..color = const Color(0xFFF0F5FA)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius * 0.2, holePaint);

    // Draw person icon if needed
    if (withPerson) {
      final personPaint = Paint()
        ..color = const Color(0xFF27AE60)
        ..style = PaintingStyle.fill;

      // Head
      canvas.drawCircle(
        Offset(center.dx, center.dy - innerRadius * 0.15),
        innerRadius * 0.12,
        personPaint,
      );

      // Body
      final bodyPath = Path();
      bodyPath.addArc(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + innerRadius * 0.1),
          width: innerRadius * 0.35,
          height: innerRadius * 0.3,
        ),
        pi,
        pi,
      );
      canvas.drawPath(bodyPath, personPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
