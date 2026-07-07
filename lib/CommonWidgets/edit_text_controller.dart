import 'package:flutter/material.dart';


Widget editTextWidget({
  required BuildContext context,
  required TextEditingController controller,
  required String hintText,
  required bool isOptional,
  required String labelText,
           Widget? suffixIcon,
}){
  return Column(
    mainAxisAlignment: MainAxisAlignment.start,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 3,),
          Container(
              margin: EdgeInsets.only(bottom: 6),
              child: Text(labelText, style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600),)
          ),

          if(isOptional == false)
          Container(
              margin: EdgeInsets.only(bottom: 6),
              child: Text("*", style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),)
          ),
        ],
      ),

      Container(
        height: 54,
        padding: EdgeInsets.only(left: 15, right: 15),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color : Colors.grey.shade300)
        ),
        child: Center(
          child: TextFormField(
            controller: controller,
            style: TextStyle(color: Colors.black, fontSize: 15),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle:  TextStyle(color: Colors.grey, fontSize: 14),
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              suffixIconConstraints: BoxConstraints(
                maxWidth: 30
              ),
              suffixIcon: suffixIcon
            ),
          ),
        ),
      ),
    ],
  );
}