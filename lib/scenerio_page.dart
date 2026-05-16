import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'data_model.dart';

class ScenarioPage extends StatefulWidget {
  final List<DataPoint> dataPoints; // kullanılmıyor
  final String site;                // SUNUCU adresi burada
  final String rota;                // kullanılmıyor

  const ScenarioPage({
    super.key,
    required this.dataPoints,
    required this.site,
    required this.rota,
  });

  @override
  State<ScenarioPage> createState() => _ScenarioPageState();
}

class _ScenarioPageState extends State<ScenarioPage> {
  final List<String> _allPlaces = const [
    'A1','A2','A3','A4',
    'B1','B2','B3','B4',
    'S1','S2',
    'CS', // <-- Şarj istasyonu
  ];

  final List<String> _selected = [];
  String Arota = "";
  bool senaryoIsDone = false;
  String _data = '';

  // QR eşleme
  final Map<String, String> _qrMap = const {
    'A1':'QA1.1','A2':'QA2.1','A3':'QA3.1','A4':'QA4.1',
    'B1':'QB1.1','B2':'QB2.1','B3':'QB3.1','B4':'QB4.1',
    'S1':'S1.1','S2':'S2.1',
    'CS':'CS1.1', // <-- Şarj istasyonu
  };

  @override
  void initState() {
    super.initState();
    senaryoIsDone = widget.rota.isNotEmpty;
  }

  void _addPlace(String code) => setState(() => _selected.add(code));

  void _undo() {
    if (_selected.isEmpty) return;
    setState(() => _selected.removeLast());
  }

  void _returnData() => Navigator.pop(context, Arota);

  // Chip’te CS için kullanıcı dostu isim göster
  String _displayName(String code) {
    if (code == 'CS') return 'Şarj İstasyonu';
    return code;
  }

  List<Widget> _buildChipList() => _selected.map((code) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 3.w),
      child: Chip(
        label: Text(_displayName(code), style: TextStyle(color: Colors.white, fontSize: 3.sp)),
        backgroundColor: const Color.fromARGB(255, 32, 32, 32),
        side: BorderSide(width: 0.7.w, color: Colors.blue),
        shape: const StadiumBorder(),
      ),
    );
  }).toList();

  // İstersen gerçek yol hesabını burada kurarsın (şu an kullanılmıyor)
  String rotaOlustur(String from, String to) {
    return ""; // TODO
  }

  // Server’a bas
  Future<void> veriBas(String veri) async {
    try {
      final uri = Uri.parse("${widget.site}/$veri");
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() => _data = response.body);
      } else {
        throw Exception('Veri basılamadı: ${response.reasonPhrase}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _data = 'Hata: $e');
    }
  }

  // Senaryo üret + bas + çık
  Future<void> _buildScenarioAndSend() async {
    if (_selected.isEmpty) return;

    final parts = <String>[];

    // İlk seçim S* ise çıktıya eklemiyoruz (başlangıç kabul)
    int startIndex = 0;
    if (_selected.first.startsWith('S')) {
      startIndex = 1;
    }

    // A/B: q-e-q-e..., S: .../null, CS: .../null
    bool pickupNext = true; // ilk A/B işlemi q
    for (int i = startIndex; i < _selected.length; i++) {
      final p = _selected[i];
      final qr = _qrMap[p] ?? p;

      if (p.startsWith('A') || p.startsWith('B')) {
        parts..add(qr)..add(pickupNext ? 'q' : 'e');
        pickupNext = !pickupNext;
      } else if (p.startsWith('S') || p == 'CS') {
        parts..add(qr)..add('null');
      }
    }

    setState(() {
      senaryoIsDone = true;
      Arota = parts.join('/');
      print(Arota);
    });

    if (Arota.isNotEmpty) {
      await veriBas("v$Arota");
    }

    if (mounted) {
      Navigator.pop(context, Arota);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Senaryo', style: TextStyle(fontSize: 4.sp)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 7.sp),
          onPressed: () {
            if (senaryoIsDone) {
              _returnData();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 20.w),
                  Expanded(child: Center(child: Wrap(spacing: 8.0.w, children: _buildChipList()))),
                  IconButton(
                    onPressed: _undo,
                    icon: Icon(Icons.undo, color: Colors.black, size: 7.sp),
                  ),
                ],
              ),
              SizedBox(height: 50.h),

              Expanded(
                child: Wrap(
                  spacing: 8.0.w,
                  runSpacing: 8.0.w,
                  children: _allPlaces.map((code) {
                    final isCS = code == 'CS';
                    final title = isCS ? 'Şarj İstasyonu' : code;
                    final icon = isCS ? Icons.battery_charging_full : Icons.place_outlined;

                    return SizedBox(
                      width: 50.w,
                      height: 100.h,
                      child: ElevatedButton(
                        onPressed: () => _addPlace(code),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          backgroundColor: const Color.fromARGB(255, 20, 20, 20),
                          side: BorderSide(color: Colors.blue, width: 1.w),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, color: Colors.blue, size: 7.sp),
                            Text(title, textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontSize: isCS ? 3.5.sp : 4.sp),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 10.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 10.w),
                        SizedBox(
                          width: 45.w,
                          height: 60.h,
                          child: ElevatedButton(
                            onPressed: _selected.isNotEmpty ? _buildScenarioAndSend : null,
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.grey,
                              backgroundColor: const Color.fromARGB(255, 20, 20, 20),
                              side: BorderSide(color: Colors.grey, width: 0.4.w),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(60.r)),
                            ),
                            child: Center(
                              child: Text("Senaryo Oluştur", style: TextStyle(color: Colors.white, fontSize: 3.sp)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 50.h),
                    Expanded(
                      child: Text(
                        Arota.isNotEmpty ? "v$Arota" : "Senaryo Oluşmadı",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.blueAccent, fontSize: 4.7.sp),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 60.h),
            ],
          ),
        ),
      ),
    );
  }
}
