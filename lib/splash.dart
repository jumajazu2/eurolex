import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: imageWidth,
        height: imageHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Image.asset(
            'assets/splash1.png',
            width: imageWidth,
            height: imageHeight,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  // Set these to your image's native resolution
  static const double imageWidth = 512;
  static const double imageHeight = 512;
}
