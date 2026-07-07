import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/Screens/on_boarding_screens/basic_details_screen.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hexcolor/hexcolor.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  Widget build(BuildContext context) {

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // for Android
      statusBarBrightness: Brightness.dark, // for iOS
      )
    );

    return Scaffold(
      body: Container(
       child: Column(
         children: [

           Container(
             width: MediaQuery.of(context).size.width,
             decoration: BoxDecoration(
               color: AppColors.greenColor,
               borderRadius: BorderRadius.only(bottomRight: Radius.circular(30), bottomLeft: Radius.circular(30))
             ),
             child: Column(
               children: [
                 SizedBox(height: 40,),

                 Container(
                   child: Image.asset("assets/app_icon.png",
                     height: 150,
                     width: 150,
                     fit: BoxFit.cover,
                   ),
                 ),

                 Text("Welcome to",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w400
                    ),
                 ),

                 Text("Movezy Partner App",
                   style: TextStyle(
                       color: Colors.white,
                       fontSize: 19,
                       fontWeight: FontWeight.bold
                   ),
                 ),


                 SizedBox(height: 20,),

               ],
             ),
           ),


           SizedBox(height: 20,),

           Text("Please select the service you want to register for",
             style: TextStyle(
                 color: Colors.black,
                 fontSize: 13,
                 fontWeight: FontWeight.w400
             ),
           ),

           Container(
             margin: EdgeInsets.only(left: 6, right: 6),
             child: Stack(
               children: [
               Image.asset(
               "assets/register_as_cab_movezy_driver_app.png",
               ),

                 Positioned(
                   top: 15,
                     left: 20,
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.start,
                       crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Container(
                         child: Text("Register \nas a Cab Driver", style: TextStyle(
                             color: Colors.white,
                             fontWeight: FontWeight.w600,
                             fontSize: 14
                           ),
                         )
                     ),
                     SizedBox(height: 4,),
                     Container(
                         child: const Text("to earn from daily rides", style: TextStyle(
                             color: Colors.white,
                             fontWeight: FontWeight.w400,
                             fontSize: 13
                              ),
                         )
                     ),
                     SizedBox(height: 4,),
                     InkWell(
                       onTap: (){
                         pushTo(context, BasicDetailsScreen());
                       },
                       child: Container(
                         height: 45,
                           padding: EdgeInsets.symmetric(horizontal: 15),
                           decoration: BoxDecoration(
                             color: HexColor("#015EA3"),
                             borderRadius: BorderRadius.circular(13),
                           ),
                           child: Center(
                             child: Text("Register as a Cab Driver", style: TextStyle(
                                 color: Colors.white,
                                 fontWeight: FontWeight.w600,
                                 fontSize: 13
                               ),
                             ),
                           )
                       ),
                     ),
                   ],
                 )
                 )
               ],
             ),
           ),

           Container(
             margin: EdgeInsets.only(left: 6, right: 6, top: 6),
             child: Stack(
               children: [
                 Image.asset(
                   "assets/register_as_parcel_delivery.png",
                 ),

                 Positioned(
                     top: 15,
                     left: 20,
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.start,
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Container(
                             child: Text("Register for Parcel Delivery", style: TextStyle(
                                 color: Colors.white,
                                 fontWeight: FontWeight.w600,
                                 fontSize: 14
                             ),
                             )
                         ),
                         SizedBox(height: 4,),
                         Container(
                             child: const Text("Deliver parcels & earn with flexible \ntimings", style: TextStyle(
                                 color: Colors.white,
                                 fontWeight: FontWeight.w400,
                                 fontSize: 12
                               ),
                             )
                         ),
                         SizedBox(height: 8,),
                         InkWell(
                           onTap: (){
                             pushTo(context, BasicDetailsScreen());
                           },
                           child: Container(
                               height: 45,
                               padding: EdgeInsets.symmetric(horizontal: 15),
                               decoration: BoxDecoration(
                                 color: HexColor("#015EA3"),
                                 borderRadius: BorderRadius.circular(13),
                               ),
                               child: Center(
                                 child: Text("Continue Parcel Delivery", style: TextStyle(
                                     color: Colors.white,
                                     fontWeight: FontWeight.w600,
                                     fontSize: 13
                                   ),
                                 ),
                               )
                           ),
                         ),
                       ],
                     )
                 )
               ],
             ),
           ),
         ],
       ),
      ),
    );
  }
}
