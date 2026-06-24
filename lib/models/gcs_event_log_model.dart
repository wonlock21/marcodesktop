import 'package:flutter/foundation.dart';

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

  final List<GcsEventEntry> _kayitlar = [];

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
  }

  /// Demo / admin modu için örnek olay geçmişi.
  void demoYukle() {
    _kayitlar.clear();
    final now = DateTime.now();
    const mesajlar = [
      'Görev tamamlandı',
      'Yük bırakıldı',
      'PLC: Geçiş izni alındı',
      'Kapı kontrol noktasına ulaşıldı',
      'Yük alındı',
      'QR okundu',
      'Görev alındı',
    ];
    for (var i = 0; i < mesajlar.length; i++) {
      _kayitlar.add(GcsEventEntry(
        zaman: now.subtract(Duration(minutes: (mesajlar.length - i) * 2)),
        mesaj: mesajlar[i],
      ));
    }
    notifyListeners();
  }

  void temizle() {
    if (_kayitlar.isNotEmpty) {
      _kayitlar.clear();
      notifyListeners();
    }
  }
}
