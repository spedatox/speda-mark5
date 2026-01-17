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
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'morning'
        : hour < 17
            ? 'afternoon'
            : 'evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top row with SPEDA Logo and date
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // SPEDA Logo (opens drawer)
            GestureDetector(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: SpedaColors.surface,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/speda_ui_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Title
            Expanded(
              child: Text(
                'brIefIng',
                style: TextStyle(
                  fontFamily: 'Logirent',
                  fontSize: 26,
                  color: SpedaColors.textPrimary,
                ),
              ),
            ),
            // Date indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: SpedaColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                DateFormat('MMM d').format(DateTime.now()).toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: SpedaColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Personalized greeting
        Text(
          'Good $timeGreeting, Ahmet Erol.',
          style: SpedaTypography.heading.copyWith(
            fontSize: 22,
            color: SpedaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          greeting,
          style: SpedaTypography.body.copyWith(
            color: SpedaColors.textSecondary,
          ),
        ),
      ],
    );
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1A24),
            Color(0xFF121218),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: iconColor.withOpacity(0.3),
          width: 1,
        ),
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
