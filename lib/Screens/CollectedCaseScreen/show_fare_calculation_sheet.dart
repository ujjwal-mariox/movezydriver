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

  @override
  Widget build(BuildContext context) {
    const darkBlue = Color(0xFF14233B);
    const dividerColor = Color(0xFFE6EEF2);

    // Real fare components from the booking; 0 when a component isn't present.
    final b = booking ?? const {};
    final baseFare = _num(b['baseFare']);
    final distanceCharge = _num(b['distanceCharge']);
    final timeCharge = _num(b['timeCharge']);
    final surgeFare = _num(b['surgeFare']);
    final waitingCharge = _num(b['waitingCharge']);
    final gst = _num(b['gstAmount']);
    final discount = _num(b['totalDiscount'] ?? b['discount']);
    final subtotal = _num(b['subtotal']);
    final grandTotal = _num(b['finalFare'] ?? b['fare']);
    final hasData = grandTotal > 0 || subtotal > 0;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Blurred background
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            color: Colors.black.withOpacity(0.4),
          ),
        ),

        // Bottom Sheet
        DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              child: Stack(
                children: [
                  // Sheet content
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                    margin: EdgeInsets.only(top: 60),
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
                        else ...[
                          if (baseFare > 0)
                            _fareRow("Base Fare:", "+ ${_money(baseFare)}"),
                          if (distanceCharge > 0)
                            _fareRow("Distance Charge:", "+ ${_money(distanceCharge)}"),
                          if (timeCharge > 0)
                            _fareRow("Time Charge:", "+ ${_money(timeCharge)}"),
                          if (surgeFare > 0)
                            _fareRow("Surge:", "+ ${_money(surgeFare)}"),
                          if (waitingCharge > 0)
                            _fareRow("Waiting Charge:", "+ ${_money(waitingCharge)}"),
                          if (gst > 0) _fareRow("GST:", "+ ${_money(gst)}"),
                          if (discount > 0)
                            _fareRow("Discount:", "- ${_money(discount)}"),

                          if (subtotal > 0) ...[
                            const SizedBox(height: 10),
                            const Divider(color: dividerColor, thickness: 1),
                            _fareRow("Sub Total:", _money(subtotal),
                                isBold: true, color: Colors.black),
                          ],

                          const SizedBox(height: 10),
                          const Divider(color: dividerColor, thickness: 1),
                          _fareRow("Grand Total:", _money(grandTotal),
                              isBold: true, color: Colors.black),
                        ],
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
              ),
            );
          },
        ),
      ],
    );
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
              color: color ?? Color(0xFF14233B),
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
