import 'package:flutter/material.dart';

Color hexToColor(String hex) {
  final h = hex.replaceAll('#', '').padLeft(6, '0');
  return Color(int.tryParse('FF$h', radix: 16) ?? 0xFF00C8FF);
}
