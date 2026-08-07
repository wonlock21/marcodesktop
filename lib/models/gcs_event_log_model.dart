import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Zaman damgalı olay kaydı.
class GcsEventEntry {
  final DateTime zaman;
  final String mesaj;

  const GcsEventEntry({required this.zaman, required this.mesaj});

  /// HH:MM:SS formatında zaman damgası.
  String get zamanFormatli {
    final h = zaman.hour.toString().padLeft(2, '0');
    final m = zaman.minute.toString().padLeft(2, '0');
    final s = zaman.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

/// Sistem mesajları / olay günlüğü.
///
/// Üst özet şeridi ve sağ paneldeki anlık durumdan bağımsız olarak
/// zaman damgalı geçmiş olayları tutar.
class GcsEventLogModel extends ChangeNotifier {
  static const int _maxKayit = 50;
  static const String _storageKey = 'gcsEventLog';

  final List<GcsEventEntry> _kayitlar = [];

  GcsEventLogModel() {
    unawaited(_kayitlariYukle());
  }

  List<GcsEventEntry> get kayitlar => List.unmodifiable(_kayitlar);

  /// Yeni olay ekler; en eski kayıtlar limit aşıldığında silinir.
  void ekle(String mesaj, {DateTime? zaman}) {
    _kayitlar.insert(
      0,
      GcsEventEntry(zaman: zaman ?? DateTime.now(), mesaj: mesaj),
    );
    if (_kayitlar.length > _maxKayit) {
      _kayitlar.removeRange(_maxKayit, _kayitlar.length);
    }
    notifyListeners();
    unawaited(_kayitlariKaydet());
  }

  /// Test / admin modu için örnek olay geçmişi.
  ///
  /// Tüm görev aşamalarını ve önemli sistem olaylarını içerir.
  void demoYukle() {
    _kayitlar.clear();
    final now = DateTime.now();
    final kayitlar = [
      // (kaç saniye önce, mesaj)
      (10,  'Yüklü hareket başladı → B3 istikameti'),
      (38,  'Yük alındı — Lift kaldırıldı'),
      (72,  'QR okundu: QA2.1 — Konum doğrulandı'),
      (115, 'Yük alma noktasına ulaşıldı (A2)'),
      (158, 'Yüksüz hareket başladı → A2 istikameti'),
      (183, 'Görev alındı — ID: MSN-0042 | A2 → B3'),
      (210, 'Robot bağlantısı kuruldu'),
      (245, 'Sistem hazır — Görev bekleniyor'),
    ];
    for (final (sn, mesaj) in kayitlar) {
      _kayitlar.add(GcsEventEntry(
        zaman: now.subtract(Duration(seconds: sn)),
        mesaj: mesaj,
      ));
    }
    notifyListeners();
  }

  void temizle() {
    if (_kayitlar.isNotEmpty) {
      _kayitlar.clear();
      notifyListeners();
      unawaited(_kayitlariKaydet());
    }
  }

  Future<void> _kayitlariYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final saved = <GcsEventEntry>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final zaman = DateTime.tryParse(item['zaman']?.toString() ?? '');
        final mesaj = item['mesaj']?.toString() ?? '';
        if (zaman != null && mesaj.isNotEmpty) {
          saved.add(GcsEventEntry(zaman: zaman, mesaj: mesaj));
        }
      }
      final existing = _kayitlar
          .map((e) => '${e.zaman.toIso8601String()}|${e.mesaj}')
          .toSet();
      _kayitlar.addAll(saved.where((e) => existing
          .add('${e.zaman.toIso8601String()}|${e.mesaj}')));
      _kayitlar.sort((a, b) => b.zaman.compareTo(a.zaman));
      if (_kayitlar.length > _maxKayit) {
        _kayitlar.removeRange(_maxKayit, _kayitlar.length);
      }
      notifyListeners();
    } catch (_) {
      // Bozuk eski kayıt uygulamanın açılmasını engellemesin.
    }
  }

  Future<void> _kayitlariKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _kayitlar
        .map((e) => {
              'zaman': e.zaman.toIso8601String(),
              'mesaj': e.mesaj,
            })
        .toList();
    await prefs.setString(_storageKey, jsonEncode(data));
  }
}
