import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/jarvis_theme.dart';
import '../../features/chat/screens/jarvis_chat_screen.dart';
import '../../features/tasks/screens/jarvis_tasks_screen.dart';
import '../../features/calendar/screens/jarvis_calendar_screen.dart';
import '../../features/briefing/screens/jarvis_briefing_screen.dart';
import '../../features/tasks/providers/task_provider.dart';
import '../../features/calendar/providers/calendar_provider.dart';

/// Main scaffold with JARVIS-style bottom navigation.
class MainScaffold extends StatefulWidget {
  final int initialIndex;

  const MainScaffold({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _currentIndex;

  final List<Widget> _screens = const [
    ChatScreen(),
    TasksScreen(),
    CalendarScreen(),
    BriefingScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    // Refresh data for initial tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshDataForTab(_currentIndex);
    });
  }

  /// Refresh data when switching to a tab
  void _refreshDataForTab(int index) {
    switch (index) {
      case 1: // Tasks
        context.read<TaskProvider>().loadTasks();
        break;
      case 2: // Calendar - load a week of events
        final now = DateTime.now();
        context.read<CalendarProvider>().loadEvents(
          startDate: now.subtract(const Duration(days: 3)),
          endDate: now.add(const Duration(days: 4)),
        );
        break;
    }
  }

  /// Handle tab change
  void _onTabChanged(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
      _refreshDataForTab(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: JarvisColors.surface.withOpacity(0.95),
        border: const Border(
          top: BorderSide(color: JarvisColors.panelBorder),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                  0, Icons.chat_bubble_outline, Icons.chat_bubble, 'CHAT'),
              _buildNavItem(
                  1, Icons.task_alt_outlined, Icons.task_alt, 'TASKS'),
              _buildNavItem(2, Icons.calendar_today_outlined,
                  Icons.calendar_today, 'CALENDAR'),
              _buildNavItem(
                  3, Icons.dashboard_outlined, Icons.dashboard, 'BRIEFING'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onTabChanged(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                border:
                    Border.all(color: JarvisColors.primary.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(4),
                color: JarvisColors.primary.withOpacity(0.1),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? JarvisColors.primary : JarvisColors.textMuted,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color:
                    isSelected ? JarvisColors.primary : JarvisColors.textMuted,
                fontSize: 9,
                letterSpacing: 1,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
