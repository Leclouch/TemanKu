/// Navigation — go_router.
///
/// **Choice noted for IT-1/IT-2:** go_router over raw Navigator 2.0. The
/// architecture doc left this open. go_router because the flows here are shallow
/// and named (select child → session, select child → guardian home), and because
/// a declarative route table is one shared file two developers can both read
/// without either owning the other's screens — hand-rolling a RouterDelegate
/// would be strictly more code for strictly less clarity on a 5-day build.
///
/// Routes deliberately carry `childId` in the path rather than in a provider:
/// the multi-child model (§9) means "which child" is never ambient state, and a
/// route that can't be built without a child id can't accidentally render the
/// wrong one.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:temanku/features/child_session/child_session_placeholder.dart';
import 'package:temanku/features/guardian/guardian_home_placeholder.dart';
import 'package:temanku/features/onboarding/select_child_screen.dart';

abstract final class Routes {
  static const selectChild = '/';
  static const childSession = '/session/:childId';
  static const guardianHome = '/guardian/:childId';

  static String sessionFor(String childId) => '/session/$childId';
  static String guardianFor(String childId) => '/guardian/$childId';
}

final appRouter = GoRouter(
  initialLocation: Routes.selectChild,
  routes: [
    GoRoute(
      path: Routes.selectChild,
      builder: (context, state) => const SelectChildScreen(),
    ),
    GoRoute(
      path: Routes.childSession,
      builder: (context, state) => ChildSessionPlaceholder(
        childId: state.pathParameters['childId']!,
      ),
    ),
    GoRoute(
      path: Routes.guardianHome,
      builder: (context, state) => GuardianHomePlaceholder(
        childId: state.pathParameters['childId']!,
      ),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Route not found: ${state.uri}')),
  ),
);
