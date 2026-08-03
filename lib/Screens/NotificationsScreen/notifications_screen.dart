import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Screens/NotificationsScreen/notifications_service.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';

/// The driver's notification inbox — the destination behind the bell in the
/// bottom navigation. The API (list, unread count, mark-read) already existed;
/// there was simply no screen reading it.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<DriverNotification> _items = [];
  int _unread = 0;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await NotificationsService.fetch();
      if (!mounted) return;
      setState(() {
        _items = r.notifications;
        _unread = r.unreadCount;
        _loading = false;
        _error = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load notifications.';
      });
    }
  }

  Future<void> _markAll() async {
    final ok = await NotificationsService.markRead();
    if (ok) await _load();
  }

  Future<void> _open(DriverNotification n) async {
    if (!n.isRead) {
      await NotificationsService.markRead(id: n.id);
      await _load();
    }
  }

  /// Icon + tint per notification type, so a payout reads differently from a
  /// booking at a glance.
  (IconData, Color) _visual(String type) {
    switch (type) {
      case 'BOOKING':
        return (Icons.local_shipping_outlined, AppColors.appColor);
      case 'PAYMENT':
        return (Icons.account_balance_wallet_outlined, const Color(0xFF1F8B4C));
      case 'PROMO':
        return (Icons.local_offer_outlined, const Color(0xFF8B5CF6));
      case 'CHAT':
        return (Icons.chat_bubble_outline, const Color(0xFF0EA5E9));
      case 'REWARD':
        return (Icons.emoji_events_outlined, const Color(0xFFF59E0B));
      default:
        return (Icons.notifications_none_rounded, const Color(0xFF64748B));
    }
  }

  String _when(DateTime? at) {
    if (at == null) return '';
    final local = at.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(local);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: Column(
        children: [
          commonAppBar(
            height: 100,
            context: context,
            child: Padding(
              padding: EdgeInsets.only(
                  left: 8,
                  right: 16,
                  top: MediaQuery.of(context).padding.top + 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 20),
                  ),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (_unread > 0)
                    InkWell(
                      onTap: _markAll,
                      child: const Text('Mark all read',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return Center(
          child: CircularProgressIndicator(color: AppColors.appColor));
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.appColor,
                  foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_rounded,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No notifications yet',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.appColor,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final n = _items[i];
          final (icon, tint) = _visual(n.type);
          return InkWell(
            onTap: () => _open(n),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // Unread carries a faint tint so it stands out without a dot.
                color: n.isRead ? Colors.white : const Color(0xFFFFF6F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: n.isRead
                        ? const Color(0xFFE1E6EF)
                        : AppColors.appColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 19, color: tint),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                n.title.isEmpty ? 'Notification' : n.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: n.isRead
                                        ? FontWeight.w600
                                        : FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(_when(n.createdAt),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500)),
                          ],
                        ),
                        if (n.body.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            n.body,
                            style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: Colors.grey.shade700),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
