import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Helper to generate custom, high-resolution BitmapDescriptor map markers
/// (e.g. Student Profile Avatars, Home Base pins, Delivery Couriers, Campus Spots)
/// and manage dark-mode map styling.
class MapMarkerHelper {
  static final Map<String, BitmapDescriptor> _markerCache = {};

  /// Generates a circular avatar marker showing the student's profile picture or initials,
  /// complete with a directional pin pointer, glowing border, battery badge, and status dot.
  static Future<BitmapDescriptor> createStudentAvatarMarker({
    required String name,
    String? profileImageUrl,
    Color borderColor = const Color(0xFF05D5AA),
    int? batteryLevel,
    bool isSOS = false,
    double? speedKmh,
    bool isOnline = true,
  }) async {
    // Generate cache key based on state
    final batteryTier = batteryLevel == null ? -1 : (batteryLevel / 10).floor() * 10;
    final speedTier = speedKmh == null ? 0 : (speedKmh > 25 ? 2 : (speedKmh > 1 ? 1 : 0));
    final cacheKey = 'student_${name}_${profileImageUrl ?? "none"}_${borderColor.toARGB32()}_${batteryTier}_${isSOS}_${speedTier}_$isOnline';

    if (_markerCache.containsKey(cacheKey)) {
      return _markerCache[cacheKey]!;
    }

    final effectiveBorderColor = isSOS
        ? const Color(0xFFF92B60)
        : (batteryLevel != null && batteryLevel <= 15
            ? Colors.redAccent
            : (speedKmh != null && speedKmh > 25 ? const Color(0xFFFF6F00) : borderColor));

    // Marker canvas dimensions
    const double width = 140.0;
    const double height = 170.0;
    const double cx = width / 2;
    const double cy = 60.0;
    const double radius = 48.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    // 1. Draw Pointer / Drop Pin Tail with Shadow
    final pointerPath = Path();
    pointerPath.moveTo(cx - 18, cy + radius - 10);
    pointerPath.quadraticBezierTo(cx, cy + radius + 32, cx, height - 16);
    pointerPath.quadraticBezierTo(cx, cy + radius + 32, cx + 18, cy + radius - 10);
    pointerPath.close();

    // Drop shadow under the pin tip
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(cx, height - 8), width: 36, height: 14),
      shadowPaint,
    );

    // Fill pointer
    final pointerPaint = Paint()
      ..color = effectiveBorderColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(pointerPath, pointerPaint);

    // 2. Outer Glow Ring
    final glowPaint = Paint()
      ..color = effectiveBorderColor.withValues(alpha: isSOS ? 0.45 : 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSOS ? 12.0 : 8.0;
    canvas.drawCircle(const Offset(cx, cy), radius + (isSOS ? 6.0 : 3.0), glowPaint);

    // 3. Main Border Circle
    final borderPaint = Paint()
      ..color = effectiveBorderColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(cx, cy), radius, borderPaint);

    // 4. White Inset Ring
    final whiteRingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(const Offset(cx, cy), radius - 3.5, whiteRingPaint);

    // 5. Draw Profile Image or Initials Avatar
    final innerRadius = radius - 6.5;
    final clipPath = Path()
      ..addOval(Rect.fromCircle(center: const Offset(cx, cy), radius: innerRadius));

    canvas.save();
    canvas.clipPath(clipPath);

    ui.Image? loadedImage;
    if (profileImageUrl != null && profileImageUrl.trim().isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(profileImageUrl)).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final codec = await ui.instantiateImageCodec(
            res.bodyBytes,
            targetWidth: (innerRadius * 2).toInt(),
            targetHeight: (innerRadius * 2).toInt(),
          );
          final frame = await codec.getNextFrame();
          loadedImage = frame.image;
        }
      } catch (_) {
        // Fallback to initials if image loading fails
      }
    }

    if (loadedImage != null) {
      paintImage(
        canvas: canvas,
        rect: Rect.fromCircle(center: const Offset(cx, cy), radius: innerRadius),
        image: loadedImage,
        fit: BoxFit.cover,
      );
    } else {
      // Background gradient
      final grad = ui.Gradient.linear(
        Offset(cx - innerRadius, cy - innerRadius),
        Offset(cx + innerRadius, cy + innerRadius),
        [
          const Color(0xFF0C1A30),
          const Color(0xFF1E3A8A),
        ],
      );
      final bgPaint = Paint()..shader = grad;
      canvas.drawCircle(const Offset(cx, cy), innerRadius, bgPaint);

      // Initials text
      final initials = _extractInitials(name);
      final tp = TextPainter(
        text: TextSpan(
          text: initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
    canvas.restore();

    // 6. Status Badge (Online dot or SOS indicator on top right)
    final badgeCenter = Offset(cx + radius - 14, cy - radius + 14);
    final badgeBgPaint = Paint()..color = const Color(0xFF0C101B);
    canvas.drawCircle(badgeCenter, 10, badgeBgPaint);

    final statusColor = isSOS
        ? const Color(0xFFF92B60)
        : (!isOnline
            ? Colors.grey
            : (speedKmh != null && speedKmh > 25 ? const Color(0xFFFF6F00) : const Color(0xFF22C55E)));

    final statusPaint = Paint()..color = statusColor;
    canvas.drawCircle(badgeCenter, 7.5, statusPaint);

    // 7. Battery & Info Pill at Bottom
    if (batteryLevel != null && batteryLevel >= 0) {
      final pillCenter = Offset(cx, height - 14);
      final pillRect = Rect.fromCenter(center: pillCenter, width: 62, height: 20);
      final rrect = RRect.fromRectAndRadius(pillRect, const Radius.circular(10));

      // Pill shadow & background
      canvas.drawRRect(
        rrect,
        Paint()..color = const Color(0xFF0C101B).withValues(alpha: 0.95),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = effectiveBorderColor.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      final batteryText = '$batteryLevel%';
      final batteryTp = TextPainter(
        text: TextSpan(
          text: isSOS ? '🚨 SOS' : '⚡ $batteryText',
          style: TextStyle(
            color: isSOS ? const Color(0xFFF92B60) : Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      batteryTp.layout();
      batteryTp.paint(canvas, Offset(pillCenter.dx - batteryTp.width / 2, pillCenter.dy - batteryTp.height / 2));
    }

    // Convert to PNG BitmapDescriptor
    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final descriptor = BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    _markerCache[cacheKey] = descriptor;
    return descriptor;
  }

  /// Generates a custom Home / Parent Base marker
  static Future<BitmapDescriptor> createParentHomeMarker({String label = 'Home Zone'}) async {
    const cacheKey = 'parent_home_marker';
    if (_markerCache.containsKey(cacheKey)) return _markerCache[cacheKey]!;

    const double width = 120.0;
    const double height = 130.0;
    const double cx = width / 2;
    const double cy = 45.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    // Pointer
    final pointer = Path();
    pointer.moveTo(cx - 14, cy + 30);
    pointer.lineTo(cx, height - 12);
    pointer.lineTo(cx + 14, cy + 30);
    pointer.close();

    canvas.drawPath(pointer, Paint()..color = const Color(0xFF3B82F6));

    // Outer circle
    canvas.drawCircle(const Offset(cx, cy), 36, Paint()..color = const Color(0xFF3B82F6));
    canvas.drawCircle(const Offset(cx, cy), 32, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(cx, cy), 28, Paint()..color = const Color(0xFF131A2A));

    // Draw Home Icon text or glyph
    final tp = TextPainter(
      text: const TextSpan(
        text: '🏠',
        style: TextStyle(fontSize: 26),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));

    // Bottom pill
    final pillRect = Rect.fromCenter(center: Offset(cx, height - 8), width: 80, height: 18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pillRect, const Radius.circular(8)),
      Paint()..color = const Color(0xFF131A2A),
    );
    final labelTp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    labelTp.layout();
    labelTp.paint(canvas, Offset(cx - labelTp.width / 2, height - 8 - labelTp.height / 2));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final descriptor = BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    _markerCache[cacheKey] = descriptor;
    return descriptor;
  }

  /// Generates a custom courier / rider marker with a motorbike emoji/icon and rider name
  static Future<BitmapDescriptor> createCourierMarker({String? riderName, String? label}) async {
    final displayName = riderName ?? label ?? 'Courier';
    final cacheKey = 'courier_$displayName';
    if (_markerCache.containsKey(cacheKey)) return _markerCache[cacheKey]!;

    const double width = 120.0;
    const double height = 120.0;
    const double cx = width / 2;
    const double cy = 46.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    // Pin tail
    final pointer = Path();
    pointer.moveTo(cx - 12, cy + 24);
    pointer.lineTo(cx, height - 12);
    pointer.lineTo(cx + 12, cy + 24);
    pointer.close();
    canvas.drawPath(pointer, Paint()..color = const Color(0xFF05D5AA));

    // Main circle
    canvas.drawCircle(const Offset(cx, cy), 32, Paint()..color = const Color(0xFF05D5AA));
    canvas.drawCircle(const Offset(cx, cy), 28, Paint()..color = const Color(0xFF131A2A));

    // Moto Icon
    final tp = TextPainter(
      text: const TextSpan(text: '🏍️', style: TextStyle(fontSize: 24)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final descriptor = BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    _markerCache[cacheKey] = descriptor;
    return descriptor;
  }

  /// Extracts 1 or 2 uppercase initials from a name (e.g. "John Doe" -> "JD")
  static String _extractInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'ST';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  /// High-contrast, state-of-the-art Cyber Dark mode styling JSON for Google Maps
  static const String darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#0d131f"
      }
    ]
  },
  {
    "elementType": "labels.icon",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#8b9bb4"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#0d131f"
      }
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#1f2937"
      }
    ]
  },
  {
    "featureType": "administrative.country",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#9ca3af"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#151d2d"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#6b7280"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#111f26"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#1c2638"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#9ca3af"
      }
    ]
  },
  {
    "featureType": "road.arterial",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#223147"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#2a3d58"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#182333"
      }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#1a2536"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#081b29"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#05d5aa"
      }
    ]
  }
]
''';
}
