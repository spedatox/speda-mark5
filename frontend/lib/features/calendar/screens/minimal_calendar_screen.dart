import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/speda_theme.dart';
import '../../../core/models/api_response.dart';
import '../../../core/services/api_service.dart';
import '../providers/calendar_provider.dart';

/// Ultra-minimal calendar screen - 2026 design
class MinimalCalendarScreen extends StatefulWidget {
  const MinimalCalendarScreen({super.key});

  @override
  State<MinimalCalendarScreen> createState() => _MinimalCalendarScreenState();
}

class _MinimalCalendarScreenState extends State<MinimalCalendarScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEvents();
    });
  }

  void _loadEvents() {
    final start = _selectedDate.subtract(const Duration(days: 3));
    final end = _selectedDate.add(const Duration(days: 4));
    context.read<CalendarProvider>().loadEvents(startDate: start, endDate: end);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpedaColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildDateChips(),
            Expanded(child: _buildEventList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Menu button
          GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: const Icon(
              Icons.menu_rounded,
              size: 26,
              color: SpedaColors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calendar',
                  style: SpedaTypography.heading.copyWith(
                    fontSize: 24,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, MMMM d').format(_selectedDate),
                  style: SpedaTypography.bodySmall.copyWith(
                    color: SpedaColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // Today button
          GestureDetector(
            onTap: () {
              setState(() => _selectedDate = DateTime.now());
              _loadEvents();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: SpedaColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Today',
                style: SpedaTypography.label.copyWith(
                  color: SpedaColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChips() {
    final today = DateTime.now();
    final days = List.generate(7, (i) => today.add(Duration(days: i - 3)));

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = _isSameDay(day, _selectedDate);
          final isToday = _isSameDay(day, today);

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = day);
              _loadEvents();
            },
            child: Container(
              width: 52,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? SpedaColors.primary : SpedaColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: isToday && !isSelected
                    ? Border.all(color: SpedaColors.primary.withAlpha(100))
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(day).substring(0, 2),
                    style: SpedaTypography.caption.copyWith(
                      color: isSelected
                          ? SpedaColors.background
                          : SpedaColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    day.day.toString(),
                    style: SpedaTypography.title.copyWith(
                      color: isSelected
                          ? SpedaColors.background
                          : SpedaColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildEventList() {
    return Consumer<CalendarProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: SpedaColors.primary,
              strokeWidth: 2,
            ),
          );
        }

        // Get events for selected date from provider
        final dayEvents = provider.getEventsForDate(_selectedDate);

        if (dayEvents.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: dayEvents.length,
          itemBuilder: (context, index) {
            final event = dayEvents[index];
            // Handle both GoogleCalendarEvent and EventModel
            return _buildEventTile(event);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SpedaColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.event_available_rounded,
              size: 48,
              color: SpedaColors.textTertiary.withAlpha(100),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No events',
            style: SpedaTypography.title,
          ),
          const SizedBox(height: 8),
          Text(
            'Your day is clear',
            style: SpedaTypography.bodySmall.copyWith(
              color: SpedaColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTile(dynamic event) {
    // Handle both GoogleCalendarEvent and EventModel
    String title;
    String startTime;
    String endTime;
    String? location;
    bool isAllDay = false;

    if (event is GoogleCalendarEvent) {
      title = event.summary;
      startTime =
          event.start != null ? DateFormat('h:mm a').format(event.start!) : '';
      endTime =
          event.end != null ? DateFormat('h:mm a').format(event.end!) : '';
      location = event.location;
      isAllDay = event.isAllDay;
    } else if (event is EventModel) {
      title = event.title;
      startTime = DateFormat('h:mm a').format(event.startTime);
      endTime = DateFormat('h:mm a').format(event.endTime);
      location = event.location;
      isAllDay = event.allDay;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: SpedaColors.surface,
        borderRadius: BorderRadius.circular(SpedaRadius.lg),
        border: Border.all(color: SpedaColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Time column
            SizedBox(
              width: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAllDay ? 'All day' : startTime,
                    style: SpedaTypography.label.copyWith(
                      color: SpedaColors.primary,
                    ),
                  ),
                  if (!isAllDay) ...[
                    const SizedBox(height: 2),
                    Text(
                      endTime,
                      style: SpedaTypography.caption,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Divider line
            Container(
              width: 2,
              height: 40,
              decoration: BoxDecoration(
                color: SpedaColors.primary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 16),

            // Event details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SpedaTypography.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (location != null && location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: SpedaColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: SpedaTypography.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
