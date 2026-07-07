import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';


class StartCustomerDirection extends StatefulWidget {
  const StartCustomerDirection({super.key});
  @override
  State<StartCustomerDirection> createState() => _StartCustomerDirectionState();
}

class _StartCustomerDirectionState extends State<StartCustomerDirection> {

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 7,),

            // Total amount section
            Container(
              padding: EdgeInsets.only(left: 10, right: 10, top: 17, bottom: 17),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: HexColor("#000000").withOpacity(0.1)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(width: 10,),
                      Text(
                        "Service details -AC",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black,
                          fontWeight: FontWeight.w400,
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

                   SizedBox(height: 4),
                  Row(
                    children:  [
                      SizedBox(width: 10,),
                      Text(
                        "Book an ac technician",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                          fontWeight: FontWeight.w500
                        ),
                      ),

                      Spacer(),

                      SizedBox(width: 10,),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding:  EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:  [
                  Row(
                    children: [
                      Text(
                        "Customer Address.",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),

                      Spacer(),

                      Text(
                        "1 Km",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: HexColor("#2C54C1"),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Tower 4, Assotech Business Cresterra, 714, Sector 135, Noida, Bajidpur, Uttar Pradesh India",
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

            Container(
              padding: EdgeInsets.only(left: 10, right: 10, top: 17, bottom: 17),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(width: 10,),
                      Text(
                        "Service charge",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      Spacer(),

                      Text(
                        "₹ 239",
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      SizedBox(width: 10,),
                    ],
                  ),

                  const SizedBox(height: 4),
                  Row(
                    children:  [
                      SizedBox(width: 10,),
                      Text(
                        "Your Booking ID is",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),

                      SizedBox(width: 6,),

                      Text(
                        "#5599",
                        style: TextStyle(
                          fontSize: 11,
                          color: HexColor("#275FC8"),
                        ),
                      ),

                      Spacer(),

                      SizedBox(width: 10,),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Buttons
            Row(
              children: [

                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: HexColor("#2C54C1")),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {},
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        Icon(Icons.call, size: 19,),

                        SizedBox(width: 5,),

                        const Text(
                          "Call",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2F5AE3),
                          ),
                        ),
                      ],
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
                    onPressed: () {},
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        Image.asset("assets/chat_msg.png",height: 18,width: 18,),

                        SizedBox(width: 5,),

                        Text(
                          "Chat",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2F5AE3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20,),

            InkWell(
              onTap: (){
              //  pushTo(context, ConfirmOtpScreen());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 30),
                decoration: BoxDecoration(
                  color: HexColor("#2C54C1"),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  "Start customer direction",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          ],
        ),
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
