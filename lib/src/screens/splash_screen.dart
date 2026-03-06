import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  static const routeName = '/';
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Minimum ennyi ideig legyen kint a splash (ms)
  static const _minDisplay = Duration(milliseconds: 1200);
  late final ImageProvider _image;

  @override
  void initState() {
    super.initState();
    _image = const AssetImage('assets/images/finalmaybe.jpg');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final sw = Stopwatch()..start();
      // előtöltés, hogy ne villanjon
      await precacheImage(_image, context);

      final remain = _minDisplay - sw.elapsed;
      if (remain.inMilliseconds > 0) {
        await Future.delayed(remain);
      }
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, LoginScreen.routeName);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image(
          image: _image,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
