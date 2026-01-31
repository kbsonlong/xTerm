import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';
import 'theme.dart';

class XTermApp extends StatelessWidget {
  const XTermApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'xTerm',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }

  GoRouter get _router => GoRouter(
        routes: appRoutes,
        initialLocation: '/',
        debugLogDiagnostics: false,
      );
}