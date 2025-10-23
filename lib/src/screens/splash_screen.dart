import 'dart:async';
import 'dart:ui'; // 🔹 ez kell a blur funkcióhoz
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
    _image = const AssetImage('assets/images/SplashScreen.jpg');

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
      backgroundColor: const Color(0xFFC7F2E3),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1) Háttér: ugyanaz a kép erősen elmosva és cover-rel kitöltve
          //    -> nincs üres sáv, nincs észrevehető torzítás
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFC7F2E3),
                image: DecorationImage(
                  image: _image,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ),
          ),

          // (opcionális) finom átlátszó sötétítés, hogy az előtér kontrasztosabb legyen
          Container(
            color: Colors.black.withOpacity(0.05),
          ),

          // 2) Előtér: tűéles kép contain-nel -> semmi nem vágódik le
          Center(
            child: Image(
              image: _image,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              filterQuality: FilterQuality.high,
            ),
          ),
        ],
      ),
    );
  }
}
