import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:movezy_driver_app/CommonWidgets/slider_button_widget.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/Model/driver_dashboard_response.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';

/// Presentation only: every action and booking value belongs to the existing page.
class PickupTripSheet extends StatefulWidget {
  final DashboardBooking booking;
  final bool isArriving;
  final String startTime;
  final VoidCallback onCall, onChat, onDirections, onHelp, onTicket, onCancel;
  final Future<void> Function() onArrived;
  final ValueChanged<double>? onExtentChanged;
  const PickupTripSheet({
    super.key,
    required this.booking,
    required this.startTime,
    required this.isArriving,
    required this.onCall,
    required this.onChat,
    required this.onDirections,
    required this.onHelp,
    required this.onTicket,
    required this.onCancel,
    required this.onArrived,
    this.onExtentChanged,
  });

  @override
  State<PickupTripSheet> createState() => _PickupTripSheetState();
}

class _PickupTripSheetState extends State<PickupTripSheet> {
  final _controller = DraggableScrollableController();
  double _extent = .42, _minimum = .24, _initial = .42, _viewportHeight = 1;
  bool _confirming = false;
  DashboardBooking get booking => widget.booking;
  bool get _collapsed => _extent < (_minimum + _initial) / 2;
  bool get _expanded => _extent >= _initial + (.85 - _initial) * .6;
  bool get _headingToPickup =>
      booking.status == 'ASSIGNED' || booking.status == 'DRIVER_ARRIVED';
  static String? _text(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ||
            ['null', 'undefined', 'nan'].contains(text.toLowerCase())
        ? null
        : text;
  }

