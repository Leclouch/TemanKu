import 'package:flutter/material.dart';

import 'package:temanku/core/routing/app_router.dart';
import 'package:temanku/core/theme/temanku_theme.dart';

/// Root widget.
///
/// The app-level theme is the **guardian** temperature, because the entry point
/// (select-child) is a guardian surface. The child session screen wraps itself in
/// the child theme locally — see `ChildSessionPlaceholder`. Both come from
/// `core/theme/`; neither defines a value of its own.
class TemanKuApp extends StatelessWidget {
  const TemanKuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TemanKu',
      debugShowCheckedModeBanner: false,
      theme: TemanKuTheme.guardian,
      routerConfig: appRouter,
    );
  }
}
