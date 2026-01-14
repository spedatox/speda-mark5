import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/speda_theme.dart';
import '../../features/chat/screens/minimal_chat_screen.dart';
import '../../features/tasks/screens/minimal_tasks_screen.dart';
import '../../features/calendar/screens/minimal_calendar_screen.dart';
import '../../features/briefing/screens/minimal_briefing_screen.dart';
import '../../features/voice/screens/minimal_voice_screen.dart';
import '../../features/settings/screens/minimal_settings_screen.dart';
import '../../features/tasks/providers/task_provider.dart';
import '../../features/calendar/providers/calendar_provider.dart';
import '../../features/briefing/providers/briefing_provider.dart';

/// Main scaffold with minimal bottom navigation.
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
    MinimalChatScreen(),
    MinimalVoiceScreen(),
    MinimalTasksScreen(),
    MinimalCalendarScreen(),
    MinimalBriefingScreen(),
    MinimalSettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshDataForTab(_currentIndex);
    });
  }

  void _refreshDataForTab(int index) {
    switch (index) {
      case 2: // Tasks
        context.read<TaskProvider>().loadTasks();
        break;
      case 3: // Calendar
        final now = DateTime.now();
        context.read<CalendarProvider>().loadEvents(
              startDate: now.subtract(const Duration(days: 3)),
              endDate: now.add(const Duration(days: 4)),
            );
        break;
      case 4: // Briefing
        context.read<BriefingProvider>().loadBriefing();
        break;
    }
  }

  void _onTabChanged(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
      _refreshDataForTab(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpedaColors.background,
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
        color: SpedaColors.surface,
        border: Border(
          top: BorderSide(color: SpedaColors.border, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.chat_bubble_outline_rounded,
                  Icons.chat_bubble_rounded, 'Chat'),
              _buildNavItem(
                  1, Icons.mic_none_rounded, Icons.mic_rounded, 'Voice'),
              _buildNavItem(2, Icons.check_circle_outline_rounded,
                  Icons.check_circle_rounded, 'Tasks'),
              _buildNavItem(3, Icons.calendar_today_outlined,
                  Icons.calendar_today_rounded, 'Calendar'),
              _buildNavItem(4, Icons.wb_sunny_outlined, Icons.wb_sunny_rounded,
                  'Briefing'),
              _buildNavItem(5, Icons.settings_outlined, Icons.settings_rounded,
                  'Settings'),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color:
                  isSelected ? SpedaColors.primary : SpedaColors.textTertiary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                color:
                    isSelected ? SpedaColors.primary : SpedaColors.textTertiary,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
