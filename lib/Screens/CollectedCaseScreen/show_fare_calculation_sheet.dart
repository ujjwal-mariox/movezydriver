import 'package:flutter/material.dart';

/// Shows the fare breakdown. Pass the completed booking (from completeTrip) so
/// the real fare components are shown instead of placeholder numbers.
Future<void> showFareCalculationSheet(BuildContext context, {Map<String, dynamic>? booking}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return FareCalculationSheet(booking: booking);
    },
  );
}

class FareCalculationSheet extends StatelessWidget {
  final Map<String, dynamic>? booking;
  const FareCalculationSheet({super.key, this.booking});

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  String _money(double v) => "₹${v.toStringAsFixed(2)}";

  /// Whole numbers read better on labels like "GST (5%)" / "Surge (x1.5)".
  String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    const darkBlue = Color(0xFF14233B);
    const dividerColor = Color(0xFFE6EEF2);

    // Real fare components from the booking; 0 when a component isn't present.
    //
    // The backend composes the fare as:
    //   subtotal  = base + distance + time + surge + add-ons (+ waiting/tolls
    //               when they were billed)
    //   finalFare = subtotal + GST − discounts
    // This receipt used to list GST and Discount ABOVE the Sub Total and left
    // add-on charges out altogether, so the rows never added up to either
    // total. Rows are now emitted in the order the server sums them.
    final b = booking ?? const {};
    final baseFare = _num(b['baseFare']);
    final distanceCharge = _num(b['distanceCharge']);
    final timeCharge = _num(b['timeCharge']);
    final surgeFare = _num(b['surgeFare']);
    final surgeMultiplier = _num(b['surgeMultiplier']);
    final addonTotal = _num(b['addonTotal']);
    final waitingCharge = _num(b['waitingCharge']);
    final waitingMinutes = _num(b['waitingMinutes']);
    final tollCharges = _num(b['tollCharges']);
    final parkingCharges = _num(b['parkingCharges']);
    final loadingCharge = _num(
        b['loadingUnloading'] is Map ? (b['loadingUnloading'] as Map)['charge'] : null);
    final gst = _num(b['gstAmount']);
    final gstPercentage = _num(b['gstPercentage']);
    final promoDiscount = _num(b['promoDiscount']);
    final coinDiscount = _num(b['coinDiscount']);
    final promoCode = b['promoCode']?.toString() ?? '';
    final discount = _num(b['totalDiscount'] ?? b['discount']);
    final subtotal = _num(b['subtotal']);
    final grandTotal = _num(b['finalFare'] ?? b['fare']);
    final hasData = grandTotal > 0 || subtotal > 0;

    final rows = <Widget>[];
    void charge(String label, double value) {
      if (value > 0.004) rows.add(_fareRow(label, "+ ${_money(value)}"));
    }

