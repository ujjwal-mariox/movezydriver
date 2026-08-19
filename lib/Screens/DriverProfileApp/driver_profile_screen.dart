import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Screens/MyProfileScreen/Model/driver_profile_bundle.dart';
import 'package:movezy_driver_app/Screens/MyProfileScreen/my_profile_api_service.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/ImageQualityValidator/image_quality_validator.dart';
import 'package:movezy_driver_app/Screens/CropScreen/crop_screen.dart';
import 'package:movezy_driver_app/Screens/DriverProfileApp/my_badge_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  final DriverProfileBundle? initialProfile;

  const DriverProfileScreen({super.key, this.initialProfile});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  static const Color subtitleGray = Color(0xFF8C9098);
  final MyProfileApiService _apiService = MyProfileApiService();
  final NumberFormat _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  DriverProfileBundle? _profile;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  String _error = '';
  List<Map<String, dynamic>> _badges = [];
  bool _badgesLoading = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    _isLoading = widget.initialProfile == null;
    if (widget.initialProfile == null) {
      _loadProfile();
    }
    _fetchBadges();
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
        _error = 'Unable to load profile details right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text('take_photo'.tr),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('choose_gallery'.tr),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final pickedFile = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    // Validate image quality
    final qualityResult = await ImageQualityValidator.validate(File(pickedFile.path));
    if (!qualityResult.isAcceptable) {
      if (mounted) {
        await ImageQualityValidator.showQualityDialog(context, qualityResult);
      }
      return;
    }

    // Navigate to crop screen
    if (!mounted) return;
    final croppedPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CropScreen(
          title: 'Profile Photo',
          file: File(pickedFile.path),
        ),
      ),
    );
    if (croppedPath == null || !mounted) return;

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      final updatedPhotoUrl = await _apiService.uploadProfilePhoto(File(croppedPath));
      if (!mounted) return;
      setState(() {
        _profile = _profile?.copyWith(
          profilePhoto: updatedPhotoUrl.isEmpty
              ? _profile?.profilePhoto
              : updatedPhotoUrl,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile_updated'.tr)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _fetchBadges() async {
    setState(() => _badgesLoading = true);
    try {
      final response = await http.get(
        Uri.parse(ApiUrls.driverBadgesUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'];
        if (data is List) {
          setState(() {
            _badges = List<Map<String, dynamic>>.from(data);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching badges: $e');
    } finally {
      if (mounted) setState(() => _badgesLoading = false);
    }
  }

  Future<void> _refreshAll() async {
    await _loadProfile();
    await _fetchBadges();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: AppColors.appColor,
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _topBar(),
              if (_isLoading && _profile == null)
                Padding(
                  padding: EdgeInsets.only(top: 120),
                  child: CircularProgressIndicator(color: AppColors.appColor),
                )
              else if (_profile == null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
                  child: Column(
                    children: [
                      Text(
                        _error.isEmpty ? 'Profile not available' : _error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadProfile,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.appColor),
                        child: Text('retry'.tr),
                      ),
                    ],
                  ),
                )
              else
                _body(_profile!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return commonAppBar(
      height: 100,
      context: context,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context, _profile),
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
              if (_profile != null)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star_rounded,
                          color: AppColors.appColor, size: 18),
                      const SizedBox(width: 3),
                      Text(
                        _profile!.rating.toStringAsFixed(1),
                        style: TextStyle(
                          color: AppColors.appColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(DriverProfileBundle profile) {
    return Column(
      children: [
        const SizedBox(height: 20),
        _avatar(profile.profilePhoto),
        const SizedBox(height: 14),
        Text(
          profile.fullName.isEmpty ? 'Driver' : profile.fullName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Driving Since ${_formatJoinedDate(profile.createdAt)}',
          style: const TextStyle(fontSize: 12, color: subtitleGray),
        ),
        const SizedBox(height: 4),
        Text(
          '${profile.countryCode} ${profile.mobileNumber}',
          style: const TextStyle(fontSize: 12, color: subtitleGray),
        ),
        if (profile.languages.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: profile.languages.map((language) => _chip(language)).toList(),
          ),
        ],
        const SizedBox(height: 12),
        _strip(),
        const SizedBox(height: 12),
        _sectionHeader('Earning & Rides', _yearLabel()),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 18),
          child: Column(
            children: [
              Text(
                _money.format(profile.stats.totalEarnings),
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  color: HexColor('#08875D'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MiniInfo(
                    title: 'Total Trips',
                    value: profile.stats.totalTrips.toString(),
                  ),
                  const SizedBox(width: 10),
                  _MiniInfo(
                    title: 'Total Driving Hrs',
                    value: _hoursLabel(profile.stats.totalDurationMin),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _strip(),
        const SizedBox(height: 12),
        _sectionHeader('Badges', 'my_badge'.tr,
            onTrailingTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MyBadgeScreen()),
                )),
        const SizedBox(height: 12),
        if (_badgesLoading && _badges.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )),
          )
        else if (_badges.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('no_badges'.tr, style: const TextStyle(color: Color(0xFF8C9098), fontSize: 13))),
          )
        else
          SizedBox(
            height: 192,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _badges.length,
              separatorBuilder: (_, _) => const SizedBox(width: 28),
              itemBuilder: (_, i) => _badgeRing(_badges[i]),
            ),
          ),
        const SizedBox(height: 20),
        _strip(),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            children: [
              const Text(
                'Driving License',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Column(
                children: [
                  // DL Number hidden for privacy - show verified status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DL Status',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      // Reflect the REAL verification state. This badge was
                      // hardcoded to "DL Verified" for every driver, so an
                      // unverified/under-review driver saw a false claim.
                      Builder(builder: (_) {
                        final verified = profile.isKycVerified;
                        final color = verified
                            ? const Color(0xFF1F8B4C)
                            : const Color(0xFFB26A00);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                verified
                                    ? Icons.verified
                                    : Icons.hourglass_bottom,
                                color: color,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                verified ? 'DL Verified' : 'Under review',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (profile.license.number.trim().isNotEmpty)
                    LicenseRow(
                      label: 'DL Number',
                      // Masked to the last 4 (client spec: keep sensitive data
                      // hidden). Enough to confirm WHICH licence is on file
                      // without exposing the full number to shoulder-surfing;
                      // the verified badge above carries the status.
                      value: profile.license.number.trim().length > 4
                          ? '•••• ${profile.license.number.trim().substring(profile.license.number.trim().length - 4)}'
                          : '••••',
                    ),
                  LicenseRow(
                    label: 'DL Expiry Date',
                    value: _formatLicenseDate(profile.license.expiryDate),
                  ),
                  LicenseRow(
                    label: 'Experience',
                    value: _experienceLabel(profile.createdAt),
                  ),
                  LicenseRow(
                    label: 'City',
                    value: _displayValue(
                      [profile.city, profile.state]
                          .where((item) => item.trim().isNotEmpty)
                          .join(', '),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatar(String imageUrl) {
    final url = imageUrl.trim();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF3F6F8)),
          child: ClipOval(
            child: url.isEmpty
                ? const Icon(Icons.person_outline, size: 42, color: Colors.black54)
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.person_outline, size: 42, color: Colors.black54),
                    placeholder: (context, url) => Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: AppColors.appColor, strokeWidth: 2),
                      ),
                    ),
                  ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: InkWell(
            onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.appColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: _isUploadingPhoto
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  /// One badge as the design draws it: a 118px ring with the emoji inside, a
  /// small corner medallion, and title + subtitle beneath. Unlocked rings are
  /// green (orange for the KYC/profile badge); locked ones grey out.
  Widget _badgeRing(Map<String, dynamic> badge) {
    final unlocked = badge['isUnlocked'] == true;
    final name = (badge['name'] ?? '').toString();
    final isKycBadge = name.toLowerCase().contains('verif') ||
        (badge['code'] ?? '').toString().toUpperCase().contains('KYC');
    final ringColor = !unlocked
        ? HexColor('#D3DDE7')
        : isKycBadge
            ? AppColors.appColor
            : const Color(0xFF3CB882);

    return SizedBox(
      width: 130,
      child: Column(
        children: [
          SizedBox(
            width: 122,
            height: 122,
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 118,
                    height: 118,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ringColor, width: 2),
                    ),
                    child: Center(
                      child: Opacity(
                        opacity: unlocked ? 1 : 0.35,
                        child: Text(
                          (badge['icon'] ?? '🏆').toString(),
                          style: const TextStyle(fontSize: 48),
                        ),
                      ),
                    ),
                  ),
                ),
                if (unlocked)
                  Positioned(
                    top: 4,
                    right: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: ringColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check,
                          color: Colors.white, size: 16),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            (badge['progressLabel'] ?? '').toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: subtitleGray),
          ),
        ],
      ),
    );
  }

  Widget _strip() {
    return Container(
      height: 8,
      width: MediaQuery.of(context).size.width,
      color: HexColor('#D3DDE7').withValues(alpha: 0.40),
    );
  }

  Widget _sectionHeader(String title, String trailing,
      {VoidCallback? onTrailingTap}) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HexColor('#E1E6EF')),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(trailing,
              style: TextStyle(
                  fontSize: 13,
                  color: onTrailingTap != null
                      ? AppColors.appColor
                      : subtitleGray)),
          if (onTrailingTap != null) ...[
            const SizedBox(width: 3),
            Icon(Icons.chevron_right, size: 16, color: AppColors.appColor),
          ],
        ],
      ),
    );
    return Row(
      children: [
        const SizedBox(width: 25),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const Spacer(),
        onTrailingTap != null
            ? InkWell(onTap: onTrailingTap, child: pill)
            : pill,
        const SizedBox(width: 25),
      ],
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: HexColor('#F8FAFC'),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: HexColor('#E1E6EF')),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFF364B63), fontSize: 13),
      ),
    );
  }

  String _yearLabel() => DateFormat('yyyy').format(DateTime.now());

  String _formatJoinedDate(String raw) {
    final date = DateTime.tryParse(raw);
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy').format(date.toLocal());
  }

  String _formatLicenseDate(String raw) {
    final date = DateTime.tryParse(raw);
    if (date == null) return _displayValue(raw);
    return DateFormat('dd MMM yyyy').format(date.toLocal());
  }

  String _hoursLabel(int totalDurationMin) {
    final hours = totalDurationMin / 60;
    if (hours <= 0) return '0 Hrs';
    if (hours % 1 == 0) return '${hours.toInt()} Hrs';
    return '${hours.toStringAsFixed(1)} Hrs';
  }

  String _experienceLabel(String raw) {
    final date = DateTime.tryParse(raw);
    if (date == null) return '-';
    final now = DateTime.now();
    int months = (now.year - date.year) * 12 + now.month - date.month;
    if (now.day < date.day) months -= 1;
    if (months <= 0) return 'Less than 1 month';
    if (months < 12) return '$months month${months == 1 ? '' : 's'}';
    final years = months ~/ 12;
    final extraMonths = months % 12;
    if (extraMonths == 0) return '$years year${years == 1 ? '' : 's'}';
    return '$years year${years == 1 ? '' : 's'} $extraMonths month${extraMonths == 1 ? '' : 's'}';
  }

  String _displayValue(String value) => value.trim().isEmpty ? '-' : value;
}

class _MiniInfo extends StatelessWidget {
  final String title;
  final String value;

  const _MiniInfo({required this.title, required this.value});

  static const Color subtitleGray = Color(0xFF8C9098);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: HexColor('#E1E6EF')),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: subtitleGray, fontSize: 13)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class BadgeCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool isUnlocked;

  const BadgeCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.isUnlocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isUnlocked ? 1.0 : 0.45,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isUnlocked ? const Color(0xFFFFF7ED) : const Color(0xFFF3F6F8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked ? const Color(0xFFFFD6A5) : const Color(0xFFE1E6EF),
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563)),
            ),
            if (isUnlocked) ...[
              const SizedBox(height: 6),
              const Icon(Icons.check_circle, color: Color(0xFF08875D), size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class LicenseRow extends StatelessWidget {
  final String label;
  final String value;

  const LicenseRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF636B74),
                fontWeight: FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ':  $value',
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
