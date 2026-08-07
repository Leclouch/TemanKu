/// "Data lengkap" aggregation — the raw-counts companion to
/// `session_recap.dart`'s narrative sentence and `guardian_home_placeholder.dart`'s
/// categorical milestone timeline.
///
/// §8 draws a hard line: guardian-facing summaries are "descriptive
/// sentences... no percentages, no accuracy stats" and the longitudinal view
/// is "a milestone timeline, not a performance graph". Nothing in this file
/// computes a single reductive score or percentage anywhere, even here in
/// the detailed view — every number below is a plain count, a fraction
/// presented as two counts side by side, or a date. A teacher or therapist
/// who wants the receipts behind the narrative gets raw counts to read for
/// themselves, never a grade this app computed on their behalf.
///
/// Pulls only from data [SessionRepository] already stores —
/// [SessionSummary] for the per-session shape and [TrialLog] for the raw
/// per-trial outcomes — no new tracking field anywhere. One real gap worth
/// naming: nothing in the child-facing mode screens today actually calls
/// [SessionRepository.startSession]/`appendTrialLog`/`endSession` during
/// real play (only the ladder position is persisted, via
/// `engine/advancement/advancement_tracker.dart`'s separate path) — so this
/// view is only ever as populated as whatever a [SessionRepository]
/// implementation's session/trial-log lifecycle actually captures. That is a
/// pre-existing gap in wiring the session lifecycle, not something this file
/// can paper over by inventing data.
library;

import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/child.dart';
import 'package:temanku/data/models/session.dart';
import 'package:temanku/data/repositories/session_repository.dart';

/// One [SimilarityTier] and the first date [SessionSummary.endedAt] shows a
/// session ending with the child's ladder already at that tier, for one
/// (module, mode) pair — i.e. "date reached", read straight off existing
/// session-history timestamps.
class TierMilestone {
  const TierMilestone({required this.tier, required this.reachedAt});

  final SimilarityTier tier;
  final DateTime reachedAt;
}

/// Raw counts for one (module, mode) pair, aggregated across every session
/// [SessionRepository] has on record for it. No field on this class is ever
/// a ratio rendered as a percentage — [independentCorrect] and
/// [independentAttempts] are two counts, presented together, deliberately
/// never divided into one number.
class ModuleModeStats {
  const ModuleModeStats({
    required this.module,
    required this.mode,
    required this.totalTrials,
    required this.independentAttempts,
    required this.independentCorrect,
    required this.currentPosition,
    required this.tierMilestones,
    required this.sessions,
  });

  final ModuleId module;
  final ResponseMode mode;

  /// Every logged trial, hinted or not.
  final int totalTrials;

  /// Trials attempted without a hint — the independent-responding count
  /// [requiredStreakForAdvancement] (`engine/advancement/advancement_tracker.dart`)
  /// is itself built from.
  final int independentAttempts;

  /// Of [independentAttempts], how many were correct. Always read alongside
  /// [independentAttempts] as "X dari Y", never alone.
  final int independentCorrect;

  /// Where the ladder sits right now — the same [LadderPosition] the
  /// milestone timeline card already reads.
  final LadderPosition currentPosition;

  /// Every tier the ladder has passed through, oldest first, each with the
  /// date it was first reached. Never collapsed to just the current one —
  /// a teacher reading the full data wants the whole path.
  final List<TierMilestone> tierMilestones;

  /// This pair's own sessions, newest first — the source rows for the "log
  /// sesi" table (duration, mode, date).
  final List<SessionSummary> sessions;
}

/// Teacher-recognizable plain-language label for [tier] — the internal
/// [SimilarityTier] enum name is never shown as-is. LRFFC ("Listener
/// Responding by Function, Feature, or Class") is spelled out because it is
/// itself a real, standard ABA/VB-MAPP-program term this codebase already
/// treats as such (see `core/constants/domain_enums.dart`'s own doc comment
/// on [SimilarityTier.lrffc]) — not a fabricated milestone number. No
/// specific VB-MAPP level/milestone number is invented here: this app has no
/// clinically validated mapping to one, and guessing at a number tied to a
/// real assessment instrument would mislead the teacher reading it.
String tierLabel(SimilarityTier tier) => switch (tier) {
      SimilarityTier.differentCategory => 'Diskriminasi dasar (kategori yang jelas berbeda)',
      SimilarityTier.sameCategoryDistinct => 'Diskriminasi dalam kategori yang sama',
      SimilarityTier.similar => 'Diskriminasi halus (benda yang mirip)',
      SimilarityTier.lrffc => 'LRFFC — memilih berdasarkan fungsi, fitur, atau kelas',
    };

/// Aggregates every (module, mode) pair with at least one session on record
/// for [childId], sorted by [ModuleId.values] then [ResponseMode.values] —
/// a fixed, predictable order rather than most-recent-first, since this is a
/// reference table, not a feed.
Future<List<ModuleModeStats>> loadFullData(
  SessionRepository repository,
  String childId,
) async {
  final history = await repository.getSessionHistory(childId);
  if (history.isEmpty) return const [];

  // Oldest-first, so tier-milestone detection below walks forward through
  // time — the order [SessionSummary.endedAt] actually happened in.
  final chronological = history.reversed.toList();

  final grouped = <(ModuleId, ResponseMode), List<SessionSummary>>{};
  for (final session in chronological) {
    (grouped[(session.module, session.mode)] ??= []).add(session);
  }

  final stats = <ModuleModeStats>[];
  for (final entry in grouped.entries) {
    final (module, mode) = entry.key;
    final sessionsOldestFirst = entry.value;

    var totalTrials = 0;
    var independentAttempts = 0;
    var independentCorrect = 0;
    for (final session in sessionsOldestFirst) {
      final logs = await repository.getTrialLogs(session.sessionId);
      totalTrials += logs.length;
      for (final log in logs) {
        if (log.hintShown) continue;
        independentAttempts++;
        if (log.outcome == TrialOutcome.correct) independentCorrect++;
      }
    }

    final tierMilestones = <TierMilestone>[];
    SimilarityTier? lastTier;
    for (final session in sessionsOldestFirst) {
      final tier = session.ladderAtEnd.similarityTier;
      if (tier == lastTier) continue;
      tierMilestones.add(TierMilestone(tier: tier, reachedAt: session.endedAt));
      lastTier = tier;
    }

    stats.add(
      ModuleModeStats(
        module: module,
        mode: mode,
        totalTrials: totalTrials,
        independentAttempts: independentAttempts,
        independentCorrect: independentCorrect,
        currentPosition: sessionsOldestFirst.last.ladderAtEnd,
        tierMilestones: tierMilestones,
        sessions: sessionsOldestFirst.reversed.toList(),
      ),
    );
  }

  stats.sort((a, b) {
    final moduleOrder = ModuleId.values.indexOf(a.module).compareTo(ModuleId.values.indexOf(b.module));
    if (moduleOrder != 0) return moduleOrder;
    return ResponseMode.values.indexOf(a.mode).compareTo(ResponseMode.values.indexOf(b.mode));
  });
  return stats;
}
