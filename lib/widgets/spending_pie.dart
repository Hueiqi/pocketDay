import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SpendingPie extends CustomPainter {
  final List<int> values;
  SpendingPie(this.values);
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0, (a, b) => a + b);
    if (total == 0) return;
    double start = -math.pi / 2;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: math.min(size.width, size.height) / 2 - 4,
    );
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = chartColors[i % chartColors.length],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant SpendingPie oldDelegate) => true;
}
