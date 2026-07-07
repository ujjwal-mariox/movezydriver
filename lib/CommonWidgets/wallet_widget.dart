import 'package:flutter/material.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';

Widget walletWidget(BuildContext context){
     return Container(
       padding:  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
       decoration: BoxDecoration(
         color: AppColors.appColor,
         borderRadius: BorderRadius.circular(12),
       ),
       child: Row(
         children:  [
           Icon(Icons.wallet, color: Colors.white),
           SizedBox(width: 6),
           Text(
             "500",
             style: TextStyle(
               fontSize: 13,
               color: Colors.white,
               fontWeight: FontWeight.bold,
             ),
           )
         ],
       ),
     );
   }