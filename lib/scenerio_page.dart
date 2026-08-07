import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'services/agv_service.dart';
import 'services/ros_gcs_contract.dart';
import 'data_model.dart';

// ─── Renk sabitleri (ana GCS ekranıyla birebir) ────────────────────────────
const _bg = Color(0xFF121212);
const _panelBg = Color(0xFF1A1A1A);
const _borderC = Color(0xFF333333);
const _muted = Color(0xFF9E9E9E);
const _bright = Color(0xFFE0E0E0);
const _accent = Color(0xFF42A5F5);
const _danger = Color(0xFFEF5350);

// ─── İstasyon tipi sabitler ───────────────────────────────────────────────
class _StationType {
  final String label;
  final IconData icon;
  final Color color;
  const _StationType(this.label, this.icon, this.color);
}

const _stationTypes = {
  'A': _StationType('Alma Noktası', Icons.download_outlined, Color(0xFF42A5F5)),
  'B':
      _StationType('Bırakma Noktası', Icons.upload_outlined, Color(0xFF66BB6A)),
  'S': _StationType(
      'Başlangıç / Bekleme', Icons.flag_outlined, Color(0xFFFF9800)),
  'C': _StationType(
      'Şarj İstasyonu', Icons.battery_charging_full, Color(0xFFAB47BC)),
};