  String? _money(double value) => value.isFinite && value >= 0
      ? NumberFormat.currency(
          locale: 'en_IN',
          symbol: '₹',
          decimalDigits: 0,
        ).format(value)
      : null;
  String get _tripEstimate => [
    if (booking.distanceKm.isFinite && booking.distanceKm > 0)
      'Trip ${booking.distanceKm.toStringAsFixed(1)} km',
    if (booking.durationMin > 0) 'Estimated ${booking.durationMin} min',
  ].join(' • ');
  String get _customer => _text(booking.customerName) ?? 'Customer';
  String get _address =>
      _text(_headingToPickup ? booking.pickup.address : booking.drop.address) ??
      _text(_headingToPickup ? booking.pickupAddress : booking.dropAddress) ??
      'Address unavailable';
  bool get _hasLoading =>
      booking.loadingUnloading != null &&
      _text(booking.loadingUnloading!.type) != null &&
      booking.loadingUnloading!.type != 'NONE';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animate(double target) {
    if (!_controller.isAttached) return;
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _toggle() => _animate(
    _expanded
        ? _initial
        : _collapsed
        ? _initial
        : .85,
  );
  void _expand() {
    if (!_expanded) _animate(.85);
  }

  void _endHandleDrag(DragEndDetails details) {
    if (!_controller.isAttached) return;
    final size = _controller.size;
    final velocity = details.primaryVelocity ?? 0;
    final stops = [_minimum, _initial, .85];
    final double target;
    if (velocity < -900) {
      target = .85;
    } else if (velocity > 900) {
      target = _minimum;
    } else if (velocity < -150) {
      target = stops.firstWhere((s) => s > size + .02, orElse: () => .85);
    } else if (velocity > 150) {
      target = stops.reversed.firstWhere(
        (s) => s < size - .02,
        orElse: () => _minimum,
      );
    } else {
      target = stops.reduce(
        (a, b) => (a - size).abs() < (b - size).abs() ? a : b,
      );
    }
    _animate(target);
  }

  Future<void> _arrive() async {
    if (_confirming || widget.isArriving) return;
    setState(() => _confirming = true);
    try {
      await widget.onArrived();
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _viewportHeight = constraints.maxHeight;
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final ctaHeight = math.max(
        56.0,
        MediaQuery.textScalerOf(context).scale(16) * 2 + 16,
      );
      final bottomInset = MediaQuery.paddingOf(context).bottom;
      // Short screens / large fonts still reserve room for the handle and CTA.
      _minimum = math
          .max(.24, (ctaHeight + bottomInset + 76) / _viewportHeight)
          .clamp(.24, .65)
          .toDouble();
      _initial = math.max(.42, _minimum + .06).clamp(.42, .74).toDouble();
      if (!_controller.isAttached) _extent = _initial;
      return NotificationListener<DraggableScrollableNotification>(
        onNotification: (notification) {
          setState(() => _extent = notification.extent);
          widget.onExtentChanged?.call(notification.extent);
          return false;
        },
        child: DraggableScrollableSheet(
          key: const ValueKey('pickup-trip-sheet'),
          controller: _controller,
          initialChildSize: _initial,
          minChildSize: _minimum,
          maxChildSize: .85,
          snap: true,
          snapSizes: [_initial],
          snapAnimationDuration: const Duration(milliseconds: 240),
          builder: (context, scrollController) => Material(
            key: const ValueKey('pickup-sheet-surface'),
            color: Colors.white,
            elevation: 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Semantics(
                  button: true,
                  label: _expanded
                      ? 'Show less booking information'
                      : 'Expand booking information',
                  child: GestureDetector(
                    key: const ValueKey('pickup-sheet-handle'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggle,
                    onVerticalDragUpdate: (details) {
                      if (_controller.isAttached) {
                        _controller.jumpTo(
                          (_controller.size -
                                  details.delta.dy / _viewportHeight)
                              .clamp(_minimum, .85),
                        );
                      }
                    },
                    onVerticalDragEnd: _endHandleDrag,
                    child: SizedBox(
                      height: 44,
                      width: double.infinity,
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    key: const ValueKey('pickup-sheet-scroll'),
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: _expanded ? _details() : _essentials(scale),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottomInset),
                  child: _confirming || widget.isArriving
                      ? SizedBox(
                          key: const ValueKey('pickup-arrival-busy'),
                          height: ctaHeight,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : SliderButtonWidget(
                          key: const ValueKey('pickup-arrival-action'),
                          text: 'at_pickup'.tr,
                          height: ctaHeight,
                          arrowColor: AppColors.appColor,
                          backgroundColor: AppColors.appColor,
                          onTap: _arrive,
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _customerRow({bool full = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Text(
          _customer,
          maxLines: full ? null : 2,
          overflow: full ? null : TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(width: 4),
      IconButton(
        key: const ValueKey('pickup-call'),
        tooltip: 'Call customer',
        onPressed: widget.onCall,
        icon: Icon(Icons.call_outlined, color: AppColors.appColor),
      ),
      IconButton(
        key: const ValueKey('pickup-chat'),
        tooltip: 'Chat with customer',
        onPressed: widget.onChat,
        icon: Icon(Icons.chat_bubble_outline, color: AppColors.appColor),
      ),
    ],
  );

  List<Widget> _essentials(double scale) => [
    GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _expand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _headingToPickup ? 'pickup'.tr.toUpperCase() : 'DROP',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.appColor,
                      ),
                    ),
                    if (!_collapsed) ...[
                      const SizedBox(height: 4),
                      Text(
                        _address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!_collapsed)
                IconButton(
                  key: const ValueKey('pickup-directions'),
                  tooltip: 'get_directions'.tr,
                  onPressed: widget.onDirections,
                  icon: Icon(
                    Icons.navigation_outlined,
                    color: AppColors.appColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _tripEstimate.isEmpty ? 'Trip estimate unavailable' : _tripEstimate,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ],
      ),
    ),
    _customerRow(),
    if (!_collapsed) ...[
      if (_requirementSummary != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 20,
                color: AppColors.appColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _requirementSummary!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      _compactEarnings(),
    ],
  ];

  String? get _requirementSummary {
    final addons = booking.addons.where((a) => _text(a.name) != null).toList();
    if (addons.isNotEmpty) {
      final important = addons.firstWhere(
        (a) => RegExp(
          'load|pack|assist|helper',
          caseSensitive: false,
        ).hasMatch(a.name),
        orElse: () => addons.first,
      );
      return '${important.name}${important.quantity > 0 ? ' ×${important.quantity}' : ''}${addons.length > 1 ? ' · +${addons.length - 1} more' : ''}';
    }
    return _hasLoading
        ? booking.loadingUnloading!.type.replaceAll('_', ' ')
        : null;
  }

  Widget _compactEarnings() {
    final known =
        booking.estimatedEarnings.isFinite && booking.estimatedEarnings > 0;
    final amount = _money(
      known ? booking.estimatedEarnings : booking.estimatedFare,
    );
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (amount != null)
          Text(
            '$amount ${known ? 'earnings' : 'trip value · earnings pending'}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        if (_text(booking.paymentMethod) != null)
          Chip(
            label: Text(booking.paymentMethod.replaceAll('_', ' ')),
            visualDensity: VisualDensity.compact,
            backgroundColor: const Color(0xFFF3F4F6),
            side: BorderSide.none,
          ),
      ],
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.black54,
      ),
    ),
  );
  Widget _valueRow(String label, String? value) => value == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 310 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(label, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              );
            },
          ),
        );

  List<Widget> _details() => [
    const Text(
      'Booking Details',
      key: ValueKey('pickup-trip-expanded'),
      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
    ),
    if (_text(booking.bookingNumber) != null)
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('#${booking.bookingNumber}'),
      ),
    Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        [
          if (_text(booking.serviceType) != null)
            booking.serviceType == 'OUTSTATION' ? 'Outstation' : 'Within City',
          if (_text(booking.vehicleTypeName) != null) booking.vehicleTypeName,
        ].join(' • '),
        style: const TextStyle(color: Colors.black54),
      ),
    ),
    if (_text(booking.status) != null)
      _valueRow('Status', booking.status.replaceAll('_', ' ')),
    if (_text(widget.startTime) != null && widget.startTime != '--')
      _valueRow('Start time', widget.startTime),
    _section('CUSTOMER'),
    _customerRow(full: true),
    _section('pickup'.tr.toUpperCase()),
    Text(
      _text(booking.pickup.address) ??
          _text(booking.pickupAddress) ??
          'Address unavailable',
      style: const TextStyle(fontSize: 16, height: 1.4),
    ),
    TextButton.icon(
      key: const ValueKey('pickup-directions'),
      onPressed: widget.onDirections,
      icon: const Icon(Icons.navigation_outlined),
      label: Text('get_directions'.tr),
    ),
    _section('DROP'),
    Text(
      _text(booking.drop.address) ??
          _text(booking.dropAddress) ??
          'Address unavailable',
      style: const TextStyle(fontSize: 16, height: 1.4),
    ),
    for (var i = 0; i < booking.stops.length; i++) ...[
      _section('STOP ${i + 1}'),
      Text(_text(booking.stops[i].address) ?? 'Address unavailable'),
    ],
    if (_tripEstimate.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(_tripEstimate),
      ),
    if (_text(booking.goodsType) != null ||
        _text(booking.goodsDescription) != null) ...[
      _section('PARCEL'),
      if (_text(booking.goodsType) != null)
        Text(
          booking.goodsType,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      if (_text(booking.goodsDescription) != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(booking.goodsDescription),
        ),
    ],
    if (booking.addons.isNotEmpty || _hasLoading) ...[
      _section('addon_services'.tr.toUpperCase()),
      for (final addon in booking.addons) ...[
        Text(
          _text(addon.name) ?? 'Add-on service',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        _valueRow(
          addon.quantity > 0 ? 'Quantity ${addon.quantity}' : 'Price',
          _money(addon.price),
        ),
      ],
      if (_hasLoading) ...[
        Text(booking.loadingUnloading!.type.replaceAll('_', ' ')),
        if (booking.loadingUnloading!.pickupFloor != null)
          _valueRow('Pickup floor', '${booking.loadingUnloading!.pickupFloor}'),
        if (booking.loadingUnloading!.dropFloor != null)
          _valueRow('Drop floor', '${booking.loadingUnloading!.dropFloor}'),
        _valueRow(
          'Loading / unloading charge',
          _money(booking.loadingUnloading!.charge),
        ),
      ],
    ],
    _section('FARE DETAILS'),
    _valueRow(
      'customer_pays'.tr,
      _money(
        booking.customerTotal > 0
            ? booking.customerTotal
            : booking.estimatedFare,
      ),
    ),
    if (booking.gstAmount > 0) _valueRow('GST', _money(booking.gstAmount)),
    if (booking.commissionAmount > 0 || booking.commissionPercent > 0)
      _valueRow('commission'.tr, _money(booking.commissionAmount)),
    if (booking.estimatedEarnings.isFinite && booking.estimatedEarnings > 0)
      _valueRow('your_estimated_earnings'.tr, _money(booking.estimatedEarnings))
    else
      const Text('Estimated earnings pending'),
    if (booking.addonTotal > 0)
      _valueRow('Included add-on value', _money(booking.addonTotal)),
    if (_text(booking.paymentMethod) != null)
      _valueRow('payment'.tr, booking.paymentMethod.replaceAll('_', ' ')),
    const Divider(height: 32),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton.icon(
          key: const ValueKey('pickup-help'),
          onPressed: widget.onHelp,
          icon: const Icon(Icons.help_outline),
          label: Text('help_support'.tr),
        ),
        TextButton.icon(
          key: const ValueKey('pickup-ticket'),
          onPressed: widget.onTicket,
          icon: const Icon(Icons.support_agent),
          label: Text('raise_ticket'.tr),
        ),
      ],
    ),
    if (_headingToPickup)
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const ValueKey('pickup-cancel'),
          onPressed: widget.onCancel,
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          icon: const Icon(Icons.close),
          label: Text('cancel_booking'.tr),
        ),
      ),
  ];
}
