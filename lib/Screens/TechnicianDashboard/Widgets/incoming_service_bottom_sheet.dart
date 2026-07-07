import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/Widgets/start_customer_direction.dart';

class IncomingServiceBottomSheet extends StatelessWidget {
  const IncomingServiceBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [

          Container(
            margin: EdgeInsets.only(top: 50),
            decoration: BoxDecoration(
              color: HexColor("#FBFBFB"),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                children: [

                  const SizedBox(height: 60),

                  // Total amount section
                  Container(
                    padding: EdgeInsets.only(left: 10, right: 10, top: 17, bottom: 17),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: const [
                            SizedBox(width: 10,),
                            Text(
                              "Total Amount",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            Spacer(),

                            Text(
                              "₹ 239",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),

                            SizedBox(width: 10,),
                          ],
                        ),

                        const SizedBox(height: 4),
                        Row(
                          children: const [
                            SizedBox(width: 10,),
                            Text(
                              "Payment Method : CASH",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                              ),
                            ),

                            Spacer(),

                            Text(
                              "Est Time : 0 Mins",
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF2F5AE3),
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            SizedBox(width: 10,),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Service Details - AC",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Ac Repair & Gas Refill",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Address list
                  Column(
                    children: [
                      buildAddress(
                        "Tower 4, Assotech Business Cresterra, 714, Sector 135, Noida, Bajdpur, Uttar Pradesh India",
                        "0 Km Away",
                        true,
                        context
                      ),
                      const SizedBox(height: 10),
                      buildAddress(
                        "Sector 29 Assotech T-4,718,7th, Assotech Business Cresterra, Above Assotech Business Cresterra, Sector 135, Noida, Uttar Pradesh 201304, India",
                        "",
                        false,
                        context
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HexColor("#2C54C1"),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding:  EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              shape:  RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                              ),
                              builder: (_) => StartCustomerDirection()
                            );
                          },
                          child:  Text(
                            "Accept Service",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: HexColor("#2C54C1")),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Ignore",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2F5AE3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Color(0xFF2F5AE3), width: 3),
              color: Colors.white
            ),
            alignment: Alignment.center,
            child: const Text(
              "3 : 00",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAddress(String address, String distance, bool selected, BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 18,
          width: 18,
          margin: EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            border: Border.all(color: HexColor("#275FC8"), width: 5),
            borderRadius: BorderRadius.circular(100)
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: MediaQuery.of(context).size.width - 70,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  address,
                  style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w400),
                ),
              ),
              if (distance.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    distance,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
