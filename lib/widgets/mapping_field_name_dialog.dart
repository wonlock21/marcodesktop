import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<String?> showMappingFieldNameDialog({
  required BuildContext context,
  required String initialValue,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _MappingFieldNameDialog(initialValue: initialValue),
    );

class _MappingFieldNameDialog extends StatefulWidget {
  const _MappingFieldNameDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_MappingFieldNameDialog> createState() =>
      _MappingFieldNameDialogState();
}

class _MappingFieldNameDialogState extends State<_MappingFieldNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close([String? value]) {
    Navigator.of(context).pop(value?.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Saha adı',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'monospace',
          ),
        ),
        content: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontFamily: 'monospace',
          ),
          cursorColor: const Color(0xFF4A90D9),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
          ],
          decoration: const InputDecoration(
            hintText: 'saha_01',
            hintStyle: TextStyle(color: Color(0xFF555555)),
            helperText: 'Yalnız harf, rakam, _ ve -',
            helperStyle: TextStyle(color: Color(0xFF666666), fontSize: 12),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF333333)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF4A90D9)),
            ),
          ),
          onSubmitted: (value) => _close(value),
        ),
        actions: [
          TextButton(
            onPressed: _close,
            child: const Text(
              'İptal',
              style: TextStyle(color: Color(0xFF888888), fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: () => _close(_controller.text),
            child: const Text(
              'Başlat',
              style: TextStyle(color: Color(0xFF4A90D9), fontSize: 14),
            ),
          ),
        ],
      );
}
