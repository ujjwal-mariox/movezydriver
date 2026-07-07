

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

void showCustomToast(BuildContext context,String text) {
  FToast fToast = FToast();
  fToast.init(context);

  Widget toast = Container(
    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16.0),
      color: Colors.black87,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
         Flexible(
           child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 14),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
         ),
      ],
    ),
  );

  fToast.showToast(
    child: toast,
    gravity: ToastGravity.BOTTOM,
    toastDuration: const Duration(seconds: 2),
  );
}