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
import 'speda_drawer.dart';

/// Main scaffold - Chat is primary, other screens accessed via drawer
class MainScaffold extends StatefulWidget {
  final int initialIndex;

  const MainScaffold({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainScaffold> createState() => MainScaffoldState();
}

class MainScaffoldState extends State<MainScaffold> {
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
  }

  void navigateTo(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
      _refreshDataForTab(index);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpedaColors.background,
      drawer: SpedaDrawer(
        onNavigation: (index) => navigateTo(index),
      ), // Global drawer
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
    );
  }
}