    if (subtotal > 0) {
      charge("Base Fare:", baseFare);
      charge("Distance Charge:", distanceCharge);
      charge("Time Charge:", timeCharge);
      charge(
          surgeMultiplier > 1 ? "Surge (x${_plain(surgeMultiplier)}):" : "Surge:",
          surgeFare);
      charge("Add-on Charges:", addonTotal);

      // Add-on names, no figures: a percentage-priced add-on stores `price` as
      // the percentage (Insurance = 2), so listing those as money would both
      // misstate them and break the sum. The charged total is the row above.
      final addonNames = _addonNames();
      if (addonTotal > 0 && addonNames.isNotEmpty) {
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            addonNames,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7A90)),
          ),
        ));
      }

      // Extras the server records but does not always bill: a waiting charge on
      // an already-paid booking is stored and deliberately left out of the
      // subtotal. Show them only when they account for the gap, so the rows
      // keep summing to the Sub Total the customer was actually charged.
      final itemised =
          baseFare + distanceCharge + timeCharge + surgeFare + addonTotal;
      final gap = subtotal - itemised;
      final extras =
          waitingCharge + tollCharges + parkingCharges + loadingCharge;
      if (extras > 0.004 && (gap - extras).abs() <= 0.01) {
        charge(
            waitingMinutes > 0
                ? "Waiting Charge (${_plain(waitingMinutes)} min):"
                : "Waiting Charge:",
            waitingCharge);
        charge("Toll Charges:", tollCharges);
        charge("Parking Charges:", parkingCharges);
        charge("Loading / Unloading:", loadingCharge);
      } else if (gap > 0.01) {
        // Whatever the server put into the subtotal that isn't itemised above
        // (e.g. a minimum-fare top-up). Derived from the server's own figures —
        // never a made-up number — so the rows still reach the Sub Total.
        charge("Other Charges:", gap);
      }

      rows.add(const SizedBox(height: 10));
      rows.add(const Divider(color: dividerColor, thickness: 1));
      rows.add(_fareRow("Sub Total:", _money(subtotal),
          isBold: true, color: Colors.black));
    }

    // GST and discounts apply to the Sub Total, so they belong below it.
    if (gst > 0.004) {
      rows.add(_fareRow(
          gstPercentage > 0 ? "GST (${_plain(gstPercentage)}%):" : "GST:",
          "+ ${_money(gst)}"));
    }
    if (discount > 0.004) {
      // Itemise promo vs coins only when the two account for the whole
      // discount; otherwise a single honest line.
      if (promoDiscount > 0.004 &&
          coinDiscount > 0.004 &&
          (promoDiscount + coinDiscount - discount).abs() <= 0.01) {
        rows.add(_fareRow(
            promoCode.isNotEmpty ? "Promo ($promoCode):" : "Promo Discount:",
            "- ${_money(promoDiscount)}"));
        rows.add(_fareRow("Coin Discount:", "- ${_money(coinDiscount)}"));
      } else {
        rows.add(_fareRow("Discount:", "- ${_money(discount)}"));
      }
    }

    // Anything still unaccounted for between the rows above and the server's
    // grand total. The total shown is always the server's — money is
    // server-authoritative — and this line is the difference, so the receipt
    // reconciles instead of silently disagreeing with itself.
    final adjustment = grandTotal - (subtotal + gst - discount);
    if (subtotal > 0 && adjustment.abs() > 0.01) {
      rows.add(_fareRow("Adjustment:",
          "${adjustment < 0 ? '- ' : '+ '}${_money(adjustment.abs())}"));
    }

    rows.add(const SizedBox(height: 10));
    rows.add(const Divider(color: dividerColor, thickness: 1));
    rows.add(_fareRow("Grand Total:", _money(grandTotal),
        isBold: true, color: Colors.black));

    return Stack(
      alignment: Alignment.center,
      children: [
        // Blurred background
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            color: Colors.black.withValues(alpha: 0.4),
          ),
        ),

        // Bottom Sheet
        DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Stack(
              children: [
                // Sheet content
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                  margin: const EdgeInsets.only(top: 60),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      const Center(
                        child: Text(
                          "Fare Calculations",
                          style: TextStyle(
                            color: darkBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (!hasData)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              "Fare details unavailable",
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        )
                      else
                        ...rows,
                      const SizedBox(height: 30),
                    ],
                  ),
                ),

                // Close Button
                Positioned(
                  top: 0,
                  left : 0,
                  right : 0,
                  child: Container(
                    height: 50,
                    width: 50,
                    decoration: const BoxDecoration(
                      color: darkBlue,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// "Loading Help x2, Insurance" — context for the Add-on Charges row.
  String _addonNames() {
    final raw = booking?['addons'];
    if (raw is! List) return '';
    final names = <String>[];
    for (final a in raw) {
      if (a is! Map) continue;
      final name = a['name']?.toString() ?? '';
      if (name.isEmpty) continue;
      final qty = _num(a['quantity']);
      names.add(qty > 1 ? '$name x${_plain(qty)}' : name);
    }
    return names.join(', ');
  }

  Widget _fareRow(String title, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: color ?? const Color(0xFF14233B),
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color ?? const Color(0xFF14233B),
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
