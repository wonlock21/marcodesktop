import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'data_model.dart';

class QRPage extends StatefulWidget {
  const QRPage({super.key});

  @override
  State<QRPage> createState(){
    return _QRPageState();
  }
}

class _QRPageState extends State<QRPage>{
    
  void _showRenameDialog(BuildContext context, DataPoint qrPoint) {
    final TextEditingController _controller = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey,
          surfaceTintColor: Colors.white,
          title: Text('QR Kodu Yeniden Adlandır', style: TextStyle(fontSize: 6.sp)),
          content: TextField(
            controller: _controller,
            decoration: InputDecoration(hintText: "Yeni QR adı girin" , hintStyle: TextStyle(fontSize: 3.sp) ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('İptal', style: TextStyle(fontSize: 3.sp),),
            ),
            TextButton(
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  setState(() {
                    qrPoint.type = _controller.text;
                  });
                }
                Navigator.of(context).pop();
              },
              child: Text('Kaydet', style: TextStyle(fontSize: 3.sp)),
            ),
          ],
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    var dataPoints = Provider.of<DataModel>(context).dataPoints;
    List<DataPoint> qrPoints= List.empty(growable: true);
    List invisibleQRfor = List.empty(growable: true);

    for(int i = 0; i<dataPoints.length; i++){
      if(dataPoints[i].type.contains("Q")){
        qrPoints.add(dataPoints[i]);
      }  
    };
    
    for(int i = 0; i < qrPoints.length; i++){
      for(int k = 0; k < dataPoints.length; k++){
        if (qrPoints[i].x == dataPoints[k].x && qrPoints[i].y == dataPoints[k].y && !dataPoints[k].type.contains("Q")){
          invisibleQRfor.add(dataPoints[k]);
        } 
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "QR KOD LİSTESİ",
          style: TextStyle(
              color: const Color.fromARGB(255, 255, 255, 255),
              fontSize: 4.sp,
              fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(
        child: Container(
          width: 200.w,
          height: 600.h,
          padding: EdgeInsets.symmetric(vertical: 20.h),
          child: SingleChildScrollView(
            child: DataTable(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue,),
                borderRadius: BorderRadius.circular(10.r),
                color: const Color.fromARGB(255, 57, 57, 57)
              ),
              columns: <DataColumn>[
                DataColumn(
                  label: Text(
                    'Etiket',
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 5.sp),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'X KONUMU',
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 4.sp),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Y KONUMU',
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 4.sp),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Ek Bilgi',
                    style:
                        TextStyle(fontStyle: FontStyle.italic, fontSize: 4.sp),
                  ),
                ),

                DataColumn(
                  label: Text(
                    'İşlem',
                    style:
                        TextStyle(fontStyle: FontStyle.italic, fontSize: 4.sp),
                  ),
                ),
              ],
              rows: List.generate(
                qrPoints.length,
                (index) {
                  // QR noktası için mevcut veri
                  var qrPoint = qrPoints[index];
                  
                  // QR noktasının aynı x ve y koordinatlarına sahip invisibleQRfor listesinde bir veri olup olmadığını kontrol et
                  String additionalData = '';
                  for (var invisibleQR in invisibleQRfor) {
                    if (qrPoint.x == invisibleQR.x && qrPoint.y == invisibleQR.y) {
                      additionalData = invisibleQR.type; // invisibleQRfor'daki verinin type'ını al
                      break; // Bir eşleşme bulunduktan sonra döngüyü sonlandır
                    }
                  }
                  
                  return DataRow(
                    color: const WidgetStatePropertyAll(Color.fromARGB(255, 112, 112, 112)),
                    cells: <DataCell>[
                      DataCell(Text(qrPoint.type, style: TextStyle(fontSize: 4.sp))),
                      DataCell(Text(qrPoint.x.toString(), style: TextStyle(fontSize: 4.sp))),
                      DataCell(Text(qrPoint.y.toString(), style: TextStyle(fontSize: 4.sp))),
                      DataCell(Text(additionalData, style: TextStyle(fontSize: 4.sp))), // additionalData'yı ekle
                      DataCell(
                        TextButton(
                          onPressed: () {
                            _showRenameDialog(context, qrPoint);
                          },
                          child: Text(
                            'QR Tanımla',
                            style: TextStyle(fontSize: 3.5.sp, color: Colors.black54),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

            ),
          ),
        ),
      ),
    );
  }
}