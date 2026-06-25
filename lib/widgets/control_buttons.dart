import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PowerButton extends StatefulWidget {
  final double height;
  final double width;
  final IconData icon;
  final Function onPressed;
  final String? labelOn;
  final String? labelOff;

  const PowerButton({
    super.key,
    this.icon = Icons.power_settings_new,
    this.width = 300,
    this.height = 100,
    required this.onPressed,
    this.labelOn,
    this.labelOff,
  });

  @override
  State<PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<PowerButton> {
  bool isOn = false;

  void _toggleState() {
    setState(() {
      isOn = !isOn;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() { isOn = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _toggleState();
        widget.onPressed();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 55.w,
        padding: EdgeInsets.symmetric(vertical: 1.2.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4.r),
          color: isOn ? const Color(0xFF3A2020) : const Color(0xFF1A1A1A),
          border: Border.all(
            color: isOn ? const Color(0xFFE53935) : const Color(0xFF444444),
            width: 0.5.w,
          ),
        ),
        child: Center(
          child: AnimatedScale(
            scale: isOn ? 0.88 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  color: isOn ? const Color(0xFFE53935) : const Color(0xFF9E9E9E),
                  size: 9.sp,
                ),
                if (widget.labelOn != null || widget.labelOff != null)
                  Padding(
                    padding: EdgeInsets.only(top: 0.5.h),
                    child: Text(
                      isOn
                          ? (widget.labelOn ?? '')
                          : (widget.labelOff ?? ''),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isOn
                            ? const Color(0xFFE53935)
                            : const Color(0xFF9E9E9E),
                        fontSize: 2.2.sp,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QRButton extends StatefulWidget {
  final VoidCallback onPressed;
  final LogicalKeyboardKey shortcutKey;

  const QRButton(
      {required this.onPressed, required this.shortcutKey, super.key});

  @override
  State<QRButton> createState() => _QRButtonState();
}

class _QRButtonState extends State<QRButton> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _focusNode.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == widget.shortcutKey) {
      widget.onPressed();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.qr_code_scanner, size: 10.sp),
      focusNode: _focusNode,
      onPressed: widget.onPressed,
    );
  }
}

class NormalButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final LogicalKeyboardKey assignedKey;
  final FocusNode? customFocusNode;

  const NormalButton({
    super.key,
    required this.text,
    required this.onPressed,
    required this.assignedKey,
    this.customFocusNode,
  });

  @override
  State<NormalButton> createState() => _NormalButtonState();
}

class _NormalButtonState extends State<NormalButton> {
  bool isOn = false;
  late FocusNode _focusNode;

  void _toggleState() {
    setState(() { isOn = !isOn; });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() { isOn = false; });
    });
  }

  @override
  void initState() {
    super.initState();
    _focusNode = widget.customFocusNode ?? FocusNode();
    _focusNode.requestFocus();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _focusNode.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == widget.assignedKey) {
      if (!isOn) {
        setState(() {
          _toggleState();
          widget.onPressed();
        });
      }
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: GestureDetector(
        onTap: () {
          _toggleState();
          widget.onPressed();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 55.h,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4.r),
            color: isOn ? const Color(0xFF1A2540) : const Color(0xFF1A1A1A),
            border: Border.all(
              color: isOn ? const Color(0xFF1565C0) : const Color(0xFF444444),
              width: 0.5.w,
            ),
          ),
          child: Center(
            child: AnimatedScale(
              scale: isOn ? 0.88 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                widget.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isOn ? const Color(0xFF42A5F5) : const Color(0xFF9E9E9E),
                  fontWeight: FontWeight.bold,
                  fontSize: 4.sp,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ControlButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final VoidCallback onReleased;
  final LogicalKeyboardKey assignedKey;
  final FocusNode? customFocusNode;

  const ControlButton({
    super.key,
    required this.child,
    required this.onPressed,
    required this.onReleased,
    required this.assignedKey,
    this.customFocusNode,
  });

  @override
  State<ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<ControlButton> {
  bool isPressed = false;
  late FocusNode _focusNode;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.customFocusNode ?? FocusNode();
    _focusNode.requestFocus();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == widget.assignedKey) {
      _handlePress();
      return true;
    } else if (event is KeyUpEvent && event.logicalKey == widget.assignedKey) {
      _handleRelease();
      return true;
    }
    return false;
  }

  void _handlePress() {
    if (!isPressed) {
      setState(() { isPressed = true; });
      widget.onPressed();
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {});
  }

  void _handleRelease() {
    if (_debounceTimer?.isActive ?? false) return;
    if (isPressed) {
      setState(() { isPressed = false; });
      widget.onReleased();
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {});
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: GestureDetector(
        onTapDown: (_) => _handlePress(),
        onTapUp: (_) => _handleRelease(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: isPressed
                ? const Color(0xFF3A3A3A)
                : const Color(0xFF242424),
            borderRadius: BorderRadius.circular(4.r),
            border: Border.all(
              color: isPressed
                  ? const Color(0xFF5E5E5E)
                  : const Color(0xFF333333),
              width: 0.5.w,
            ),
          ),
          child: Transform.scale(
            scale: isPressed ? 0.93 : 1.0,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
