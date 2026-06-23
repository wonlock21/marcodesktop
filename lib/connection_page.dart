import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
      appBar: AppBar(
        title: Text(
          "BAĞLANTI",
          style: TextStyle(
              color: const Color.fromARGB(255, 255, 255, 255),
              fontSize: 4.sp,
              fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 90.w, vertical: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                cursorColor: Colors.white54,
                style: TextStyle(color: Colors.white, fontSize: 4.sp),
                decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.black26,
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue, width: 0.6.w)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: const Color.fromARGB(255, 0, 140, 255),
                            width: 0.9.w)),
                    hintText: 'IP Adresi Girin',
                    hintStyle: TextStyle(color: Colors.white, fontSize: 3.sp)),
                onChanged: (value) {
                  setState(() {
                    _ipAddress = value;
                  });
                },
              ),
              SizedBox(height: 50.h),
              ConnectButton(
                text: "Bağlan",
                onPressed:() {
                  Navigator.pop(context, _ipAddress);
                },
              )
            ],
          ),
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
        duration: const Duration(milliseconds: 300),
        height: 60.h,
        width: 33.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          color: Colors.grey[850],
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
            width: 75.w,
            height: 65.h,
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 6.w),
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15.r),
              border: Border.all(
                color: isOn ? Colors.grey : Colors.blue,
                width: 0.7.w,
              ),
            ),
            child: AnimatedScale(
              scale: isOn ? 0.85 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Row(
                children: [
                  Icon(Icons.link, color: isOn? Colors.grey : Colors.blue, size: 6.sp,),
                  SizedBox(width: 1.w,),
                  Text(widget.text,
                      style: TextStyle(
                        color: isOn ? Colors.grey : Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 3.sp,
                      )
                   ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}