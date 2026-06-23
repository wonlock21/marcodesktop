import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PowerButton extends StatefulWidget {
  final double height;
  final double width;
  final IconData icon;
  final Function onPressed;

  const PowerButton({
    super.key,
    this.icon = Icons.power_settings_new,
    this.width = 300,
    this.height = 100,
    required this.onPressed,
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
        duration: const Duration(milliseconds: 300),
        height: 150.h,
        width: 80.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          color: Colors.grey[800],
          boxShadow: [
            BoxShadow(
              color: isOn ? Colors.transparent : Colors.black54,
              blurRadius: isOn ? 0 : 10,
              spreadRadius: isOn ? 0 : 4,
              offset: isOn ? const Offset(0, 0) : const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: AnimatedContainer(
            padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 25.w),
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: (isOn ? Colors.red : Colors.grey[700])!,
                width: 1.w,
              ),
            ),
            child: AnimatedScale(
              scale: isOn ? 0.85 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                widget.icon,
                color: isOn ? Colors.red : Colors.grey[600],
                size: 20.sp,
              ),
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
          duration: const Duration(milliseconds: 300),
          height: 80.h,
          width: 50.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            color: Colors.grey[800],
            boxShadow: [
              BoxShadow(
                color: isOn ? Colors.transparent : Colors.black54,
                blurRadius: isOn ? 0 : 10,
                spreadRadius: isOn ? 0 : 2,
                offset: isOn ? const Offset(0, 0) : const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: AnimatedContainer(
              alignment: Alignment.center,
              width: 45.w,
              height: 65.h,
              padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 6.w),
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: (isOn ? Colors.blue : Colors.grey[700])!,
                  width: 1.w,
                ),
              ),
              child: AnimatedScale(
                scale: isOn ? 0.85 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isOn ? Colors.blue : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 5.sp,
                  ),
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
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: isPressed
                ? const Color.fromARGB(255, 173, 173, 173)
                : const Color.fromARGB(255, 121, 121, 121),
            borderRadius: BorderRadius.circular(25.r),
            boxShadow: isPressed
                ? null
                : [
                    BoxShadow(
                      color: const Color.fromARGB(255, 163, 163, 163),
                      offset: const Offset(0, 5),
                      blurRadius: 15.r,
                    ),
                    BoxShadow(
                      color: const Color.fromARGB(255, 76, 76, 76),
                      offset: const Offset(0, -2),
                      blurRadius: 10.r,
                    ),
                  ],
            gradient: const LinearGradient(
              colors: [
                Color.fromARGB(255, 107, 107, 107),
                Color.fromARGB(255, 162, 162, 162),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Transform.scale(
            scale: isPressed ? 0.96 : 1,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
