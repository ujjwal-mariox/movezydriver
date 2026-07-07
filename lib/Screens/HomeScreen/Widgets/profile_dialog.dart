import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';


class ProfileDialog extends StatefulWidget {
  const ProfileDialog({super.key});

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  SizedBox(height: 20,),

                  Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Column(
                        children: [

                          SizedBox(height: 50,),
                          SizedBox(
                              height: 200, width: 400,
                              child: Image.asset("assets/pati_icon.png", height: 200, width: 400,)),
                        ],
                      ),

                      SizedBox(height: 10,),

                      Image.asset("assets/transparent_app_icon.png", height: 130, ),

                      const SizedBox(height: 8),


                      Column(
                        children: [
                          SizedBox(height: 140,),
                          Image.asset("assets/profile_pic.png", height: 100,)
                        ],
                      )

                    ],
                  ),


                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text("Zakariya Yoder", style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold),),
                      SizedBox(height: 2,),
                      Text("Gochauffeurs patner", style: TextStyle(color: HexColor("#607080"), fontSize: 12, fontWeight: FontWeight.w400),),
                      SizedBox(height: 2,),
                      Text("#1324574890", style: TextStyle(color: HexColor("#607080"), fontSize: 12, fontWeight: FontWeight.w400),),
                    ],
                  ),

                  SizedBox(height: 20,),


                  Container(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Mobile Number", style: TextStyle(color: HexColor("#607080"), fontSize: 12, fontWeight: FontWeight.w400),),
                            SizedBox(height: 7,),
                            Text("Joining Date", style: TextStyle(color: HexColor("#607080"), fontSize: 12, fontWeight: FontWeight.w400),),
                            SizedBox(height: 7,),
                            Text("Driving License", style: TextStyle(color: HexColor("#607080"), fontSize: 12, fontWeight: FontWeight.w400),),
                            SizedBox(height: 7,),
                            Text("Emergency No.", style: TextStyle(color: HexColor("#607080"), fontSize: 12, fontWeight: FontWeight.w400),),
                            SizedBox(height: 7,),
                            Text("Blood Group", style: TextStyle(color: HexColor("#607080"), fontSize: 12, fontWeight: FontWeight.w400),),
                            SizedBox(height: 7,),
                            Text("License Validity", style: TextStyle(color: HexColor("#607080"), fontSize: 12, fontWeight: FontWeight.w400),),
                            SizedBox(width: 10,),
                          ],
                        ),

                        SizedBox(width: 10,),

                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(":  +91 12345 67890", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w400),),
                            SizedBox(height: 7,),
                            Text(":  12 Jan 2023", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w400),),
                            SizedBox(height: 7,),
                            Text(":  DLFA10101010101", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w400),),
                            SizedBox(height: 7,),
                            Text(":  +91 12345 67890", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w400),),
                            SizedBox(height: 7,),
                            Text(":  B+", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w400),),
                            SizedBox(height: 7,),
                            Text(":  23 Aug 2029", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w400),),
                            SizedBox(width: 7,),
                          ],
                        )


                      ],
                    ),
                  ),

                  SizedBox(height: 20,),
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
