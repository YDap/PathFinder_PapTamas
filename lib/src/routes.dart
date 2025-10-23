import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  SplashScreen.routeName: (_) => const SplashScreen(),
  LoginScreen.routeName: (_) => const LoginScreen(),
};
