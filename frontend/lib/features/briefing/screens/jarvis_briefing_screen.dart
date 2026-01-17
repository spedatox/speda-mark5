import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/jarvis_theme.dart';
import '../../../core/widgets/hud_widgets.dart';
import '../../../core/widgets/animated_widgets.dart';
import '../providers/briefing_provider.dart';

/// JARVIS-style daily briefing screen
class BriefingScreen extends StatefulWidget {
  const BriefingScreen({super.key});

  @override
  State<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends State<BriefingScreen> {
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
      backgroundColor: JarvisColors.background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: HexagonPattern(color: JarvisColors.primary),
          ),
          SafeArea(
            child: Consumer<BriefingProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return _buildLoadingState();
                }

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader()),
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildStatusPanel(provider),
                          const SizedBox(height: 16),
                          _buildDateTimePanel(),
                          const SizedBox(height: 16),
                          _buildTasksPanel(provider),
                          const SizedBox(height: 16),
                          _buildEventsPanel(provider),
                          const SizedBox(height: 16),
                          _buildQuickActionsPanel(),
                        ]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ArcLoader(size: 80),
          SizedBox(height: 24),
          Text(
            'LOADING BRIEFING',
            style: TextStyle(
              color: JarvisColors.primary,
              fontSize: 14,
              letterSpacing: 3,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Gathering intelligence...',
            style: TextStyle(
              color: JarvisColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: JarvisColors.panelBorder),
        ),
      ),
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
                  'DAILY BRIEFING',
                  style: TextStyle(
                    color: JarvisColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
                Text(
                  'EXECUTIVE SUMMARY',
                  style: TextStyle(
                    color: JarvisColors.textMuted,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            color: JarvisColors.textMuted,
            onPressed: () => context.read<BriefingProvider>().loadBriefing(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPanel(BriefingProvider provider) {
    return HudPanel(
      title: 'SYSTEM STATUS',
      child: Row(
        children: [
          Expanded(
            child: _buildStatusItem(
              'TASKS',
              provider.briefing?.tasksPending.length.toString() ?? '0',
              Icons.task_alt,
              JarvisColors.warning,
            ),
          ),
          Container(width: 1, height: 50, color: JarvisColors.panelBorder),
          Expanded(
            child: _buildStatusItem(
              'EVENTS',
              provider.briefing?.eventsToday.length.toString() ?? '0',
              Icons.event,
              JarvisColors.primary,
            ),
          ),
          Container(width: 1, height: 50, color: JarvisColors.panelBorder),
          Expanded(
            child: _buildStatusItem(
              'EMAILS',
              provider.briefing?.pendingEmails.length.toString() ?? '0',
              Icons.email,
              JarvisColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.w200,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: JarvisColors.textMuted,
            fontSize: 9,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimePanel() {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final now = DateTime.now();
        return HudPanel(
          title: 'DATE & TIME',
          showScanLine: false,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontFamily: JarvisTheme.fontFamily,
                        color: JarvisColors.primary,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                      ),
                    ),
                    Text(
                      _getFullDate(now),
                      style: const TextStyle(
                        fontFamily: JarvisTheme.fontFamily,
                        color: JarvisColors.textSecondary,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              ProgressArc(
                progress: now.hour / 24,
                size: 60,
                color: JarvisColors.primary,
                child: Text(
                  '${((now.hour / 24) * 100).round()}%',
                  style: const TextStyle(
                    fontFamily: JarvisTheme.fontFamily,
                    color: JarvisColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getFullDate(DateTime date) {
    const months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER'
    ];
    const days = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY'
    ];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildTasksPanel(BriefingProvider provider) {
    final tasks = provider.briefing?.tasksPending ?? [];

    return HudPanel(
      title: 'UPCOMING TASKS',
      subtitle: '${tasks.length} items pending',
      child: tasks.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No pending tasks',
                  style: TextStyle(color: JarvisColors.textMuted),
                ),
              ),
            )
          : Column(
              children: tasks.take(3).map((task) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: JarvisColors.panelBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: JarvisColors.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          task.title.toUpperCase(),
                          style: const TextStyle(
                            color: JarvisColors.textPrimary,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (task.dueDate != null)
                        Text(
                          '${task.dueDate!.day}.${task.dueDate!.month}',
                          style: const TextStyle(
                            color: JarvisColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildEventsPanel(BriefingProvider provider) {
    final events = provider.briefing?.eventsToday ?? [];

    return HudPanel(
      title: 'TODAY\'S SCHEDULE',
      subtitle: '${events.length} events',
      child: events.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No events scheduled',
                  style: TextStyle(color: JarvisColors.textMuted),
                ),
              ),
            )
          : Column(
              children: events.take(3).map((event) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: JarvisColors.panelBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: Text(
                          '${event.startTime.hour.toString().padLeft(2, '0')}:${event.startTime.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontFamily: JarvisTheme.fontFamily,
                            color: JarvisColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 20,
                        color: JarvisColors.primary,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      Expanded(
                        child: Text(
                          event.title.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: JarvisTheme.fontFamily,
                            color: JarvisColors.textPrimary,
                            fontSize: 12,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildQuickActionsPanel() {
    return HudPanel(
      title: 'QUICK ACTIONS',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          HudButton(
            label: 'NEW TASK',
            icon: Icons.add_task,
            onPressed: () {},
          ),
          HudButton(
            label: 'NEW EVENT',
            icon: Icons.event,
            onPressed: () {},
          ),
          HudButton(
            label: 'COMPOSE',
            icon: Icons.email,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
