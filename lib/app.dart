import 'package:flutter/material.dart';

import 'package:temanku/core/design/design.dart';
import 'package:temanku/core/routing/app_router.dart';

/// Root widget.
///
/// The app-level theme is the **guardian** temperature, because the entry point
/// (select-child) is a guardian surface. The child-facing screens (day-arc,
/// tap/match/speak) get the child theme from [TkChildScreen], which applies it
/// locally around their own body. Both come from `core/design/`; neither
/// defines a value of its own.
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
