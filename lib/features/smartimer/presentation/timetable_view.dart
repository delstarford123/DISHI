import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/timetable_event.dart';
import 'widgets/event_editor_dialog.dart';
import '../utils/pdf_generator.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class TimetableView extends StatefulWidget {
  const TimetableView({super.key});

  @override
  State<TimetableView> createState() => _TimetableViewState();
}

class _TimetableViewState extends State<TimetableView> {
  late final ValueNotifier<List<TimetableEvent>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // In-memory state for events.
  final Map<DateTime, List<TimetableEvent>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    
    // Seed some example events based on the professional structure
    _seedExampleEvents();
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  void _seedExampleEvents() {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    
    _events[normalizedToday] = [
      TimetableEvent.create(
        title: 'Deep Work: Project Architecture',
        type: EventType.deepWork,
        startTime: DateTime(today.year, today.month, today.day, 8, 0),
        endTime: DateTime(today.year, today.month, today.day, 10, 0),
      ),
      TimetableEvent.create(
        title: 'Structured Break / Coffee',
        type: EventType.breakBlock,
        startTime: DateTime(today.year, today.month, today.day, 10, 0),
        endTime: DateTime(today.year, today.month, today.day, 10, 30),
      ),
      TimetableEvent.create(
        title: 'Admin Buffer: Emails & Expenses',
        type: EventType.adminBuffer,
        startTime: DateTime(today.year, today.month, today.day, 14, 0),
        endTime: DateTime(today.year, today.month, today.day, 15, 0),
      ),
    ];
  }

  List<TimetableEvent> _getEventsForDay(DateTime day) {
    // TableCalendar normalizes DateTime to UTC midnight, we need to match it.
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  void _openEventEditor({TimetableEvent? existingEvent}) {
    showDialog(
      context: context,
      builder: (_) => EventEditorDialog(
        selectedDate: _selectedDay ?? _focusedDay,
        existingEvent: existingEvent,
        onSave: (event) {
          final normalizedDay = DateTime(event.startTime.year, event.startTime.month, event.startTime.day);
          setState(() {
            if (existingEvent != null) {
              // Remove old
              final oldNormalized = DateTime(existingEvent.startTime.year, existingEvent.startTime.month, existingEvent.startTime.day);
              _events[oldNormalized]?.removeWhere((e) => e.id == event.id);
            }
            // Add new
            if (_events[normalizedDay] == null) {
              _events[normalizedDay] = [];
            }
            _events[normalizedDay]!.add(event);
            _events[normalizedDay]!.sort((a, b) => a.startTime.compareTo(b.startTime));
          });
          _selectedEvents.value = _getEventsForDay(_selectedDay!);
        },
        onDelete: (id) {
          setState(() {
            final oldNormalized = DateTime(existingEvent!.startTime.year, existingEvent.startTime.month, existingEvent.startTime.day);
            _events[oldNormalized]?.removeWhere((e) => e.id == id);
          });
          _selectedEvents.value = _getEventsForDay(_selectedDay!);
        },
      ),
    );
  }

  Future<void> _exportPdf() async {
    // Flatten all events from the map
    final allEvents = _events.values.expand((element) => element).toList();
    if (allEvents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No events to export.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preparing PDF preview...', style: TextStyle(color: Colors.black)), backgroundColor: _neonCyan));
    await TimetablePdfGenerator.generateAndPrintPdf(allEvents);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Visual Timetable', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: _neonCyan),
            tooltip: 'Export as PDF',
            onPressed: _exportPdf,
          )
        ],
      ),
      body: Column(
        children: [
          // The Calendar
          Container(
            color: _cardColor,
            child: TableCalendar<TimetableEvent>(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)), // Up to 4 months/years
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: _calendarFormat,
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarStyle: const CalendarStyle(
                defaultTextStyle: TextStyle(color: Colors.white),
                weekendTextStyle: TextStyle(color: Colors.white54),
                outsideTextStyle: TextStyle(color: Colors.white24),
                todayDecoration: BoxDecoration(color: _surfaceLight, shape: BoxShape.circle),
                selectedDecoration: BoxDecoration(color: _neonCyan, shape: BoxShape.circle),
                markerDecoration: BoxDecoration(color: _neonPink, shape: BoxShape.circle),
              ),
              headerStyle: const HeaderStyle(
                titleTextStyle: TextStyle(color: Colors.white, fontSize: 16),
                formatButtonTextStyle: TextStyle(color: Colors.white),
                formatButtonDecoration: BoxDecoration(
                  border: Border.fromBorderSide(BorderSide(color: Colors.white54)),
                  borderRadius: BorderRadius.all(Radius.circular(12.0)),
                ),
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: _textSecondary),
                weekendStyle: TextStyle(color: _textSecondary),
              ),
              onDaySelected: _onDaySelected,
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                }
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
            ),
          ),
          const SizedBox(height: 8),
          
          // Event List for Selected Day
          Expanded(
            child: ValueListenableBuilder<List<TimetableEvent>>(
              valueListenable: _selectedEvents,
              builder: (context, value, _) {
                if (value.isEmpty) {
                  return const Center(child: Text('No events for this day.', style: TextStyle(color: _textSecondary)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: value.length,
                  itemBuilder: (context, index) {
                    final event = value[index];
                    return InkWell(
                      onTap: () => _openEventEditor(existingEvent: event),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: event.color.withOpacity(0.5)),
                          boxShadow: [
                            BoxShadow(color: event.color.withOpacity(0.05), blurRadius: 10, spreadRadius: 1)
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: event.color.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.event, color: event.color),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(event.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${DateFormat('HH:mm').format(event.startTime)} - ${DateFormat('HH:mm').format(event.endTime)}',
                                    style: const TextStyle(color: _textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.edit, color: _surfaceLight, size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _neonCyan,
        onPressed: () => _openEventEditor(),
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Add Block', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
