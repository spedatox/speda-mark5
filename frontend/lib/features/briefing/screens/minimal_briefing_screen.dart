import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/speda_theme.dart';
import '../../../core/models/api_response.dart';
import '../providers/briefing_provider.dart';

/// Ultra-minimal briefing screen - 2026 design
class MinimalBriefingScreen extends StatefulWidget {
  const MinimalBriefingScreen({super.key});

  @override
  State<MinimalBriefingScreen> createState() => _MinimalBriefingScreenState();
}

class _MinimalBriefingScreenState extends State<MinimalBriefingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BriefingProvider>().loadBriefing();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpedaColors.background,
      body: SafeArea(
        child: Consumer<BriefingProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  color: SpedaColors.primary,
                  strokeWidth: 2,
                ),
              );
            }

            final briefing = provider.briefing;
            if (briefing == null) {
              return _buildEmptyState();
            }

            return RefreshIndicator(
              onRefresh: () => provider.loadBriefing(),
              color: SpedaColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(briefing.greeting),
                    const SizedBox(height: 24),
                    if (briefing.weather != null)
                      _buildWeatherCard(briefing.weather!),
                    if (briefing.eventsToday.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildEventsCard(briefing.eventsToday),
                    ],
                    if (briefing.tasksPending.isNotEmpty ||
                        briefing.tasksOverdue.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildTasksCard([
                        ...briefing.tasksOverdue,
                        ...briefing.tasksPending,
                      ]),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(String greeting) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top row with Menu Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(
                    bottom: 16,
                    left: 4), // Negative margin visually? No, just padding
                decoration: BoxDecoration(
                  color: SpedaColors.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.menu_rounded,
                  size: 24,
                  color: SpedaColors.textSecondary,
                ),
              ),
            ),
          ],
        ),

        Text(
          'Good ${_getTimeOfDay()}',
          style: SpedaTypography.displayLarge.copyWith(
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          greeting,
          style: SpedaTypography.body.copyWith(
            color: SpedaColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wb_sunny_outlined,
            size: 64,
            color: SpedaColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'No briefing available',
            style: SpedaTypography.title,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.read<BriefingProvider>().loadBriefing(),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard(WeatherInfo weather) {
    return _buildCard(
      icon: Icons.wb_sunny_rounded,
      iconColor: SpedaColors.warning,
      title: 'Weather in ${weather.location}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Temperature display
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${weather.temperature.round()}°',
                style: SpedaTypography.displayLarge.copyWith(
                  fontSize: 56,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.arrow_upward_rounded,
                      size: 14, color: SpedaColors.error),
                  Text(
                    '${weather.high.round()}°',
                    style: SpedaTypography.label.copyWith(
                      color: SpedaColors.error,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.arrow_downward_rounded,
                      size: 14, color: SpedaColors.primary),
                  Text(
                    '${weather.low.round()}°',
                    style: SpedaTypography.label.copyWith(
                      color: SpedaColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Condition display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: SpedaColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              weather.condition,
              style: SpedaTypography.body.copyWith(
                color: SpedaColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsCard(List<BriefingEvent> events) {
    return _buildCard(
      icon: Icons.calendar_today_rounded,
      iconColor: SpedaColors.primary,
      title: 'Today\'s Schedule',
      child: Column(
        children: events.take(3).map((event) {
          final timeStr = DateFormat('h:mm a').format(event.startTime);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 40,
                  decoration: BoxDecoration(
                    color: SpedaColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: SpedaTypography.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeStr,
                        style: SpedaTypography.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTasksCard(List<BriefingTask> tasks) {
    return _buildCard(
      icon: Icons.check_circle_outline_rounded,
      iconColor: SpedaColors.success,
      title: 'Tasks (${tasks.length})',
      child: Column(
        children: tasks.take(5).map((task) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: task.isOverdue
                          ? SpedaColors.error
                          : SpedaColors.textTertiary,
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    task.title,
                    style: SpedaTypography.body.copyWith(
                      color: task.isOverdue
                          ? SpedaColors.error
                          : SpedaColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (task.isOverdue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: SpedaColors.error.withAlpha(25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Overdue',
                      style: SpedaTypography.caption.copyWith(
                        color: SpedaColors.error,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SpedaColors.surface,
        borderRadius: BorderRadius.circular(SpedaRadius.lg),
        border: Border.all(color: SpedaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: SpedaTypography.label.copyWith(
                  color: SpedaColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
