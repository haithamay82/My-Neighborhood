import 'package:flutter/material.dart';
import 'yoki_splash_screen.dart';

class SplashScreen extends StatefulWidget {
  final Function(Locale)? onLanguageSelected;
  
  const SplashScreen({super.key, this.onLanguageSelected});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    return YokiSplashScreen(
      onLanguageSelected: widget.onLanguageSelected,
    );
  }
}