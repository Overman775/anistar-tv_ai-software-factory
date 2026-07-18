import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TvBackdrop(
        child: TvStateView(icon: Icons.error_outline_rounded, title: 'Что-то пошло не так', message: text),
      ),
    );
  }
}
