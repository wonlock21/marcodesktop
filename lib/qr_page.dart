import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'data_model.dart';

// ─── Renk sabitleri ────────────────────────────────────────────────────────
const _bg      = Color(0xFF121212);
const _panelBg = Color(0xFF1A1A1A);
const _borderC = Color(0xFF333333);
const _muted   = Color(0xFF9E9E9E);
const _bright  = Color(0xFFE0E0E0);

class QRPage extends StatefulWidget {
  const QRPage({super.key});

  @override
  State<QRPage> createState() {
    return _QRPageState();
  }
}

class _QRPageState extends State<QRPage> {

  /// QR etiket adından (QA2.1, QB3.1, CS1.1 vb.) tip döner.
  String _qrTipEtiket(String label) {
    final upper = label.toUpperCase();
    if (upper.startsWith('QA'))  return 'Alma';
    if (upper.startsWith('QB'))  return 'Bırakma';
    if (upper.startsWith('CS'))  return 'Şarj';
    if (upper.startsWith('S'))   return 'Başlangıç';
    if (upper.startsWith('D') || upper.contains('KAPI')) return 'Kapı';
    if (upper.startsWith('W') || upper.contains('BEKL')) return 'Bekleme';
    return '--';
  }

  void _showRenameDialog(BuildContext context, DataPoint qrPoint) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _panelBg,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4.r),
            side: BorderSide(color: _borderC, width: 0.5.w),
          ),
          title: Text(
            'QR KOD YENİDEN ADLANDIR',
            style: TextStyle(
              color: _bright,
              fontSize: 5.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          content: TextField(
            controller: controller,
            cursorColor: _bright,
            style: TextStyle(
              color: _bright,
              fontSize: 4.sp,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: "Yeni QR adı girin",
              hintStyle: TextStyle(color: const Color(0xFF444444), fontSize: 3.sp),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              contentPadding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.5.h),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: _borderC, width: 0.5.w),
                borderRadius: BorderRadius.circular(4.r),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: const Color(0xFF1565C0), width: 0.7.w),
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
          ),
          actions: <Widget>[
            _dialogBtn(
              label: 'İPTAL',
              onPressed: () => Navigator.of(context).pop(),
            ),
            _dialogBtn(
              label: 'KAYDET',
              primary: true,
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    qrPoint.type = controller.text;
                  });
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _dialogBtn({
    required String label,
    required VoidCallback onPressed,
    bool primary = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: primary ? const Color(0xFF1A2540) : _panelBg,
          border: Border.all(
            color: primary ? const Color(0xFF1565C0) : _borderC,
            width: 0.5.w,
          ),
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: primary ? const Color(0xFF42A5F5) : _muted,
            fontSize: 3.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var dataPoints = Provider.of<DataModel>(context).dataPoints;
    List<DataPoint> qrPoints = List.empty(growable: true);
    List invisibleQRfor = List.empty(growable: true);

    for (int i = 0; i < dataPoints.length; i++) {
      if (dataPoints[i].type.contains("Q")) {
        qrPoints.add(dataPoints[i]);
      }
    }

    for (int i = 0; i < qrPoints.length; i++) {
      for (int k = 0; k < dataPoints.length; k++) {
        if (qrPoints[i].x == dataPoints[k].x &&
            qrPoints[i].y == dataPoints[k].y &&
            !dataPoints[k].type.contains("Q")) {
          invisibleQRfor.add(dataPoints[k]);
        }
      }
    }

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
          "QR KOD LİSTESİ",
          style: TextStyle(
            color: Colors.white,
            fontSize: 4.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 4.w),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              headingTextStyle: TextStyle(
                color: _muted,
                fontSize: 4.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              dataTextStyle: TextStyle(
                color: _bright,
                fontSize: 3.5.sp,
                fontFamily: 'monospace',
              ),
              headingRowColor: const WidgetStatePropertyAll(_panelBg),
              dataRowColor: const WidgetStatePropertyAll(Color(0xFF161616)),
              decoration: BoxDecoration(
                border: Border.all(color: _borderC, width: 0.5.w),
                borderRadius: BorderRadius.circular(4.r),
                color: const Color(0xFF161616),
              ),
              dividerThickness: 0.3,
              columns: const <DataColumn>[
                DataColumn(label: Text('ETİKET')),
                DataColumn(label: Text('TİP')),
                DataColumn(label: Text('X KONUM')),
                DataColumn(label: Text('Y KONUM')),
                DataColumn(label: Text('EK BİLGİ')),
                DataColumn(label: Text('DOĞRULAMA')),
                DataColumn(label: Text('SON OKUNMA')),
                DataColumn(label: Text('İŞLEM')),
              ],
              rows: List.generate(
                qrPoints.length,
                (index) {
                  final qrPoint = qrPoints[index];

                  String additionalData = '';
                  for (var invisibleQR in invisibleQRfor) {
                    if (qrPoint.x == invisibleQR.x &&
                        qrPoint.y == invisibleQR.y) {
                      additionalData = invisibleQR.type;
                      break;
                    }
                  }

                  // QR tipi etiket adından türetilir
                  final tip = _qrTipEtiket(qrPoint.type);

                  return DataRow(
                    cells: <DataCell>[
                      DataCell(Text(qrPoint.type)),
                      DataCell(Text(tip)),
                      DataCell(Text(qrPoint.x.toString())),
                      DataCell(Text(qrPoint.y.toString())),
                      DataCell(Text(
                        additionalData.isEmpty ? '--' : additionalData,
                      )),
                      const DataCell(Text('--')),
                      const DataCell(Text('--')),
                      DataCell(
                        GestureDetector(
                          onTap: () => _showRenameDialog(context, qrPoint),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 2.w, vertical: 0.8.h,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: _borderC, width: 0.5.w),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              'TANIMLA',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 3.sp,
                                fontFamily: 'monospace',
                              ),
                            ),
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
