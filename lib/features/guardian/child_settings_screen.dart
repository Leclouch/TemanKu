/// Per-child guardian settings — currently just the pronunciation-hint
/// consent toggle, kept on its own screen rather than folded into
/// `guardian_home_placeholder.dart` because turning this on is a distinct
/// consent event (§10 boundary, see below), not a casual preference.
///
/// Source-of-truth §6/§10: the app is on-device-only by default for
/// photos/session data. The pronunciation hint is the **one deliberate
/// exception** — audio leaves the device, to an external scoring service —
/// and that must never be quietly implied by turning speak mode on. This
/// screen is where that line gets crossed, explicitly, per child, with
/// copy that says so before the toggle can go true.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:temanku/core/service_locator.dart';
import 'package:temanku/core/theme/temanku_theme.dart';
import 'package:temanku/data/models/child.dart';

const _consentTitle = 'Kirim rekaman suara untuk saran pengucapan?';

/// Exact copy the task brief requires: explicit, separate from the app's
/// normal on-device-only handling, specific to this one feature.
const _consentBody =
    'Kalau diaktifkan, rekaman suara anak pada mode bicara akan dikirim ke '
    'server luar untuk fitur saran pengucapan ini saja. Ini berbeda dari, '
    'dan tidak mengubah, cara aplikasi menyimpan foto dan data lain — yang '
    'selalu tetap di perangkat.';

class ChildSettingsScreen extends ConsumerStatefulWidget {
  const ChildSettingsScreen({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<ChildSettingsScreen> createState() => _ChildSettingsScreenState();
}

class _ChildSettingsScreenState extends ConsumerState<ChildSettingsScreen> {
  Child? _child;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final child = _child;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan anak')),
      body: SafeArea(
        child: child == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: colors.background,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: colors.neutralFeedback),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Saran pengucapan (eksperimental)',
                              style: context.type.display.copyWith(color: colors.text, fontSize: 18),
                            ),
                            value: child.pronunciationHintEnabled,
                            onChanged: _busy ? null : _setEnabled,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Saat aktif, sistem menampilkan tebakan kata di sebelah '
                            'tombol ✅/❌ sebagai bahan pertimbangan saja. Wali tetap '
                            'satu-satunya yang menentukan benar atau salah — tebakan '
                            'sistem tidak pernah dipilih otomatis dan tidak pernah '
                            'disimpan sebagai hasil.',
                            style: context.type.body.copyWith(color: colors.text),
                          ),
                          if (child.pronunciationHintEnabled) ...[
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline, size: 18, color: colors.neutralFeedback),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Rekaman suara dikirim ke server luar untuk fitur ini. '
                                    'Foto dan data lain tetap hanya di perangkat.',
                                    style: context.type.body.copyWith(color: colors.neutralFeedback),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
