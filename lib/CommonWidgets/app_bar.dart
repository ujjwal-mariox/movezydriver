import 'package:flutter/cupertino.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';


Widget commonAppBar({required Widget child, required double height, required BuildContext context}){
     return Container(
       height: height,
       width: MediaQuery.of(context).size.width,
       decoration:  BoxDecoration(
         color: AppColors.appColor,
         borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))
       ),
       child: Stack(
         children: [
           child,
         ],
       ),
     );
  }