// ─── İstasyon grid konumları (1–10 x / 1–9 y ölçeği) ─────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class ScenarioPage extends StatefulWidget {
  final List<DataPoint> dataPoints;
  final String site;
  final String rota;

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
  // ── Mevcut state (iş mantığı değişmedi) ─────────────────────────────────
  final List<String> _selected = [];
  final Map<String, String> _nodeByLabel = {};
  final Map<String, Offset> _stationPositions = {};
  List<String> get _allPlaces => _nodeByLabel.keys.toList(growable: false);
  String arota = "";
  bool senaryoIsDone = false;
  bool _submitting = false;
  bool _submitted = false;
  String? _taskId;
  String? _hoveredCode; // hover efekti için

  final Map<String, String> _qrMap = const {
    'A1': 'QA1.1',
    'A2': 'QA2.1',
    'A3': 'QA3.1',
    'A4': 'QA4.1',
    'B1': 'QB1.1',
    'B2': 'QB2.1',
    'B3': 'QB3.1',
    'B4': 'QB4.1',
    'S1': 'S1.1',
    'S2': 'S2.1',
    'CS': 'CS1.1',
  };

  @override
  void initState() {
    super.initState();
    senaryoIsDone = widget.rota.isNotEmpty;
    for (final point in widget.dataPoints) {
      final node = RosGcsContract.nodeForPoint(point);
      if (node == null ||
          (!node.startsWith('alma_') && !node.startsWith('birak_'))) {
        continue;
      }
      final label = RosGcsContract.labelForNode(node);
      _nodeByLabel.putIfAbsent(label, () => node);
      final map = RosGcsContract.graphNodes[node]!;
      _stationPositions[label] = Offset(
        (map.dx + 4) * 1.25,
        (3 - map.dy) * 1.5,
      );
    }
  }

  void _addPlace(String code) => setState(() => _selected.add(code));

  void _undo() {
    if (_selected.isEmpty) return;
    setState(() => _selected.removeLast());
  }

  void _reset() => setState(() {
        _selected.clear();
        arota = "";
        senaryoIsDone = false;
        _submitted = false;
        _taskId = null;
      });

  void _returnData() => Navigator.pop(context, arota);

  String _displayName(String code) => code == 'CS' ? 'Şarj İstasyonu' : code;

  _StationType _tipOf(String code) {
    if (code.startsWith('A')) return _stationTypes['A']!;
    if (code.startsWith('B')) return _stationTypes['B']!;
    if (code.startsWith('S')) return _stationTypes['S']!;
    return _stationTypes['C']!;
  }

  Future<void> _buildScenarioAndSend() async {
    if (_selected.isEmpty || _submitting || _submitted) return;
    if (_selected.length.isOdd ||
        _selected.asMap().entries.any((entry) => entry.key.isEven
            ? !entry.value.startsWith('A')
            : !entry.value.startsWith('B'))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Durakları A (alma), B (bırakma) çiftleri halinde seçin.'),
      ));
      return;
    }
    final routeNodes = _selected.map((p) => _nodeByLabel[p]!).toList();

    if (routeNodes.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'ROS tarafı şu an tek alma-bırakma çifti kabul ediyor. Yalnızca bir A ve bir B noktası seçin.'),
      ));
      return;
    }

    setState(() {
      senaryoIsDone = true;
      arota = routeNodes.join(' → ');
    });
    if (!AgvService.ros.state.value.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Senaryo yerel olarak hazırlandı; ROS bağlı olmadığı için gönderilmedi.'),
      ));
      return;
    }
    setState(() => _submitting = true);
    try {
      _taskId ??= 'gui_${DateTime.now().microsecondsSinceEpoch}';
      final response = await AgvService.submitManualTask(
        taskId: _taskId!,
        pickupNode: routeNodes[0],
        dropoffNode: routeNodes[1],
      );
      if (response['accepted'] != true) {
        throw StateError(response['message']?.toString() ?? 'Görev reddedildi');
      }
      if (mounted) {
        setState(() => _submitted = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(response['message']?.toString() ??
              'Görev kabul edildi; başlatma bekleniyor.'),
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Görev gönderilemedi: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canSave = _selected.isNotEmpty && !_submitting && !_submitted;

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(canSave),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── SOL: Harita alan + seçim şeridi ─────────────────────────────
          Expanded(
            flex: 6,
            child: Column(
              children: [
                // Seçim sırası şeridi
                _buildSelectionStrip(),
                // Harita
                Expanded(child: _buildMapArea()),
              ],
            ),
          ),
          // Dikey ayraç
          Container(width: 0.3.w, color: _borderC),
          // ── SAĞ: Yapılar + Seçili öğe ────────────────────────────────────
          SizedBox(
            width: 90.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(2.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 1.5.h),
                        _panelLabel('YAPILAR'),
                        SizedBox(height: 1.5.h),
                        _buildStationGrid(),
                        SizedBox(height: 3.h),
                        _panelLabel('SEÇİLİ ÖĞE BİLGİSİ'),
                        SizedBox(height: 1.5.h),
                        _buildSelectedInfo(),
                        SizedBox(height: 3.h),
                        _panelLabel('SENARYO ÇIKTISI'),
                        SizedBox(height: 1.5.h),
                        _buildOutputBox(),
                      ],
                    ),
                  ),
                ),
                // Alt butonlar
                _buildBottomActions(canSave),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(bool canSave) => AppBar(
        backgroundColor: _panelBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(0.3.h),
          child: Divider(height: 0.3.h, color: _borderC),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 6.sp, color: _muted),
          onPressed: () =>
              senaryoIsDone ? _returnData() : Navigator.pop(context),
        ),
        title: Text(
          'SENARYO OLUŞTURMA',
          style: TextStyle(
            color: _bright,
            fontSize: 4.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            fontFamily: 'monospace',
          ),
        ),
        actions: [
          // Sıfırla
          _appBarBtn(
            icon: Icons.restart_alt,
            label: 'SIFIRLA',
            color: _danger,
            onTap: _selected.isNotEmpty ? _reset : null,
          ),
          SizedBox(width: 2.w),
          // Haritayı Kaydet
          _appBarBtn(
            icon: Icons.save_outlined,
            label: 'HARİTAYI KAYDET',
            color: _accent,
            onTap: canSave ? _buildScenarioAndSend : null,
          ),
          SizedBox(width: 3.w),
        ],
      );

  Widget _appBarBtn({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.8.h),
        decoration: BoxDecoration(
          color: active ? color.withAlpha(28) : Colors.transparent,
          border: Border.all(
            color: active ? color.withAlpha(160) : _borderC,
            width: 0.4.w,
          ),
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 4.sp, color: active ? color : _muted),
            SizedBox(width: 1.w),
            Text(
              label,
              style: TextStyle(
                color: active ? color : _muted,
                fontSize: 2.8.sp,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Seçim sırası şeridi ──────────────────────────────────────────────────
  Widget _buildSelectionStrip() => Container(
        decoration: BoxDecoration(
          color: _panelBg,
          border: Border(bottom: BorderSide(color: _borderC, width: 0.3.w)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.2.h),
        child: Row(
          children: [
            Icon(Icons.route, size: 4.sp, color: _muted),
            SizedBox(width: 1.5.w),
            Text(
              'ROTA:',
              style: TextStyle(
                color: _muted,
                fontSize: 2.8.sp,
                fontFamily: 'monospace',
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: _selected.isEmpty
                  ? Text(
                      'İstasyon seçin...',
                      style: TextStyle(
                        color: const Color(0xFF444444),
                        fontSize: 3.sp,
                        fontFamily: 'monospace',
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _selected.asMap().entries.map((e) {
                          final i = e.key;
                          final code = e.value;
                          final tip = _tipOf(code);
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (i > 0)
                                Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 0.8.w),
                                  child: Icon(Icons.arrow_forward,
                                      size: 3.sp, color: _muted),
                                ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 1.5.w, vertical: 0.5.h),
                                decoration: BoxDecoration(
                                  color: tip.color.withAlpha(30),
                                  border: Border.all(
                                      color: tip.color.withAlpha(120),
                                      width: 0.4.w),
                                  borderRadius: BorderRadius.circular(3.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(tip.icon,
                                        size: 3.sp, color: tip.color),
                                    SizedBox(width: 0.8.w),
                                    Text(
                                      _displayName(code),
                                      style: TextStyle(
                                        color: _bright,
                                        fontSize: 2.8.sp,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
            SizedBox(width: 1.w),
            // Geri al (undo) butonu
            GestureDetector(
              onTap: _undo,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 0.6.h),
                decoration: BoxDecoration(
                  border: Border.all(color: _borderC, width: 0.4.w),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.undo, size: 4.sp, color: _muted),
                    SizedBox(width: 0.8.w),
                    Text(
                      'GERİ AL',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 2.6.sp,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  // ── Harita alanı ─────────────────────────────────────────────────────────
  Widget _buildMapArea() => Stack(
        fit: StackFit.expand,
        children: [
          // Grid arka planı
          ExcludeSemantics(
            child: CustomPaint(painter: _MapGridPainter()),
          ),
          // İstasyonlar
          LayoutBuilder(builder: (ctx, box) {
            const cols = 11.0; // x bölümü
            const rows = 10.0; // y bölümü
            final cw = box.maxWidth / cols;
            final ch = box.maxHeight / rows;

            return Stack(
              children: [
                // Seçili rota çizgisi
                if (_selected.length >= 2)
                  CustomPaint(
                    size: box.biggest,
                    painter: _RoutePainter(
                      _selected,
                      _stationPositions,
                      cw,
                      ch,
                    ),
                  ),
                // İstasyon noktaları
                ..._allPlaces.map((code) {
                  final pos = _stationPositions[code] ?? const Offset(5, 5);
                  final tip = _tipOf(code);
                  final seqNo = _selected.lastIndexOf(code);
                  final isSelected = seqNo != -1;
                  final dx = pos.dx * cw;
                  final dy = pos.dy * ch;

                  return Positioned(
                    left: dx - 26.r,
                    top: dy - 26.r,
                    child: GestureDetector(
                      onTap: () => _addPlace(code),
                      child: MouseRegion(
                        onEnter: (_) => setState(() => _hoveredCode = code),
                        onExit: (_) => setState(() => _hoveredCode = null),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 52.r,
                          height: 52.r,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? tip.color.withAlpha(50)
                                : _panelBg.withAlpha(200),
                            border: Border.all(
                              color: isSelected
                                  ? tip.color
                                  : (_hoveredCode == code
                                      ? tip.color.withAlpha(160)
                                      : _borderC),
                              width: isSelected ? 1.w : 0.5.w,
                            ),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(tip.icon,
                                  size: 4.sp,
                                  color: isSelected ? tip.color : _muted),
                              SizedBox(height: 0.4.h),
                              Text(
                                code, // kısa kod: A1, B3, CS…
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected ? _bright : _muted,
                                  fontSize: 2.5.sp,
                                  fontFamily: 'monospace',
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              if (isSelected)
                                Text(
                                  '#${seqNo + 1}',
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: tip.color,
                                    fontSize: 2.sp,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          }),
          // Sol alt — alan açıklaması
          Positioned(
            left: 3.w,
            bottom: 2.h,
            child: _buildLegend(),
          ),
        ],
      );

  Widget _buildLegend() => Container(
        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: _panelBg.withAlpha(210),
          border: Border.all(color: _borderC, width: 0.3.w),
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._stationTypes.values.map((t) => Padding(
                  padding: EdgeInsets.only(right: 2.w),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.icon, size: 3.5.sp, color: t.color),
                      SizedBox(width: 0.8.w),
                      Text(
                        t.label,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 2.4.sp,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      );

  // ── Sağ panel: yapılar grid ──────────────────────────────────────────────
  Widget _buildStationGrid() => Wrap(
        spacing: 1.5.w,
        runSpacing: 1.5.h,
        children: _allPlaces.map((code) {
          final tip = _tipOf(code);
          final isSelected = _selected.contains(code);

          return GestureDetector(
            onTap: () => _addPlace(code),
            child: Container(
              width: 38.w,
              padding: EdgeInsets.symmetric(vertical: 1.8.h, horizontal: 0.8.w),
              decoration: BoxDecoration(
                color: isSelected ? tip.color.withAlpha(28) : _panelBg,
                border: Border.all(
                  color: isSelected ? tip.color.withAlpha(160) : _borderC,
                  width: 0.5.w,
                ),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tip.icon,
                      size: 5.sp, color: isSelected ? tip.color : _muted),
                  SizedBox(height: 0.6.h),
                  Text(
                    _displayName(code),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? _bright : _bright,
                      fontSize: 3.2.sp,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 0.3.h),
                  Text(
                    tip.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? tip.color : _muted,
                      fontSize: 2.1.sp,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );

  // ── Seçili öğe bilgisi ───────────────────────────────────────────────────
  Widget _buildSelectedInfo() {
    final last = _selected.isEmpty ? null : _selected.last;

    return Container(
      padding: EdgeInsets.all(2.w),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(color: _borderC, width: 0.4.w),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: last == null
          ? Text(
              'Seçili öğe yok',
              style: TextStyle(
                color: _muted,
                fontSize: 3.sp,
                fontFamily: 'monospace',
                fontStyle: FontStyle.italic,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('TİP', _tipOf(last).label),
                _infoRow('ETİKET', _displayName(last)),
                _infoRow('QR', _qrMap[last] ?? '--'),
                _infoRow(
                    'X KON.',
                    RosGcsContract.graphNodes[_nodeByLabel[last]]?.dx
                            .toStringAsFixed(1) ??
                        '--'),
                _infoRow(
                    'Y KON.',
                    RosGcsContract.graphNodes[_nodeByLabel[last]]?.dy
                            .toStringAsFixed(1) ??
                        '--'),
                _infoRow('SIRADA', '${_selected.length}. istasyon'),
              ],
            ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: EdgeInsets.only(bottom: 0.8.h),
        child: Row(
          children: [
            SizedBox(
              width: 18.w,
              child: Text(
                label,
                style: TextStyle(
                  color: _muted,
                  fontSize: 2.6.sp,
                  fontFamily: 'monospace',
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: _bright,
                  fontSize: 2.6.sp,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

  // ── Senaryo çıktı kutusu ─────────────────────────────────────────────────
  Widget _buildOutputBox() => Container(
        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.5.h),
        decoration: BoxDecoration(
          color: _panelBg,
          border: Border.all(color: _borderC, width: 0.4.w),
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Text(
          arota.isNotEmpty ? 'v$arota' : '-- Henüz oluşturulmadı --',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: arota.isNotEmpty ? _accent : _muted,
            fontSize: 2.8.sp,
            fontFamily: 'monospace',
          ),
        ),
      );

  // ── Alt aksiyon butonları ────────────────────────────────────────────────
  Widget _buildBottomActions(bool canSave) => Container(
        decoration: BoxDecoration(
          color: _panelBg,
          border: Border(top: BorderSide(color: _borderC, width: 0.3.w)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 2.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Haritayı Kaydet
            GestureDetector(
              onTap: canSave ? _buildScenarioAndSend : null,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 1.6.h),
                decoration: BoxDecoration(
                  color: canSave ? const Color(0xFF0D2137) : _panelBg,
                  border: Border.all(
                    color: canSave ? const Color(0xFF1565C0) : _borderC,
                    width: 0.5.w,
                  ),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_outlined,
                        size: 4.sp, color: canSave ? _accent : _muted),
                    SizedBox(width: 1.5.w),
                    Text(
                      'HARİTAYI KAYDET',
                      style: TextStyle(
                        color: canSave ? _accent : _muted,
                        fontSize: 3.sp,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 1.5.h),
            // Sıfırla
            GestureDetector(
              onTap: _selected.isNotEmpty ? _reset : null,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 1.4.h),
                decoration: BoxDecoration(
                  color:
                      _selected.isNotEmpty ? const Color(0xFF2A0A0A) : _panelBg,
                  border: Border.all(
                    color: _selected.isNotEmpty
                        ? const Color(0xFFB71C1C)
                        : _borderC,
                    width: 0.5.w,
                  ),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restart_alt,
                        size: 4.sp,
                        color: _selected.isNotEmpty ? _danger : _muted),
                    SizedBox(width: 1.5.w),
                    Text(
                      'SIFIRLA',
                      style: TextStyle(
                        color: _selected.isNotEmpty ? _danger : _muted,
                        fontSize: 3.sp,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  // ── Yardımcı ─────────────────────────────────────────────────────────────
  Widget _panelLabel(String title) => Text(
        title,
        style: TextStyle(
          color: _muted,
          fontSize: 2.6.sp,
          fontFamily: 'monospace',
          letterSpacing: 1.5,
          fontWeight: FontWeight.w600,
        ),
      );
}

// ─── Harita grid custom painter ───────────────────────────────────────────

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF121212),
    );

    final paint = Paint()
      ..color = const Color(0xFF222222)
      ..strokeWidth = 0.5;

    const step = 30.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Alan etiketleri
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    void drawLabel(String text, Offset pos, Color color) {
      textPainter
        ..text = TextSpan(
          text: text,
          style: TextStyle(
            color: color.withAlpha(100),
            fontSize: 10,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        )
        ..layout();
      textPainter.paint(canvas, pos);
    }

    drawLabel('ALMA ALANI', const Offset(8, 16), const Color(0xFF42A5F5));
    drawLabel(
        'BIRAKIM ALANI', Offset(size.width - 100, 16), const Color(0xFF66BB6A));
    drawLabel('BAŞLANGIÇ', Offset(size.width * 0.4, size.height - 20),
        const Color(0xFFFF9800));
  }

  @override
  bool shouldRepaint(_MapGridPainter old) => false;
}

// ─── Rota çizgi painter ───────────────────────────────────────────────────

class _RoutePainter extends CustomPainter {
  final List<String> selected;
  final Map<String, Offset> positions;
  final double cw;
  final double ch;

  const _RoutePainter(this.selected, this.positions, this.cw, this.ch);

  @override
  void paint(Canvas canvas, Size size) {
    if (selected.length < 2) return;

    final paint = Paint()
      ..color = const Color(0xFF42A5F5).withAlpha(120)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < selected.length; i++) {
      final pos = positions[selected[i]];
      if (pos == null) continue;
      final px = pos.dx * cw;
      final py = pos.dy * ch;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.selected != selected;
}
