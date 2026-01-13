import 'package:flutter/material.dart';

import 'core/theme/speda_theme.dart';
import 'core/navigation/app_router.dart';

class SpedaApp extends StatelessWidget {
  const SpedaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SPEDA',
      debugShowCheckedModeBanner: false,
      theme: SpedaTheme.dark,
      darkTheme: SpedaTheme.dark,
      themeMode: ThemeMode.dark,
      initialRoute: AppRouter.chat,
      onGenerateRoute: AppRouter.generateRoute,
      builder: (context, child) {
        // Force Inter as default text style
        final base = Theme.of(context).textTheme.bodyMedium ??
            const TextStyle(fontSize: 14, fontFamily: 'Inter');
        return DefaultTextStyle(
          style: base.copyWith(fontFamily: 'Inter'),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
