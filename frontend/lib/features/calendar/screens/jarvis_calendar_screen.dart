import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/jarvis_theme.dart';
import '../../../core/widgets/hud_widgets.dart';
import '../../../core/widgets/animated_widgets.dart';
import '../../../core/services/api_service.dart';
import '../providers/calendar_provider.dart';

/// JARVIS-style calendar screen
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Initial load - load a week of events
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      context.read<CalendarProvider>().loadEvents(
        startDate: now.subtract(const Duration(days: 3)),
        endDate: now.add(const Duration(days: 4)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisColors.background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: HexagonPattern(color: JarvisColors.primary),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildDateSelector(),
                const Divider(color: JarvisColors.panelBorder, height: 1),
                Expanded(child: _buildEventList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            color: JarvisColors.primary,
            margin: const EdgeInsets.only(right: 12),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CALENDAR',
                  style: TextStyle(
                    color: JarvisColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
                Text(
                  'SCHEDULE OVERVIEW',
                  style: TextStyle(
                    color: JarvisColors.textMuted,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          _buildMiniClock(),
        ],
      ),
    );
  }

  Widget _buildMiniClock() {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final now = DateTime.now();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: JarvisColors.panelBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.access_time,
                color: JarvisColors.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontFamily: JarvisTheme.fontFamily,
                  color: JarvisColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateSelector() {
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.add(Duration(days: i - 3)));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: days.map((date) {
          final isSelected = date.day == _selectedDate.day &&
              date.month == _selectedDate.month;
          final isToday = date.day == now.day && date.month == now.month;

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? JarvisColors.primary.withOpacity(0.2)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? JarvisColors.primary
                      : isToday
                          ? JarvisColors.primary.withOpacity(0.3)
                          : Colors.transparent,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  Text(
                    _getDayName(date.weekday),
                    style: TextStyle(
                      color: isSelected
                          ? JarvisColors.primary
                          : JarvisColors.textMuted,
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: isSelected
                          ? JarvisColors.primary
                          : JarvisColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  if (isToday)
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: const BoxDecoration(
                        color: JarvisColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[weekday - 1];
  }

  Widget _buildEventList() {
    return Consumer<CalendarProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(
            child: ArcLoader(size: 60),
          );
        }

        final events = provider.getEventsForDate(_selectedDate);
        
        if (events.isEmpty) {
          return _buildEmptyState(provider.googleConnected);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            if (event is GoogleCalendarEvent) {
              return _buildGoogleEventTile(event);
            } else {
              return _buildEventTile(event);
            }
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool googleConnected) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available,
            size: 64,
            color: JarvisColors.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'NO SCHEDULED EVENTS',
            style: TextStyle(
              color: JarvisColors.textMuted,
              fontSize: 14,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            googleConnected 
                ? 'Calendar is clear for this date'
                : 'Connect Google in Settings to see your calendar',
            style: const TextStyle(
              color: JarvisColors.textMuted,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleEventTile(GoogleCalendarEvent event) {
    final startTime = event.start;
    final endTime = event.end;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (event.isAllDay)
                  const Text(
                    'ALL DAY',
                    style: TextStyle(
                      color: JarvisColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  )
                else if (startTime != null) ...[
                  Text(
                    _formatTime(startTime),
                    style: const TextStyle(
                      color: JarvisColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1,
                    ),
                  ),
                  if (endTime != null)
                    Text(
                      _formatTime(endTime),
                      style: const TextStyle(
                        color: JarvisColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ],
            ),
          ),

          // Timeline indicator
          Container(
            width: 32,
            alignment: Alignment.center,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: JarvisColors.accent.withOpacity(0.3),
                    border: Border.all(color: JarvisColors.accent, width: 2),
                  ),
                ),
                Container(
                  width: 2,
                  height: 60,
                  color: JarvisColors.panelBorder,
                ),
              ],
            ),
          ),

          // Event card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: JarvisColors.panelBackground,
                border: Border.all(color: JarvisColors.accent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.g_mobiledata, color: JarvisColors.accent, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.summary.toUpperCase(),
                          style: const TextStyle(
                            color: JarvisColors.textPrimary,
                            fontSize: 13,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (event.location != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: JarvisColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location!,
                            style: const TextStyle(
                              color: JarvisColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTile(event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(event.startTime),
                  style: const TextStyle(
                    color: JarvisColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  _formatTime(event.endTime),
                  style: const TextStyle(
                    color: JarvisColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Timeline indicator
          Container(
            width: 32,
            alignment: Alignment.center,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: JarvisColors.primary, width: 2),
                  ),
                ),
                Container(
                  width: 2,
                  height: 60,
                  color: JarvisColors.panelBorder,
                ),
              ],
            ),
          ),

          // Event card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: JarvisColors.panelBackground,
                border: Border.all(color: JarvisColors.panelBorder),
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title.toUpperCase(),
                        style: const TextStyle(
                          color: JarvisColors.textPrimary,
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                      ),
                      if (event.location != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 12,
                              color: JarvisColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              event.location!,
                              style: const TextStyle(
                                color: JarvisColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  // Corner accents
                  const Positioned(
                    top: -16,
                    left: -16,
                    child: HudCorner(position: CornerPosition.topLeft, size: 6),
                  ),
                  const Positioned(
                    top: -16,
                    right: -16,
                    child:
                        HudCorner(position: CornerPosition.topRight, size: 6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
