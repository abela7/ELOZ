import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Service to convert Flutter icons to Android bitmaps for notifications
class IconBitmapGenerator {
  /// Convert an IconData to a Uint8List bitmap (PNG format)
  /// This can be used as a large icon in Android notifications
  static Future<Uint8List?> iconToBitmap({
    required IconData icon,
    required Color color,
    double size = 64.0,
  }) async {
    try {
      // Create a picture recorder to draw the icon
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Draw a circular background
      final paint = Paint()
        ..color = color.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(size / 2, size / 2),
        size / 2,
        paint,
      );
      
      // Draw the icon
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );
      
      textPainter.text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size * 0.6, // 60% of the canvas size
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      );
      
      textPainter.layout();
      
      // Center the icon
      final xOffset = (size - textPainter.width) / 2;
      final yOffset = (size - textPainter.height) / 2;
      
      textPainter.paint(canvas, Offset(xOffset, yOffset));
      
      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      
      // Convert to PNG bytes
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('❌ IconBitmapGenerator: Error converting icon to bitmap: $e');
      return null;
    }
  }
  
  /// Generate a default app icon bitmap (bell icon)
  static Future<Uint8List?> generateDefaultIcon() async {
    return iconToBitmap(
      icon: Icons.notifications_rounded,
      color: const Color(0xFFCDAF56), // Gold color
      size: 64.0,
    );
  }
  
  /// Generate a special task icon bitmap (star icon)
  static Future<Uint8List?> generateSpecialTaskIcon() async {
    return iconToBitmap(
      icon: Icons.star_rounded,
      color: const Color(0xFFE53935), // Red color
      size: 64.0,
    );
  }
}
