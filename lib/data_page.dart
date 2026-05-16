import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;

class DataPage extends StatefulWidget {
  final String site;

  const DataPage({super.key, required this.site});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  List<String> pinData = ["-", "-","-","-","-","-","-","-"];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

 Future<void> _fetchData() async {
  if (widget.site.isNotEmpty) {
    try {
      var response = await http
          .get(Uri.parse('${widget.site}/qtr'));

      if (response.statusCode == 200) {
        setState(() {
          pinData = response.body.split("/");
         // print(pinData);
        });
      } 
    } catch (e) {
      setState(() {
        pinData = ["-", "-", "-", "-", "-", "-", "-", "-"];
      });
      print('Bir hata oluştu: $e');
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Veriler",
          style: TextStyle(
              color: const Color.fromARGB(255, 255, 255, 255),
              fontSize: 4.sp,
              fontWeight: FontWeight.w600),
        ),
      ),
      body: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                 Column(
                   children: [
                     SizedBox(height: 25.h,),
                     Text("QTR-8A", style: TextStyle(fontSize: 8.sp, color: Colors.blue),),
                   ],
                 ),
                 SizedBox(width: 10.w,),
                Column(
                  children: [
                    Text(
                      "PIN-1",
                      style: TextStyle(fontSize: 4.sp, color: Colors.lightBlue),
                    ),
                    SizedBox(height: 5.h),
                    Container(
                      width: 30.w,
                      height: 60.h,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(221, 25, 25, 25),
                        border: Border.all(width: 0.5.w, color: Colors.blueAccent),
                      ),
                      child: Center(
                        child: pinData.isNotEmpty && pinData.length > 0
                            ? Text(
                                pinData[0],
                                style: TextStyle(fontSize: 7.sp, color: Colors.white),
                              )
                            : Text(
                                'NC',
                                style: TextStyle(fontSize: 7.sp, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
                 Column(
                   children: [
                     Text("PIN-2", style: TextStyle(fontSize: 4.sp, color: Colors.lightBlue),),
                     SizedBox(height: 5.h,),
                     Container(
                      width: 30.w,
                      height: 60.h,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(221, 25, 25, 25),
                        border: Border.all(width: 0.5.w, color: Colors.blueAccent)
                      ),
                      child: Center(
                        child: pinData.isNotEmpty && pinData.length > 0
                            ? Text(
                                pinData[1],
                                style: TextStyle(fontSize: 7.sp, color: Colors.white),
                              )
                            : Text(
                                'NC',
                                style: TextStyle(fontSize: 7.sp, color: Colors.white),
                              ),
                      ),
                     ),
                   ],
                 ),
                 Column(
                   children: [
                     Text("PIN-3", style: TextStyle(fontSize: 4.sp, color: Colors.lightBlue),),
                     SizedBox(height: 5.h,),
                     Container(
                      width: 30.w,
                      height: 60.h,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(221, 25, 25, 25),
                        border: Border.all(width: 0.5.w, color: Colors.blueAccent)
                      ),
                      child: Center(
                        child: pinData.isNotEmpty && pinData.length > 0
                            ? Text(
                                pinData[2],
                                style: TextStyle(fontSize: 7.sp, color: Colors.white),
                              )
                            : Text(
                                'NC',
                                style: TextStyle(fontSize: 7.sp, color: Colors.white),
                              ),
                      ),
                     ),
                   ],
                 ),
                 Column(
                   children: [
                     Text("PIN-4", style: TextStyle(fontSize: 4.sp, color: Colors.lightBlue),),
                     SizedBox(height: 5.h,),
                     Container(
                      width: 30.w,
                      height: 60.h,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(221, 25, 25, 25),
                        border: Border.all(width: 0.5.w, color: Colors.blueAccent)
                      ),
                      child: Center(
                        child: pinData.isNotEmpty && pinData.length == 8
                            ? Text(
                                pinData[3],
                                style: TextStyle(fontSize: 7.sp, color: Colors.white),
                              )
                            : Text(
                                'NC',
                                style: TextStyle(fontSize: 7.sp, color: Colors.white),
                              ),
                      ),
                     ),
                   ],
                 ),
                 Column(
                   children: [
                     Text("PIN-5", style: TextStyle(fontSize: 4.sp, color: Colors.lightBlue),),
                     SizedBox(height: 5.h,),
                     Container(
                      width: 30.w,
                      height: 60.h,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(221, 25, 25, 25),
                        border: Border.all(width: 0.5.w, color: Colors.blueAccent)
                      ),
                      child: Center(
                        child: pinData.isNotEmpty && pinData.length == 8
                            ? Text(
                                pinData[4],
                                style: TextStyle(fontSize: 7.sp, color: Colors.white),
                              )
                            : Text(
                                'NC',
                                style: TextStyle(fontSize: 7.sp, color: Colors.white),
                              ),
                      ),
                     ),
                   ],
                 ),
                 Column(
                   children: [
                     Text("PIN-6", style: TextStyle(fontSize: 4.sp, color: Colors.lightBlue),),
                     SizedBox(height: 5.h,),
                     Container(
                      width: 30.w,
                      height: 60.h,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(221, 25, 25, 25),
                        border: Border.all(width: 0.5.w, color: Colors.blueAccent)
                      ),
                      child: Center(
                        child: pinData.isNotEmpty && pinData.length == 8
                            ? Text(
                                pinData[5],
                                style: TextStyle(fontSize: 7.sp, color: Colors.white),
                              )
                            : Text(
                                'NC',
                                style: TextStyle(fontSize: 7.sp, color: Colors.white),
                              ),
                      ),
                     ),
                   ],
                 ),
                 Column(
                   children: [
                     Text("PIN-7", style: TextStyle(fontSize: 4.sp, color: Colors.lightBlue),),
                     SizedBox(height: 5.h,),
                     Container(
                      width: 30.w,
                      height: 60.h,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(221, 25, 25, 25),
                        border: Border.all(width: 0.5.w, color: Colors.blueAccent)
                      ),
                      child: Center(
                        child: pinData.isNotEmpty && pinData.length == 8
                            ? Text(
                                pinData[6],
                                style: TextStyle(fontSize: 7.sp, color: Colors.white),
                              )
                            : Text(
                                'NC',
                                style: TextStyle(fontSize: 7.sp, color: Colors.white),
                              ),
                      ),
                     ),
                   ],
                 ),
                 Column(
                   children: [
                     Text("PIN-8", style: TextStyle(fontSize: 4.sp, color: Colors.lightBlue),),
                     SizedBox(height: 5.h,),
                     Container(
                      width: 30.w,
                      height: 60.h,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(221, 25, 25, 25),
                        border: Border.all(width: 0.5.w, color: Colors.blueAccent)
                      ),
                      child: Center(
                        child: pinData.isNotEmpty && pinData.length == 8
                            ? Text(
                                pinData[7],
                                style: TextStyle(fontSize: 7.sp, color: Colors.white),
                              )
                            : Text(
                                'NC',
                                style: TextStyle(fontSize: 7.sp, color: Colors.white),
                              ),
                      ),
                     ),
                   ],
                 ),
                ],
              ),
              SizedBox(height: 80.h,),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Sharp 1", style: TextStyle(fontSize: 6.sp, color: Colors.blue),),
                  SizedBox(width:5.w,),
                  Container(
                    width: 30.w,
                    height: 50.h,
                    decoration: BoxDecoration(
                        color: const Color.fromARGB(221, 25, 25, 25),
                        border: Border.all(width: 0.5.w, color: Colors.blueAccent)
                    ),
                    child: Center(
                        child: Text("078", style: TextStyle(fontSize: 6.sp, color: Colors.white),)
                      ),
                  ),
                  SizedBox(width: 30.w,),
                  Text("Sharp 2", style: TextStyle(fontSize: 6.sp, color: Colors.blue),),
                  SizedBox(width:5.w,),
                  Container(
                    width: 30.w,
                    height: 50.h,
                    decoration: BoxDecoration(
                        color: const Color.fromARGB(221, 25, 25, 25),
                        border: Border.all(width: 0.5.w, color: Colors.blueAccent)
                    ),
                    child: Center(
                        child: Text("312", style: TextStyle(fontSize: 6.sp, color: Colors.white),)
                      ),
                  ),
                  SizedBox(width: 30.w,),
                  Text("Sharp 3", style: TextStyle(fontSize: 6.sp, color: Colors.blue),),
                  SizedBox(width:5.w,),
                  Container(
                    width: 30.w,
                    height: 50.h,
                    decoration: BoxDecoration(
                        color: const Color.fromARGB(221, 25, 25, 25),
                        border: Border.all(width: 0.5.w, color: Colors.blueAccent)
                    ),
                    child: Center(
                        child: Text("113", style: TextStyle(fontSize: 6.sp, color: Colors.white),)
                      ),
                  ),
                ],
              ),
              SizedBox(height: 60.h,),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      SizedBox(height: 15.h,),
                      Text("Encoder", style: TextStyle(fontSize: 5.5.sp, color: Colors.blue),),
                    ],
                  ),
                  SizedBox(width:8.w,),
                  Column(
                    children: [
                      Text("A", style: TextStyle(fontSize: 5.sp, color: Colors.lightBlue),),
                      SizedBox(height: 5.h,),
                      Container(
                        width: 30.w,
                        height: 50.h,
                        decoration: BoxDecoration(
                            color: const Color.fromARGB(221, 25, 25, 25),
                            border: Border.all(width: 0.5.w, color: Colors.blueAccent)
                        ),
                        child: Center(
                          child: Text("751", style: TextStyle(fontSize: 6.sp, color: Colors.white),)
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 56.w,),
                  Column(
                    children: [
                      Text("B", style: TextStyle(fontSize: 5.sp, color: Colors.lightBlue),),
                      SizedBox(height: 5.h,),
                      Container(
                        width: 30.w,
                        height: 50.h,
                        decoration: BoxDecoration(
                            color: const Color.fromARGB(221, 25, 25, 25),
                            border: Border.all(width: 0.5.w, color: Colors.blueAccent)
                        ),
                        child: Center(
                          child: Text("752", style: TextStyle(fontSize: 6.sp, color: Colors.white),)
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 56.w,),
                  Column(
                    children: [
                      Text("Z", style: TextStyle(fontSize: 5.sp, color: Colors.lightBlue),),
                      SizedBox(height: 5.h,),
                      Container(
                        width: 30.w,
                        height: 50.h,
                        decoration: BoxDecoration(
                            color: const Color.fromARGB(221, 25, 25, 25),
                            border: Border.all(width: 0.5.w, color: Colors.blueAccent)
                        ),
                        child: Center(
                          child: Text("23", style: TextStyle(fontSize: 6.sp, color: Colors.white),)
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 2.w,)
                ]
              ),
              SizedBox(height: 80.h,),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 1.w,),
                  Text("NRF24L01", style: TextStyle(fontSize: 5.sp, color: Colors.blue),),
                  SizedBox(width:6.w,),
                  Container(
                    width: 30.w,
                    height: 50.h,
                    decoration: BoxDecoration(
                        color: const Color.fromARGB(221, 25, 25, 25),
                        border: Border.all(width: 0.5.w, color: Colors.blueAccent)
                    ),
                    child: Center(
                          child: Text("null", style: TextStyle(fontSize: 6.sp, color: Colors.white),)
                        ),
                  ),
                  SizedBox(width: 29.w,),
                  Text("Bluetooth", style: TextStyle(fontSize: 5.sp, color: Colors.blue),),
                  SizedBox(width:5.w,),
                  Container(
                    width: 30.w,
                    height: 50.h,
                    decoration: BoxDecoration(
                        color: const Color.fromARGB(221, 25, 25, 25),
                        border: Border.all(width: 0.5.w, color: Colors.blueAccent)
                    ),
                    child: Center(
                          child: Text("null", style: TextStyle(fontSize: 6.sp, color: Colors.white),)
                        ),
                  ),
                  SizedBox(width: 38.w,),
                  Text("Load", style: TextStyle(fontSize: 6.sp, color: Colors.blue),),
                  SizedBox(width:5.w,),
                  Container(
                    width: 30.w,
                    height: 50.h,
                    decoration: BoxDecoration(
                        color: const Color.fromARGB(221, 25, 25, 25),
                        border: Border.all(width: 0.5.w, color: Colors.blueAccent)
                    ),
                    child: Center(
                          child: Text("132", style: TextStyle(fontSize: 6.sp, color: Colors.white),)
                        ),
                  ),
                  SizedBox(width: 3.5.w,)
                ],
              ),
              SizedBox(height: 80.h,),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Nem ve Sıcaklık", style: TextStyle(fontSize: 4.5.sp, color: Colors.blue, ),),
                  SizedBox(width:6.w,),
                  Container(
                    width: 30.w,
                    height: 50.h,
                    decoration: BoxDecoration(
                        color: const Color.fromARGB(221, 25, 25, 25),
                        border: Border.all(width: 0.5.w, color: Colors.blueAccent)
                    ),
                    child: Center(
                          child: Text("435 - 482", style: TextStyle(fontSize: 5.5.sp, color: Colors.white),)
                        ),
                  ),
                  SizedBox(width: 37.w,),
                  Text("Akım", style: TextStyle(fontSize: 6.sp, color: Colors.blue),),
                  SizedBox(width:5.w,),
                  Container(
                    width: 30.w,
                    height: 50.h,
                    decoration: BoxDecoration(
                        color: const Color.fromARGB(221, 25, 25, 25),
                        border: Border.all(width: 0.5.w, color: Colors.blueAccent)
                    ),
                    child: Center(
                          child: Text("232", style: TextStyle(fontSize: 6.sp, color: Colors.white),)
                        ),
                  ),
                  SizedBox(width: 36.5.w,),
                  Text("Voltaj", style: TextStyle(fontSize: 6.sp, color: Colors.blue),),
                  SizedBox(width:5.w,),
                  Container(
                    width: 30.w,
                    height: 50.h,
                    decoration: BoxDecoration(
                        color: const Color.fromARGB(221, 25, 25, 25),
                        border: Border.all(width: 0.5.w, color: Colors.blueAccent)
                    ),
                    child: Center(
                          child: Text("247", style: TextStyle(fontSize: 6.sp, color: Colors.white),)
                        ),
                  ),
                  SizedBox(width: 11.w,)
                ]
              ),
            ],
          ),
          SizedBox(width: 10.w,)
        ],
      )
    );
  }
}