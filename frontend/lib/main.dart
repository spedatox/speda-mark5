import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'features/chat/providers/chat_provider.dart';
import 'features/tasks/providers/task_provider.dart';
import 'features/calendar/providers/calendar_provider.dart';
import 'features/briefing/providers/briefing_provider.dart';
import 'core/services/api_service.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  final apiService = ApiService(
    baseUrl: AppConfig.apiBaseUrl,
    apiKey: AppConfig.apiKey,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => TaskProvider(apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => CalendarProvider(apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => BriefingProvider(apiService),
        ),
      ],
      child: const SpedaApp(),
    ),
  );
}
