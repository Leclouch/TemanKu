/// Firestore document paths — **IT-2.**
///
/// Source-of-truth §11: `guardians/{gid}/children/{cid}/...`, with **aggregated
/// telemetry** in Firestore and **raw trial logs local-only** ("summary never
/// needed trial granularity").
///
/// These constants exist so `firestore.rules` and the client agree by
/// construction. If a path changes here, the rules file changes with it.
///
/// **[OPEN] (§11):** region is asia-southeast1 (Singapore) assumed — confirm at
/// provisioning whether asia-southeast2 (Jakarta) is available for Firestore.
///
/// **No Cloud Functions in MVP** (§11). If a task here starts to want a server,
/// that is a signal to re-read the decision, not to add one.
library;

abstract final class FirestorePaths {
  static String guardian(String gid) => 'guardians/$gid';

  static String children(String gid) => 'guardians/$gid/children';

  static String child(String gid, String cid) => 'guardians/$gid/children/$cid';

  /// Ladder positions. One doc per (module, mode) pair under the child.
  static String ladder(String gid, String cid) =>
      'guardians/$gid/children/$cid/ladder';

  /// Aggregated session summaries — the only session artefact that leaves the
  /// device. Never write [TrialLog] here.
  static String sessions(String gid, String cid) =>
      'guardians/$gid/children/$cid/sessions';

  /// Photo **metadata** only, and only once cloud backup is consent-gated and
  /// built (§10 — out of MVP scope). Image bytes never go here by default.
  static String photos(String gid, String cid) =>
      'guardians/$gid/children/$cid/photos';
}
