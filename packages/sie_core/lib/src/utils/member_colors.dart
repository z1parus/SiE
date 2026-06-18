import 'package:flutter/material.dart';
import '../theme/sie_colors.dart';

const _memberPalette = [
  Color(0xFF4A90D9), // blue
  Color(0xFF7B5EA7), // purple
  Color(0xFF27AE60), // green
  Color(0xFFE67E22), // orange
  Color(0xFFE91E8C), // pink
  Color(0xFF16A085), // teal
  Color(0xFFC0392B), // red
  Color(0xFF8D6E63), // brown
];

Color memberColor(String userId, SieColors sc) {
  if (userId.isEmpty) return sc.accent;
  final hash = userId.codeUnits.fold(0, (h, c) => h * 31 + c);
  return _memberPalette[hash.abs() % _memberPalette.length];
}
