import 'package:flutter/material.dart';

enum EventType {
  deepWork, // Deep Work Blocks
  adminBuffer, // Administrative Buffers
  breakBlock, // Structured Breaks
  standard // Standard / Custom
}

class TimetableEvent {
  final String id;
  final String title;
  final EventType type;
  final DateTime startTime;
  final DateTime endTime;
  final Color color;

  TimetableEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.color,
  });

  factory TimetableEvent.create({
    required String title,
    required EventType type,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    Color eventColor;
    switch (type) {
      case EventType.deepWork:
        eventColor = const Color(0xFFFF2A6D); // _neonPink
        break;
      case EventType.adminBuffer:
        eventColor = Colors.blueAccent;
        break;
      case EventType.breakBlock:
        eventColor = const Color(0xFF05D5AA); // _neonCyan
        break;
      case EventType.standard:
      default:
        eventColor = Colors.orangeAccent;
        break;
    }

    return TimetableEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      type: type,
      startTime: startTime,
      endTime: endTime,
      color: eventColor,
    );
  }
}
