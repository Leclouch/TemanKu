/// Local persistence — **IT-2.** Hive.
///
/// Source-of-truth §11: local encrypted storage is the **default** for photos;
/// raw trial logs are **local-only**; the ladder cache lives here too so a
/// session survives being offline (offline-first is an architecture constraint,
/// not a nice-to-have).
///
/// TODO(IT-2) Day 1: open these boxes in `main()` after `Hive.initFlutter()`, and
/// use `HiveAesCipher` with a key from platform secure storage for anything
/// holding photo paths or child data — "encrypted" in §11 is literal.
library;

/// Box names in one place so nothing string-literals a box open.
abstract final class Boxes {
  /// Child profiles + intake results.
  static const children = 'children';

  /// Ladder positions, keyed `childId::module::mode`.
  static const ladder = 'ladder';

  /// Photo records. Bytes live on the filesystem; this holds the metadata.
  static const photos = 'photos';

  /// Raw trial logs. **Never synced** — §11.
  static const trialLogs = 'trial_logs';

  /// Session summaries, cached locally so history reads work offline.
  static const sessionSummaries = 'session_summaries';
}

/// Composite key for the per-child, per-module, per-mode ladder (§4.2).
/// All three axes are in the key because collapsing any of them would break
/// "no cross-module gating, ever."
String ladderKey(String childId, String module, String mode) =>
    '$childId::$module::$mode';
