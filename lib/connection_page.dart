import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ─── Renk sabitleri ────────────────────────────────────────────────────────
const _bg      = Color(0xFF121212);
const _panelBg = Color(0xFF1A1A1A);
const _borderC = Color(0xFF333333);
const _muted   = Color(0xFF9E9E9E);
const _bright  = Color(0xFFE0E0E0);

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() {
    return _ConnectionPageState();
  }
}

class _ConnectionPageState extends State<ConnectionPage> {
  final TextEditingController _controller = TextEditingController();
  String _ipAddress = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _panelBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(0.3.h),
          child: Divider(height: 0.3.h, color: _borderC),
        ),
        title: Text(
          "BAĞLANTI",
          style: TextStyle(
            color: Colors.white,
            fontSize: 4.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 8.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 6.h),
            // IP giriş alanı
            Text(
              "SUNUCU ADRESİ",
              style: TextStyle(
                color: _muted,
                fontSize: 3.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 1.5.h),
            TextField(
              controller: _controller,
              cursorColor: _bright,
              style: TextStyle(
                color: _bright,
                fontSize: 4.sp,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                hintText: 'http://192.168.x.x:5000',
                hintStyle: TextStyle(
                  color: const Color(0xFF444444),
                  fontSize: 3.5.sp,
                  fontFamily: 'monospace',
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 3.w, vertical: 2.h,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _borderC, width: 0.5.w),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: const Color(0xFF1565C0), width: 0.7.w,
                  ),
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _ipAddress = value;
                });
              },
            ),
            SizedBox(height: 6.h),
            // Bağlan butonu
            ConnectButton(
              text: "Bağlan",
              onPressed: () {
                Navigator.pop(context, _ipAddress);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ConnectButton extends StatefulWidget {
  const ConnectButton({super.key, this.text = "", required this.onPressed});

  final VoidCallback onPressed;
  final String text;
  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton> {
  bool isOn = false;

  void _toggleState() {
    setState(() {
      isOn = !isOn;
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
        height: 55.h,
        decoration: BoxDecoration(
          color: isOn
              ? const Color(0xFF1A2540)
              : const Color(0xFF1E1E1E),
          border: Border.all(
            color: isOn
                ? const Color(0xFF1565C0)
                : _borderC,
            width: 0.5.w,
          ),
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.link,
                color: isOn
                    ? const Color(0xFF42A5F5)
                    : _muted,
                size: 5.sp,
              ),
              SizedBox(width: 1.5.w),
              Text(
                widget.text.toUpperCase(),
                style: TextStyle(
                  color: isOn
                      ? const Color(0xFF42A5F5)
                      : _muted,
                  fontWeight: FontWeight.bold,
                  fontSize: 4.sp,
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
