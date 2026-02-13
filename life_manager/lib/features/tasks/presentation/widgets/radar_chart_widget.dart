import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Radar Chart Widget - Placeholder UI only
/// Shows category performance comparison
class RadarChartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> categoryData;

  const RadarChartWidget({
    super.key,
    required this.categoryData,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxValue = categoryData.map((e) => e['value'] as int).reduce((a, b) => a > b ? a : b);
    final size = 150.0;
    final center = size / 2;

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.15),
      color: isDark ? const Color(0xFF2D3139) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Category Performance',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: _RadarChartPainter(
                  categoryData: categoryData,
                  maxValue: maxValue,
                  center: center,
                  isDark: isDark,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: categoryData.map((data) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: data['color'] as Color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      data['name'] as String,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 10,
                          ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> categoryData;
  final int maxValue;
  final double center;
  final bool isDark;

  _RadarChartPainter({
    required this.categoryData,
    required this.maxValue,
    required this.center,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withOpacity(0.2);

    final dataPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFCDAF56).withOpacity(0.3);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFCDAF56);

    final pointCount = categoryData.length;
    final angleStep = (2 * math.pi) / pointCount;

    // Draw grid circles
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(Offset(center, center), center * i / 4, paint);
    }

    // Draw axes
    for (int i = 0; i < pointCount; i++) {
      final angle = i * angleStep - math.pi / 2;
      final x = center + center * math.cos(angle);
      final y = center + center * math.sin(angle);
      canvas.drawLine(Offset(center, center), Offset(x, y), paint);
    }

    // Draw data polygon
    final path = Path();
    for (int i = 0; i < pointCount; i++) {
      final data = categoryData[i];
      final value = data['value'] as int;
      final radius = (value / maxValue) * center;
      final angle = i * angleStep - math.pi / 2;
      final x = center + radius * math.cos(angle);
      final y = center + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, dataPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(_RadarChartPainter oldDelegate) => false;
}

