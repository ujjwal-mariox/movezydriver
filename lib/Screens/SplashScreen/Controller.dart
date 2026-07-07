import 'package:flutter/foundation.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:get/get.dart';


class SplashController extends GetxController {
  @override
  void onReady() {
    super.onReady();
    if (kDebugMode) {
      print('onReady');
    }
  }

  @override
  void onInit() {

  }

  @override
  void onClose() {
    super.onClose();
    if (kDebugMode) {
      print('onClose');
    }
  }



}