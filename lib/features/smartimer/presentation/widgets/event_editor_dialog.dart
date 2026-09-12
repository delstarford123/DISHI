import 'package:flutter/material.dart';
import '../../models/timetable_event.dart';

class EventEditorDialog extends StatefulWidget {
  final DateTime selectedDate;
  final TimetableEvent? existingEvent;
  final Function(TimetableEvent) onSave;
  final Function(String)? onDelete;

  const EventEditorDialog({
    super.key,
    required this.selectedDate,
    required this.onSave,
    this.existingEvent,
    this.onDelete,
  });

  @override
  State<EventEditorDialog> createState() => _EventEditorDialogState();
}

class _EventEditorDialogState extends State<EventEditorDialog> {
  late TextEditingController _titleController;
  late EventType _selectedType;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingEvent?.title ?? '');
    _selectedType = widget.existingEvent?.type ?? EventType.standard;
    
    if (widget.existingEvent != null) {
      _startTime = TimeOfDay.fromDateTime(widget.existingEvent!.startTime);
      _endTime = TimeOfDay.fromDateTime(widget.existingEvent!.endTime);
    } else {
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endTime = const TimeOfDay(hour: 10, minute: 0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final initialTime = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF05D5AA),
              onPrimary: Colors.black,
              surface: Color(0xFF131A2A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _saveEvent() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title.')));
      return;
    }

    final startDateTime = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    
    final endDateTime = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    if (endDateTime.isBefore(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End time must be after start time.')));
      return;
    }

    TimetableEvent event;
    if (widget.existingEvent != null) {
      event = TimetableEvent(
        id: widget.existingEvent!.id,
        title: _titleController.text.trim(),
        type: _selectedType,
        startTime: startDateTime,
        endTime: endDateTime,
        color: TimetableEvent.create(title: '', type: _selectedType, startTime: startDateTime, endTime: endDateTime).color, // quick hack to get updated color
      );
    } else {
      event = TimetableEvent.create(
        title: _titleController.text.trim(),
        type: _selectedType,
        startTime: startDateTime,
        endTime: endDateTime,
      );
    }

    widget.onSave(event);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const Color cardColor = Color(0xFF131A2A);
    const Color neonCyan = Color(0xFF05D5AA);

    return AlertDialog(
      backgroundColor: cardColor,
      title: Text(widget.existingEvent == null ? 'New Event' : 'Edit Event', style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Event Title',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: neonCyan)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Event Type', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            DropdownButtonFormField<EventType>(
              initialValue: _selectedType,
              dropdownColor: cardColor,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: EventType.deepWork, child: Text('Deep Work Block (High Focus)')),
                DropdownMenuItem(value: EventType.adminBuffer, child: Text('Admin Buffer (Routine Tasks)')),
                DropdownMenuItem(value: EventType.breakBlock, child: Text('Structured Break')),
                DropdownMenuItem(value: EventType.standard, child: Text('Standard Class/Event')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedType = val);
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(context, true),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Start Time', labelStyle: TextStyle(color: Colors.white70), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
                      child: Text(_startTime.format(context), style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(context, false),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'End Time', labelStyle: TextStyle(color: Colors.white70), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
                      child: Text(_endTime.format(context), style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (widget.existingEvent != null && widget.onDelete != null)
          TextButton(
            onPressed: () {
              widget.onDelete!(widget.existingEvent!.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: neonCyan),
          onPressed: _saveEvent,
          child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
