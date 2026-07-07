

import 'package:get/get.dart';
import 'package:movezy_driver_app/Screens/SplashScreen/Controller.dart';


class SplashBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => SplashController());
  }
}