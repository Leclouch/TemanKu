/// Per-child guardian settings — the speak-mode assistance consent toggle and
/// the sound controls. Kept on its own screen rather than folded into
/// `guardian_home_placeholder.dart` because turning the first one on is a
/// distinct consent event (§10 boundary, see below), not a casual preference.
///
/// Source-of-truth §6/§10: the app is on-device-only by default for
/// photos/session data. Speak-mode assistance is the **one deliberate
/// exception**, and it now covers two distinct exchanges with the same
/// external host (`speech/articulation_backend.dart`) — which is why the
/// consent copy names both rather than only the one that existed first:
///
///   - **the spoken example** (`GET /tts`) — the app sends the *word*, a
///     string the guardian typed themselves, and receives audio to play.
///     No microphone data is involved in this direction at all.
///   - **pronunciation scoring** (`POST /score`) — a short recording of the
///     **child's own voice** is uploaded. This is the consequential one, and
///     the copy leads with it for that reason.
///
/// Both ride the same `Child.pronunciationHintEnabled` flag deliberately: one
/// host, one consent. Splitting them into two toggles would let a guardian
/// agree to "just the examples" while the app still held a live path to the
/// same server, which is a distinction the consent copy could not honestly
/// explain.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/design/design.dart';
import 'package:temanku/data/models/child.dart';

const _consentTitle = 'Aktifkan bantuan mode bicara?';

/// Explicit, separate from the app's normal on-device-only handling, and
/// specific to this one feature. Names **both** exchanges — see the library
/// doc comment for why they share one toggle, and why the recording is
/// stated first.
const _consentBody =
    'Kalau diaktifkan, dua hal terhubung ke server luar pada mode bicara:\n\n'
    '1. Rekaman suara anak dikirim untuk dinilai kemiripan pengucapannya. '
    'Hasilnya hanya jadi saran — wali tetap yang menentukan benar atau salah.\n\n'
    '2. Nama benda dikirim sebagai teks, lalu aplikasi menerima suara contoh '
    'untuk diperdengarkan ke anak. Mikrofon tidak dipakai untuk bagian ini.\n\n'
    'Ini berbeda dari, dan tidak mengubah, cara aplikasi menyimpan foto dan '
    'data lain — yang selalu tetap di perangkat.';

