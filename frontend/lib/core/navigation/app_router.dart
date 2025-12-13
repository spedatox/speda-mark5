import 'package:flutter/material.dart';

import '../widgets/main_scaffold.dart';

/// Application router for navigation.
class AppRouter {
  AppRouter._();

  // Route names
  static const String chat = '/';
  static const String tasks = '/tasks';
  static const String calendar = '/calendar';
  static const String briefing = '/briefing';

  /// Generate route based on settings.
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case chat:
        return MaterialPageRoute(
          builder: (_) => const MainScaffold(initialIndex: 0),
        );
      case tasks:
        return MaterialPageRoute(
          builder: (_) => const MainScaffold(initialIndex: 1),
        );
      case calendar:
        return MaterialPageRoute(
          builder: (_) => const MainScaffold(initialIndex: 2),
        );
      case briefing:
        return MaterialPageRoute(
          builder: (_) => const MainScaffold(initialIndex: 3),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const MainScaffold(initialIndex: 0),
        );
    }
  }
}
