import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';


class WishToWorkDialog extends StatefulWidget {
  const WishToWorkDialog({super.key});

  @override
  State<WishToWorkDialog> createState() => _WishToWorkDialogState();
}

class _WishToWorkDialogState extends State<WishToWorkDialog> {

  int selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    '“ How many hours do you wish to work? ”',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),

                  Text("Please select hours", style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w400),),

                  const SizedBox(height: 20),


                  Container(
                    child: Row(
                      children: [
                        Image.asset("assets/radio_button_unselected.png", height: 30, width: 30,),
                        SizedBox(width: 10,),
                        Text("3-4 Hours", style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),)
                      ],
                    ),
                  ),

                  SizedBox(height: 15,),

                  Container(height: 1,color: HexColor("#E9F0F7"),),

                  SizedBox(height: 15,),


                  Container(
                    child: Row(
                      children: [
                        Image.asset("assets/radio_button_unselected.png", height: 30, width: 30,),
                        SizedBox(width: 10,),
                        Text("4-5 Hours", style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),)
                      ],
                    ),
                  ),

                  SizedBox(height: 15,),

                  Container(height: 1,color: HexColor("#E9F0F7"),),

                  SizedBox(height: 15,),

                  Container(
                    child: Row(
                      children: [
                        Image.asset("assets/radio_button_unselected.png", height: 30, width: 30,),
                        SizedBox(width: 10,),
                        Text("5-6 Hours", style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),)
                      ],
                    ),
                  ),

                  SizedBox(height: 15,),

                  Container(height: 1,color: HexColor("#E9F0F7"),),

                  SizedBox(height: 15,),


                  Container(
                    child: Row(
                      children: [
                        Image.asset("assets/radio_button_unselected.png", height: 30, width: 30,),
                        SizedBox(width: 10,),
                        Text("6-7 Hours", style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),)
                      ],
                    ),
                  ),

                  SizedBox(height: 15,),

                  Container(height: 1,color: HexColor("#E9F0F7"),),

                  SizedBox(height: 15,),


                  Container(
                    child: Row(
                      children: [
                        Image.asset("assets/radio_button_unselected.png", height: 30, width: 30,),
                        SizedBox(width: 10,),
                        Text("7-8 Hours", style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),)
                      ],
                    ),
                  ),

                  SizedBox(height: 15,),

                  Container(height: 1,color: HexColor("#E9F0F7"),),

                  SizedBox(height: 15,),


                  Container(
                    child: Row(
                      children: [
                        Image.asset("assets/radio_button_unselected.png", height: 30, width: 30,),
                        SizedBox(width: 10,),
                        Text("More than 8 hours", style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),)
                      ],
                    ),
                  ),

                  SizedBox(height: 20,),

                  // Book Button
                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HexColor('#A2BF49'),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "Proceed",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 13,),

          GestureDetector(
            onTap: () => Navigator.pop(context), // Close the sheet
            child: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white
              ),
              child: const Icon(Icons.close, color: Colors.black, size: 25),
            ),
          ),
        ],
      ),
    );
  }


  Widget _optionButton(String icon, String label, int index) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Image.asset(icon,fit: BoxFit.cover,height: 15,color: selectedIndex == index ? Colors.white : HexColor('#015EA3'),),
      label: Text(label, style: TextStyle(color: selectedIndex == index ? Colors.white : HexColor('#015EA3'), fontSize: 11),),
      style: OutlinedButton.styleFrom(backgroundColor:selectedIndex == index ? HexColor("#015EA3") : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