class ChildSettingsScreen extends ConsumerStatefulWidget {
  const ChildSettingsScreen({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<ChildSettingsScreen> createState() => _ChildSettingsScreenState();
}

class _ChildSettingsScreenState extends ConsumerState<ChildSettingsScreen> {
  Child? _child;
  bool _busy = false;

  // Mirrors `soundServiceProvider`'s own state (§ audio/sound_service.dart) —
  // read once here so the toggle/slider below start in sync with whatever
  // the shared singleton already holds, then kept in sync on every change.
  late bool _soundMuted;
  late double _soundVolume;

  @override
  void initState() {
    super.initState();
    final sound = ref.read(soundServiceProvider);
    _soundMuted = sound.isMuted;
    _soundVolume = sound.volume;
    _load();
  }

  Future<void> _load() async {
    final child = await ref.read(childRepositoryProvider).getChild(widget.childId);
    if (!mounted) return;
    setState(() => _child = child);
  }

  Future<void> _setEnabled(bool enabled) async {
    final child = _child;
    if (child == null) return;

    // Turning it on is the consent event — ask first, and a "batal" leaves
    // the toggle exactly where it was. Turning it off needs no confirmation;
    // withdrawing consent is never the thing this screen should slow down.
    if (enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(_consentTitle),
          content: const Text(_consentBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Aktifkan'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _busy = true);
    final updated = child.copyWith(pronunciationHintEnabled: enabled);
    await ref.read(childRepositoryProvider).updateChild(updated);
    if (!mounted) return;
    setState(() {
      _child = updated;
      _busy = false;
    });
  }

  // Neither of these needs a `_busy`/confirm gate the way pronunciation-hint
  // consent does (§10 boundary above) — sound is app-level, on-device only,
  // trivially reversible, and turning it off is exactly the "no confirmation
  // needed" case `_setEnabled`'s own withdrawing-consent path already models.
  void _setSoundMuted(bool enabled) {
    ref.read(soundServiceProvider).setMuted(!enabled);
    setState(() => _soundMuted = !enabled);
  }

  void _setSoundVolume(double value) {
    ref.read(soundServiceProvider).setVolume(value);
    setState(() => _soundVolume = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final child = _child;

    return TkScreen(
      title: 'Pengaturan anak',
      child: child == null
          ? const TkLoading(label: 'Memuat pengaturan…')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TkCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TkSwitchTile(
                        title: 'Bantuan mode bicara (eksperimental)',
                        value: child.pronunciationHintEnabled,
                        onChanged: _busy ? null : _setEnabled,
                      ),
                      const SizedBox(height: TkSpace.xs),
                      Text(
                        'Aplikasi mengucapkan nama benda dulu sebagai contoh, '
                        'lalu anak menirukan. Sistem menandai tombol ✅/❌ yang '
                        'ia sarankan — sebagai bahan pertimbangan saja. Wali '
                        'tetap satu-satunya yang menentukan benar atau salah; '
                        'saran sistem tidak pernah tersimpan sebagai hasil '
                        'sebelum wali menekannya.',
                        style: context.type.bodySm.copyWith(color: colors.text),
                      ),
                      if (child.pronunciationHintEnabled) ...[
                        const SizedBox(height: TkSpace.sm),
                        // The one place in the app where data leaves the
                        // device. It gets its own tinted panel rather than a
                        // muted line of small print: a privacy consequence
                        // the guardian has already agreed to must still stay
                        // legible afterwards, not fade into the card.
                        const _NoticePanel(
                          icon: Icons.cloud_upload_outlined,
                          text: 'Rekaman suara anak dan nama benda dikirim ke '
                              'server luar untuk fitur ini. Foto dan data lain '
                              'tetap hanya di perangkat.',
                        ),
                      ],
                    ],
                  ),
                ),
                TkCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TkSwitchTile(
                        title: 'Efek suara',
                        value: !_soundMuted,
                        onChanged: _setSoundMuted,
                      ),
                      const SizedBox(height: TkSpace.xs),
                      Text(
                        'Bunyi singkat dan ramah saat menjawab benar atau perlu coba '
                        'lagi — dua nada yang setara, tidak pernah suara alarm. Bisa '
                        'dimatikan kapan saja.',
                        style: context.type.bodySm.copyWith(color: colors.text),
                      ),
                      if (!_soundMuted) ...[
                        const SizedBox(height: TkSpace.xs),
                        Row(
                          children: [
                            Icon(Icons.volume_down, size: 18, color: colors.textMuted),
                            Expanded(
                              child: Slider(
                                value: _soundVolume,
                                onChanged: _setSoundVolume,
                              ),
                            ),
                            Icon(Icons.volume_up, size: 18, color: colors.textMuted),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// A tinted callout for a consequence the guardian needs to keep seeing.
///
/// Informational, never an alarm — [TemanKuColors.info] tints it and the words
/// carry the meaning, matching the badge rule on the guardian home.
class _NoticePanel extends StatelessWidget {
  const _NoticePanel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(TkSpace.sm),
      decoration: BoxDecoration(
        color: c.info.withValues(alpha: 0.10),
        borderRadius: TkRadius.sm,
        border: Border.all(
          color: c.info.withValues(alpha: 0.35),
          width: TkStroke.hairline,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.info),
          const SizedBox(width: TkSpace.xs),
          Expanded(
            child: Text(
              text,
              style: context.type.bodySm.copyWith(color: c.text),
            ),
          ),
        ],
      ),
    );
  }
}
