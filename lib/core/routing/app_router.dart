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

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/features/child_session/day_arc_screen.dart';
import 'package:temanku/features/child_session/match_mode_screen.dart';
import 'package:temanku/features/child_session/speak_mode_screen.dart';
import 'package:temanku/features/child_session/tap_mode_screen.dart';
import 'package:temanku/features/guardian/child_settings_screen.dart';
import 'package:temanku/features/guardian/guardian_home_placeholder.dart';
import 'package:temanku/features/guardian/photo_library_screen.dart';
import 'package:temanku/features/guardian/photo_upload_screen.dart';
import 'package:temanku/features/onboarding/intake_screen.dart';
import 'package:temanku/features/onboarding/select_child_screen.dart';

abstract final class Routes {
  static const selectChild = '/';
  static const childSession = '/session/:childId';
  static const matchSession = '/session/:childId/match/:module';
  static const tapSession = '/session/:childId/tap/:module';
  static const speakSession = '/session/:childId/speak/:module';
  static const guardianHome = '/guardian/:childId';
  static const childSettings = '/guardian/:childId/settings';
  static const photoUpload = '/guardian/:childId/upload/:module';
  static const photoLibrary = '/guardian/:childId/photos/:module';
  static const intake = '/intake/:childId';

  static String sessionFor(String childId) => '/session/$childId';
  static String matchSessionFor(String childId, ModuleId module) =>
      '/session/$childId/match/${module.name}';
  static String tapSessionFor(String childId, ModuleId module) =>
      '/session/$childId/tap/${module.name}';
  static String speakSessionFor(String childId, ModuleId module) =>
      '/session/$childId/speak/${module.name}';
  static String guardianFor(String childId) => '/guardian/$childId';
  static String childSettingsFor(String childId) => '/guardian/$childId/settings';
  static String photoUploadFor(String childId, ModuleId module) =>
      '/guardian/$childId/upload/${module.name}';
  static String photoLibraryFor(String childId, ModuleId module) =>
      '/guardian/$childId/photos/${module.name}';
  static String intakeFor(String childId) => '/intake/$childId';
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
      builder: (context, state) => DayArcScreen(
        childId: state.pathParameters['childId']!,
      ),
    ),
    GoRoute(
      path: Routes.matchSession,
      builder: (context, state) => MatchModeScreen(
        childId: state.pathParameters['childId']!,
        module: ModuleId.values.byName(state.pathParameters['module']!),
      ),
    ),
    GoRoute(
      path: Routes.tapSession,
      builder: (context, state) => TapModeScreen(
        childId: state.pathParameters['childId']!,
        module: ModuleId.values.byName(state.pathParameters['module']!),
      ),
    ),
    GoRoute(
      path: Routes.speakSession,
      builder: (context, state) => SpeakModeScreen(
        childId: state.pathParameters['childId']!,
        module: ModuleId.values.byName(state.pathParameters['module']!),
      ),
    ),
    GoRoute(
      path: Routes.guardianHome,
      builder: (context, state) => GuardianHomePlaceholder(
        childId: state.pathParameters['childId']!,
      ),
    ),
    GoRoute(
      path: Routes.childSettings,
      builder: (context, state) => ChildSettingsScreen(
        childId: state.pathParameters['childId']!,
      ),
    ),
    GoRoute(
      path: Routes.photoUpload,
      builder: (context, state) => PhotoUploadScreen(
        childId: state.pathParameters['childId']!,
        module: ModuleId.values.byName(state.pathParameters['module']!),
      ),
    ),
    GoRoute(
      path: Routes.photoLibrary,
      builder: (context, state) => PhotoLibraryScreen(
        childId: state.pathParameters['childId']!,
        module: ModuleId.values.byName(state.pathParameters['module']!),
      ),
    ),
    GoRoute(
      path: Routes.intake,
      builder: (context, state) => IntakeScreen(
        childId: state.pathParameters['childId']!,
      ),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Route not found: ${state.uri}')),
  ),
);
