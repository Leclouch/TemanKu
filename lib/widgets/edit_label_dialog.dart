import 'package:flutter/material.dart';

/// §5.5 standing-correction dialog — **shared component, jointly owned.**
/// One name-entry dialog, reused everywhere a guardian corrects or supplies
/// a photo's label: the upload flow's saved-nudge ("ketuk untuk ubah") and
/// the photo library's rename action both push this and act on whatever
/// [String] it returns (null/empty means cancelled).
///
/// A dedicated [StatefulWidget] rather than a bare [TextEditingController]
/// built inline by the caller — that shape disposes the controller the
/// instant `showDialog` resolves (on `Navigator.pop`), which fires *before*
/// the dialog's exit transition finishes, so the still-animating [TextField]
/// ends up using a disposed controller. Owning the controller here ties its
/// disposal to this widget's own element lifecycle, which Flutter only tears
/// down once the route is actually gone.
class EditLabelDialog extends StatefulWidget {
  const EditLabelDialog({super.key, required this.initialLabel});

  final String initialLabel;

  @override
  State<EditLabelDialog> createState() => _EditLabelDialogState();
}

class _EditLabelDialogState extends State<EditLabelDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialLabel);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nama benda ini'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'mis. pisang'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
