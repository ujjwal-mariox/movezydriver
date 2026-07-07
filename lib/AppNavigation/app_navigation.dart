import 'package:flutter/cupertino.dart';

Future<dynamic> pushTo(BuildContext context, Widget name) async {
  return await Navigator.push(
    context,
    CupertinoPageRoute(builder: (context) => name),
  );
}

void replaceRoute(BuildContext context, Widget name){
  Navigator.pushAndRemoveUntil(
    context,
    CupertinoPageRoute(builder: (context) => name),
        (Route<dynamic> route) => false,
  );
}