/// Deterministic recap-sentence generator for the guardian's Riwayat list.
///
/// §8: "descriptive sentences, notebook not dashboard" — one plain Bahasa
/// sentence per [SessionSummary], built from fixed string templates. Template-
/// based on purpose, not a placeholder for something smarter later: no AI/LLM
/// call, so the sentence is instant and predictable for a live demo. No
/// percentages, no accuracy stats, no numeric performance language anywhere
/// in this file — the same hard rule [SessionSummary]'s own doc comment states.
library;

import 'package:temanku/content/keluarga/keluarga_module.dart';
import 'package:temanku/content/makanan/makanan_module.dart';
import 'package:temanku/content/module_definition.dart';
import 'package:temanku/core/constants/domain_enums.dart';
import 'package:temanku/data/models/session.dart';

ModuleDefinition _definitionFor(ModuleId module) => switch (module) {
      ModuleId.makanan => makananModule,
      ModuleId.keluarga => keluargaModule,
    };

/// Bahasa label for the response mode — names the motor channel only, never
/// the child-facing "level" word (§4.1: mode and skill domain are separate axes).
String _modeLabel(ResponseMode mode) => switch (mode) {
      ResponseMode.tap => 'ketuk',
      ResponseMode.match => 'cocokkan',
      ResponseMode.speak => 'ucap',
    };

/// "Sedang berlatih dengan {module's own similarity-tier copy}." — used only
/// when a session has no recorded [SessionSummary.observations], so the
/// sentence still says something dial-specific rather than going blank.
String _fallbackDialNote(SessionSummary summary) {
  final tierCopy = _definitionFor(summary.module)
      .similarityTierCopy[summary.ladderAtEnd.similarityTier];
  if (tierCopy == null) return 'Belum ada catatan tambahan untuk sesi ini.';
  return 'Sedang berlatih dengan $tierCopy.';
}

/// One sentence: "Sesi berlangsung {duration} menit, mode {mode}. {dial-specific
/// observation}." The closing sentence prefers [SessionSummary.observations]
/// (already dial-descriptive Bahasa sentences — see that field's doc comment)
/// and falls back to the module's [ModuleDefinition.similarityTierCopy] for
/// [SessionSummary.ladderAtEnd] when a session has none.
String buildSessionRecap(SessionSummary summary) {
  final minutes = summary.duration.inMinutes;
  final mode = _modeLabel(summary.mode);
  final dialNote = summary.observations.isNotEmpty
      ? summary.observations.join(' ')
      : _fallbackDialNote(summary);
  return 'Sesi berlangsung $minutes menit, mode $mode. $dialNote';
}
