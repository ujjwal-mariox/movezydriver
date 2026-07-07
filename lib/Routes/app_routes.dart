import 'package:movezy_driver_app/Screens/SplashScreen/SplashBinding.dart';
import 'package:movezy_driver_app/Screens/SplashScreen/splash_screen.dart';
import 'package:get/get.dart';


class AppRoutes {
  static String initialRoute = '/initialRoute';

  static List<GetPage> pages = [
    GetPage(
      name: initialRoute,
      page: () =>  SplashScreen(),
      bindings: [
        SplashBinding(),
      ],
      transition: Transition.rightToLeft,
      //transitionDuration: Duration(seconds: 2),
    ),
  ];
}
