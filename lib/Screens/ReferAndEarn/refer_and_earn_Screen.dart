import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

class ReferAndEarnScreen extends StatefulWidget {
  const ReferAndEarnScreen({super.key});

  @override
  State<ReferAndEarnScreen> createState() => _ReferAndEarnScreenState();
}

class _ReferAndEarnScreenState extends State<ReferAndEarnScreen> {
  bool _loading = true;
  String _referralCode = '';
  int _referralCount = 0;
  double _totalEarnings = 0;
  int _referrerReward = 100;
  int _refereeReward = 50;

  @override
  void initState() {
    super.initState();
    _fetchReferralStats();
  }

  Future<void> _fetchReferralStats() async {
    try {
      final response = await http.get(
        Uri.parse(ApiUrls.driverReferralStatsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        setState(() {
          _referralCode = data['referralCode'] ?? '';
          _referralCount = data['referralCount'] ?? 0;
          _totalEarnings = (data['totalEarnings'] ?? 0).toDouble();
          _referrerReward = data['referrerRewardAmount'] ?? 100;
          _refereeReward = data['refereeRewardAmount'] ?? 50;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Error fetching referral stats: $e');
      setState(() => _loading = false);
    }
  }

  void _copyCode() {
    if (_referralCode.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _referralCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('referral_copied'.tr), duration: const Duration(seconds: 2)),
    );
  }

  void _shareCode() {
    if (_referralCode.isEmpty) return;
    SharePlus.instance.share(
      ShareParams(
        text: 'Join Movezy as a driver using my referral code: $_referralCode and earn ₹$_refereeReward! Download the app now.',
      ),
    );
  }

  /// Direct WhatsApp share - 1 tap sharing
  Future<void> _shareOnWhatsApp() async {
    if (_referralCode.isEmpty) return;
    final message = Uri.encodeComponent(
      'Join Movezy as a driver using my referral code: $_referralCode and earn ₹$_refereeReward! Download the app now.',
    );
    final whatsappUrl = Uri.parse('whatsapp://send?text=$message');
    
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to web WhatsApp if app not installed
      final webUrl = Uri.parse('https://wa.me/?text=$message');
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        // If both fail, use regular share
        _shareCode();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            commonAppBar(
                height: 110,
                context: context,
                child: Container(
                  padding: const EdgeInsets.only(top: 50),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.only(left: 16),
                          width: 40,
                          height: 35,
                          alignment: Alignment.center,
                          child: const Icon(Icons.arrow_back_ios, color: Colors.white),
                        ),
                      ),
                      const Text(
                        "Refer & Earn",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 15),
                    ],
                  ),
                )),
            _loading
                ? SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: const Center(child: CircularProgressIndicator()),
                  )
                // No fixed height: pinning this to the screen height capped the Stack's
                // Column below its own content on short devices, so it overflowed instead
                // of scrolling in the SingleChildScrollView above.
                : SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: Stack(
                      children: [
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            width: MediaQuery.of(context).size.width,
                            child: Image.asset(
                              "assets/refer_and_earn_r.png",
                              fit: BoxFit.cover,
                            )),
                        Column(
                          children: [
                            const SizedBox(height: 30),
                            Center(
                              child: Container(
                                margin: const EdgeInsets.only(left: 30, right: 30),
                                child: Text(
                                  "Invite your friends &\nEarn upto ${_referrerReward + _refereeReward}",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            // 30/30/30 everywhere flattened the design's rhythm:
                            // the illustration sits closer to the headline, and
                            // the stats card overlaps its base.
                            const SizedBox(height: 18),
                            Image.asset(
                              "assets/mobile_icon.png",
                              height: 180,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 4),
                            // Responsive width with equal side insets, as the
                            // design draws it. This was `width: 300` — a fixed
                            // size that left a wide gutter on a large phone and
                            // could not fit a narrow one, and the four Spacers
                            // divided whatever was left unevenly so the two
                            // halves never lined up against the centre rule.
                            // Expanded halves make each side exactly 50%.
                            Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.appColor,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "${_referralCount.toString().padLeft(2, '0')}\nReferrals",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 17,
                                          height: 1.35),
                                    ),
                                  ),
                                  Container(
                                      height: 40,
                                      width: 1.5,
                                      color: Colors.white),
                                  Expanded(
                                    child: Text(
                                      "₹${_totalEarnings.toStringAsFixed(0)}\nEarnings",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 17,
                                          height: 1.35),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),
                            // The 60%-black wrapper that used to sit here painted
                            // a dark band across the seam between the hero art
                            // and the white sheet — visible on any device where
                            // the sheet did not start exactly at the artwork's
                            // edge. The design has no such band.
                            SizedBox(
                              width: MediaQuery.of(context).size.width,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.only(
                                      topRight: Radius.circular(32),
                                      topLeft: Radius.circular(32)),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 20),
                                    Container(
                                      margin: const EdgeInsets.only(left: 20, right: 20),
                                      child: const Text(
                                        "How it works?",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    _howItWorksStep(
                                      "1",
                                      "Your friend gets ₹$_refereeReward added to their wallet",
                                      "When they sign up using your referral code",
                                    ),
                                    const SizedBox(height: 20),
                                    _howItWorksStep(
                                      "2",
                                      "You get ₹$_referrerReward added to your wallet",
                                      "When your friend signs up with your code",
                                    ),
                                    const SizedBox(height: 20),
                                    GestureDetector(
                                      onTap: _copyCode,
                                      child: Container(
                                        height: 50,
                                        margin: const EdgeInsets.only(left: 20, right: 20),
                                        decoration: BoxDecoration(
                                          color: HexColor("#FF6200").withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            const SizedBox(width: 10),
                                            // Expanded (taking over from the Spacer): as a bare Row
                                            // child this got unbounded width, so the server-driven
                                            // code could never ellipsize.
                                            Expanded(
                                              child: Text(
                                                "Referral Code: $_referralCode",
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            Image.asset("assets/copy.png",
                                                width: 27, height: 27),
                                            const SizedBox(width: 8),
                                            const Text(
                                              "Copy",
                                              style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(width: 12)
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 25),
                                    // WhatsApp Share Button - Prominent
                                    GestureDetector(
                                      onTap: _shareOnWhatsApp,
                                      // Full width with the same 20px margins
                                      // as the referral-code box above. The
                                      // fixed 280px width left this button
                                      // hugging the column's left edge while
                                      // everything around it spanned or
                                      // centred — the misalignment reported.
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                            left: 20, right: 20),
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF25D366),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF25D366).withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.chat, color: Colors.white, size: 24),
                                            SizedBox(width: 10),
                                            Text(
                                              "Share on WhatsApp",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Other Share Options
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        GestureDetector(
                                          onTap: _shareCode,
                                          child: Container(
                                            width: 160,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              border: Border.all(color: AppColors.appColor, width: 1.5),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Center(
                                              child: Text(
                                                "Other Apps",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.appColor,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  )
          ],
        ),
      ),
    );
  }

  Widget _howItWorksStep(String number, String title, String subtitle) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Row(
        children: [
          const SizedBox(width: 20),
          Container(
            height: 22,
            width: 22,
            decoration: BoxDecoration(
              color: AppColors.appColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
                child: Text(number,
                    style: const TextStyle(color: Colors.white, fontSize: 12))),
          ),
          const SizedBox(width: 10),
          Container(
            alignment: Alignment.center,
            width: MediaQuery.of(context).size.width - 80,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
