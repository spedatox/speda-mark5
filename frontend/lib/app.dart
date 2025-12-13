import 'package:flutter/material.dart';

import 'core/theme/jarvis_theme.dart';
import 'core/navigation/app_router.dart';

class SpedaApp extends StatelessWidget {
  const SpedaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speda',
      debugShowCheckedModeBanner: false,
      theme: JarvisTheme.darkTheme,
      darkTheme: JarvisTheme.darkTheme,
      themeMode: ThemeMode.dark,
      initialRoute: AppRouter.chat,
      onGenerateRoute: AppRouter.generateRoute,
      builder: (context, child) {
        // Force FSIndustrie as default text style to avoid any inheritance misses
        final base = Theme.of(context).textTheme.bodyMedium ??
            const TextStyle(fontSize: 14, fontFamily: JarvisTheme.fontFamily);
        return DefaultTextStyle(
          style: base.copyWith(fontFamily: JarvisTheme.fontFamily),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
