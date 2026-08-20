import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:intl/intl.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Screens/AwardsScreen/awards_screen.dart';
import 'package:movezy_driver_app/Screens/EarningsScreen/earnings_screen.dart';
import 'package:movezy_driver_app/Screens/BankDetailsScreen/bank_details_settings_screen.dart';
import 'package:movezy_driver_app/Screens/DriverProfileApp/driver_profile_screen.dart';
import 'package:movezy_driver_app/Screens/FaqScreen/faq_screen.dart';
import 'package:movezy_driver_app/Screens/HelpSupportScreen/help_support_screen.dart';
import 'package:movezy_driver_app/Screens/LanguageScreen/language_selection_screen.dart';
import 'package:movezy_driver_app/Screens/LoginScreen/login_screen.dart';
import 'package:movezy_driver_app/Screens/MyVehicles/my_vehicles.dart';
import 'package:movezy_driver_app/Screens/MyProfileScreen/Model/driver_profile_bundle.dart';
import 'package:movezy_driver_app/Screens/MyProfileScreen/my_profile_api_service.dart';
import 'package:movezy_driver_app/Screens/MyWallet/my_wallet_screen.dart';
import 'package:movezy_driver_app/Screens/ReferAndEarn/refer_and_earn_Screen.dart';
import 'package:movezy_driver_app/Screens/SupportChat/support_tickets_screen.dart';
import 'package:movezy_driver_app/Screens/TrainingScreen/training_screen.dart';
import 'package:movezy_driver_app/Screens/TripHistoryPage/trip_history_page.dart';
import 'package:movezy_driver_app/Screens/driver_instruction_screen/driver_instructions_screen.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/Auth/driver_logout.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final MyProfileApiService _apiService = MyProfileApiService();
  // Two decimals, matching the design and driver_profile_screen \u2014 which shows
  // the SAME lifetime total. At decimalDigits: 0 this strip rounded the paise
  // away, so the two screens disagreed about the driver's own earnings.
  final NumberFormat _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20B9',
    decimalDigits: 2,
  );

  DriverProfileBundle? _profile;
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final profile = await _apiService.getProfileBundle();
      if (!mounted) return;
      setState(() {
        _profile = profile;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load profile right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          commonAppBar(
            height: 170,
            context: context,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  children: [
                    _header(),
                    const SizedBox(height: 10),
                    _profileHeaderCard(),
                  ],
                ),
              ),
            ),
          ),
          _statsRow(),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              color: Colors.white,
              child: _content(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40,
            height: 35,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(left: 10),
            child: Image.asset('assets/back_arrow.png', color: Colors.white),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _profileHeaderCard() {
    if (_isLoading && _profile == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: SizedBox(
          height: 28,
          width: 28,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
        ),
      );
    }

    if (_profile == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error.isEmpty ? 'Profile not available' : _error,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _loadProfile,
              child: Text('retry'.tr, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final profile = _profile!;
    return InkWell(
      onTap: () async {
        final updated = await pushTo(
          context,
          DriverProfileScreen(initialProfile: profile),
        );
        if (updated is DriverProfileBundle && mounted) {
          setState(() {
            _profile = updated;
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _avatar(profile.profilePhoto),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.fullName.isEmpty ? 'Driver' : profile.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Show DL Verified badge instead of DL number
                  Row(
                    children: [
                      if (profile.isKycVerified) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F8B4C),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'DL Verified',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Rating badge
                      if (profile.rating > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                            const SizedBox(width: 2),
                            Text(
                              profile.rating.toStringAsFixed(1),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _statsRow() {
    final profile = _profile;
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: _topStat(
              'Total Earning',
              profile == null ? '--' : _money.format(profile.stats.totalEarnings),
            ),
          ),
          Container(height: 50, width: 1, color: Colors.grey[300]),
          Expanded(
            child: _topStat(
              'Total Trips',
              profile == null ? '--' : profile.stats.totalTrips.toString(),
            ),
          ),
          Container(height: 50, width: 1, color: Colors.grey[300]),
          Expanded(
            child: _topStat(
              'Total Login Hrs',
              profile == null ? '--' : _hoursLabel(profile.stats.totalDurationMin),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _topStat(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _content() {
    if (_isLoading && _profile == null) {
      return Center(child: CircularProgressIndicator(color: AppColors.appColor));
    }

    return RefreshIndicator(
      color: AppColors.appColor,
      onRefresh: _loadProfile,
      child: ListView(
        padding: const EdgeInsets.only(top: 0, bottom: 40),
        children: [
          // Earnings sits above the wallet: the wallet answers "what can I
          // withdraw", this answers "what have I earned and from what".
          _buildListTile('Earnings', 'assets/moneys.png', () {
            pushTo(context, const EarningsScreen());
          }, AppColors.appColor),
          _divider(),
          _buildListTile('history'.tr, 'assets/clock.png', () {
            pushTo(context, const TripHistoryPage());
          }, AppColors.appColor),
          _divider(),
          _buildListTile('my_wallet'.tr, 'assets/profile_circle.png', () {
            pushTo(context, const MyWalletScreen());
          }, AppColors.appColor),
          _divider(),
          _buildListTile('bank_details'.tr, 'assets/profile_circle.png', () {
            pushTo(context, const BankDetailsSettingsScreen());
          }, AppColors.appColor),
          _divider(),
          _buildListTile('my_vehicles'.tr, 'assets/task_square.png', () {
            pushTo(context, const MyVehiclesScreen(isOnboarding: false));
          }, AppColors.appColor),
          _divider(),
          _buildListTile('refer_and_earn'.tr, 'assets/share.png', () {
            pushTo(context, const ReferAndEarnScreen());
          }, AppColors.appColor),
          _divider(),
          _buildListTile('awards'.tr, 'assets/awards.png', () {
            pushTo(context, const AwardsScreen());
          }, null),
          _divider(),
          _buildListTile('training'.tr, 'assets/training.png', () {
            pushTo(context, const TrainingScreen());
          }, null,
              trailing: (_profile?.trainingComplete ?? false)
                  ? _doneBadge('Completed')
                  : null),
          _divider(),
          _buildListTile('help'.tr, 'assets/message_question.png', () {
            pushTo(context, const HelpSupportScreen());
          }, AppColors.appColor),
          _divider(),
          _buildListTile('Chat with Support', 'assets/message_question.png', () {
            pushTo(context, const SupportTicketsScreen());
          }, AppColors.appColor),
          _divider(),
          _buildListTile('faq'.tr, 'assets/message_question.png', () {
            pushTo(context, const FaqScreen());
          }, AppColors.appColor),
          _divider(),
          _buildListTile('language'.tr, 'assets/task_square.png', () {
            pushTo(context, const LanguageSelectionScreen());
          }, AppColors.appColor),
          _divider(),
          _buildListTile('driver_instructions'.tr, 'assets/task_square.png', () {
            pushTo(context, const DriverInstructionsScreen());
          }, AppColors.appColor,
              trailing: (_profile?.instructionsAcknowledged ?? false)
                  ? _doneBadge('Read')
                  : null),
          _divider(),
          ListTile(
            onTap: () async {
              // Shared routine: stops GPS/socket, tells the server we're offline
              // (so dispatch stops), and clears the token — none of which the
              // old inline logout did.
              await performDriverLogout();
              if (!mounted) return;
              replaceRoute(context, LoginScreen());
            },
            leading: SizedBox(
              height: 27,
              width: 27,
              child: Image.asset('assets/logout.png', fit: BoxFit.cover),
            ),
            title: Text(
              'logout'.tr,
              style: const TextStyle(fontSize: 13, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: HexColor('#94A3B3').withValues(alpha: 0.3),
    );
  }

  Widget _avatar(String imageUrl) {
    final url = imageUrl.trim();
    return Container(
      width: 50,
      height: 50,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
      child: ClipOval(
        child: url.isEmpty
            ? Container(
                color: Colors.white24,
                alignment: Alignment.center,
                child: const Icon(Icons.person_outline, color: Colors.white, size: 28),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  color: Colors.white24,
                  alignment: Alignment.center,
                  child: const Icon(Icons.person_outline, color: Colors.white, size: 28),
                ),
                placeholder: (context, url) => const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                ),
              ),
      ),
    );
  }

  /// Green "Completed" / "Read" pill for a one-off task that is already done.
  ///
  /// Training and Driver Instructions are both things a driver does ONCE, but
  /// the rows looked identical whether or not they had been done — so a driver
  /// had no way to tell, and would open them again to check. The state was on
  /// the server the whole time (mandatory-training progress, and
  /// instructionsAcknowledgedAt); it simply was not surfaced.
  Widget _doneBadge(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F6EC),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle,
                  size: 12, color: Color(0xFF1E9E52)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E9E52),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Icon(Icons.arrow_forward_ios, color: HexColor('#6B7280'), size: 16),
      ],
    );
  }

  Widget _buildListTile(
    String title,
    String icon,
    Function onTap,
    Color? color, {
    Widget? trailing,
  }) {
    return ListTile(
      onTap: () => onTap(),
      leading: SizedBox(
        height: 27,
        width: 27,
        child: Image.asset(icon, fit: BoxFit.cover, color: color),
      ),
      title: Text(title, style: const TextStyle(fontSize: 13)),
      trailing: trailing ??
          Icon(Icons.arrow_forward_ios, color: HexColor('#6B7280'), size: 16),
    );
  }

  String _hoursLabel(int totalDurationMin) {
    final hours = totalDurationMin / 60;
    if (hours <= 0) return '0 Hrs';
    if (hours % 1 == 0) return '${hours.toInt()} Hrs';
    return '${hours.toStringAsFixed(1)} Hrs';
  }
}
