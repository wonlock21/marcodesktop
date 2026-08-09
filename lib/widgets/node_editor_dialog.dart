import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/gcs_node_model.dart';
import '../services/ros_mapping_contract.dart';

const _panelBg = Color(0xFF1A1A1A);
const _borderC = Color(0xFF333333);
const _muted = Color(0xFF9E9E9E);
const _bright = Color(0xFFE0E0E0);
const _accent = Color(0xFF42A5F5);
const _danger = Color(0xFFE53935);

/// F/G ortak: ad + tür dialog sonucu.
class NodeEditorDraft {
  final String name;
  final FieldNodeType type;

  const NodeEditorDraft({required this.name, required this.type});
}

/// F.1 / G.1 — ortak düğüm ad/tür dialog’u.
class NodeEditorDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  final FieldNodeType? initialType;
  final String? Function(String?) validateName;

  const NodeEditorDialog({
    super.key,
    required this.title,
    required this.validateName,
    this.initialName,
    this.initialType,
  });

  static Future<NodeEditorDraft?> show(
    BuildContext context, {
    required String title,
    required String? Function(String?) validateName,
    String? initialName,
    FieldNodeType? initialType,
  }) {
    return showDialog<NodeEditorDraft>(
      context: context,
      builder: (_) => NodeEditorDialog(
        title: title,
        validateName: validateName,
        initialName: initialName,
        initialType: initialType,
      ),
    );
  }

  @override
  State<NodeEditorDialog> createState() => _NodeEditorDialogState();
}

class _NodeEditorDialogState extends State<NodeEditorDialog> {
  late final TextEditingController _controller;
  late FieldNodeType _type;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
    _type = widget.initialType ?? FieldNodeType.alma;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final err = widget.validateName(_controller.text);
    setState(() => _error = err);
    if (err != null) return;
    Navigator.of(context).pop(
      NodeEditorDraft(name: _controller.text.trim(), type: _type),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _panelBg,
      title: Text(
        widget.title,
        style: TextStyle(color: _bright, fontSize: 4.5.sp),
      ),
      content: SizedBox(
        width: 70.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ad', style: TextStyle(color: _muted, fontSize: 3.sp)),
            SizedBox(height: 0.4.h),
            TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: _bright, fontSize: 3.5.sp),
              decoration: InputDecoration(
                hintText: 'örn. A1, B3, S1, BASLANGIC',
                hintStyle: TextStyle(color: _muted, fontSize: 3.sp),
                errorText: _error,
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: _borderC),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: _accent),
                ),
                errorBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: _danger),
                ),
                focusedErrorBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: _danger),
                ),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
            ),
            SizedBox(height: 1.2.h),
            Text('Tür', style: TextStyle(color: _muted, fontSize: 3.sp)),
            SizedBox(height: 0.5.h),
            Wrap(
              spacing: 1.5.w,
              runSpacing: 0.6.h,
              children: FieldNodeType.values.map((t) {
                final selected = _type == t;
                return ChoiceChip(
                  label: Text(
                    t.etiket,
                    style: TextStyle(
                      color: selected ? Colors.white : _bright,
                      fontSize: 2.8.sp,
                    ),
                  ),
                  selected: selected,
                  selectedColor: t.markerColor,
                  backgroundColor: const Color(0xFF2A2A2A),
                  onSelected: (_) => setState(() => _type = t),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('İptal', style: TextStyle(color: _muted, fontSize: 3.sp)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            'Kaydet',
            style: TextStyle(color: _accent, fontSize: 3.sp),
          ),
        ),
      ],
    );
  }
}
