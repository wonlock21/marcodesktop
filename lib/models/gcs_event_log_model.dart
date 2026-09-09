import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Zaman damgalı olay kaydı.
class GcsEventEntry {
  final DateTime zaman;
  final String mesaj;
  final String? fingerprint;

  const GcsEventEntry({
    required this.zaman,
    required this.mesaj,
    this.fingerprint,
  });

  /// HH:MM:SS formatında zaman damgası.
  String get zamanFormatli {
    final h = zaman.hour.toString().padLeft(2, '0');
    final m = zaman.minute.toString().padLeft(2, '0');
    final s = zaman.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class GcsRawRosEventEntry {
  final DateTime zaman;
  final String raw;

  const GcsRawRosEventEntry({required this.zaman, required this.raw});

  String get zamanFormatli {
    final h = zaman.hour.toString().padLeft(2, '0');
    final m = zaman.minute.toString().padLeft(2, '0');
    final s = zaman.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _OperatorEvent {
  final String message;
  final String fingerprint;
  final bool visible;

  const _OperatorEvent(this.message, this.fingerprint, {this.visible = true});
}

/// Sistem mesajları / olay günlüğü.
///
/// Üst özet şeridi ve sağ paneldeki anlık durumdan bağımsız olarak
/// zaman damgalı geçmiş olayları tutar.
class GcsEventLogModel extends ChangeNotifier {
  static const int capacity = 200;
  static const String _storageKey = 'gcsEventLog';

  final List<GcsEventEntry> _kayitlar = [];
  final List<GcsRawRosEventEntry> _hamRosKayitlari = [];

  GcsEventLogModel() {
    unawaited(_kayitlariYukle());
  }

  List<GcsEventEntry> get kayitlar => List.unmodifiable(_kayitlar);
  List<GcsRawRosEventEntry> get hamRosKayitlari =>
      List.unmodifiable(_hamRosKayitlari);

  /// Yeni olay ekler; en eski kayıtlar limit aşıldığında silinir.
  void ekle(String mesaj, {DateTime? zaman, String? fingerprint}) {
    if (fingerprint != null) {
      _kayitlar.removeWhere((entry) => entry.fingerprint == fingerprint);
    }
    _kayitlar.insert(
      0,
      GcsEventEntry(
        zaman: zaman ?? DateTime.now(),
        mesaj: mesaj,
        fingerprint: fingerprint,
      ),
    );
    _kayitlar.sort((a, b) => b.zaman.compareTo(a.zaman));
    if (_kayitlar.length > capacity) {
      _kayitlar.removeRange(capacity, _kayitlar.length);
    }
    notifyListeners();
    unawaited(_kayitlariKaydet());
  }

  /// Ham ROS verisini eksiksiz saklar; operatör listesine sade Türkçe mesaj
  /// ekler. ROS stamp saniye cinsindedir.
  void ekleRosEvent(String raw) {
    DateTime time = DateTime.now();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final stamp = decoded['stamp'];
        time = stamp is num && stamp.isFinite
            ? DateTime.fromMicrosecondsSinceEpoch((stamp * 1000000).round())
            : DateTime.now();
        _addRaw(raw, time);
        final event = _formatOperatorEvent(decoded);
        if (event.visible) {
          ekle(event.message, zaman: time, fingerprint: event.fingerprint);
        } else {
          notifyListeners();
        }
        return;
      }
    } catch (_) {
      /* Raw fallback also preserves malformed/forward-compatible events. */
    }
    _addRaw(raw, time);
    ekle('Anlaşılmayan bir ROS sistem olayı alındı.', zaman: time);
  }

  void _addRaw(String raw, DateTime time) {
    _hamRosKayitlari.insert(0, GcsRawRosEventEntry(zaman: time, raw: raw));
    _hamRosKayitlari.sort((a, b) => b.zaman.compareTo(a.zaman));
    if (_hamRosKayitlari.length > capacity) {
      _hamRosKayitlari.removeRange(capacity, _hamRosKayitlari.length);
    }
  }

  static _OperatorEvent _formatOperatorEvent(Map<dynamic, dynamic> event) {
    final name = event['event']?.toString() ?? '';
    final task = event['task_id']?.toString() ?? 'genel';
    final station = _stationFrom(event);
    final route = _stringList(event['route_nodes']).join(' → ');
    final reason = event['reason']?.toString().trim() ?? '';
    final failureKey =
        '$task|görev_hatası|${station ?? _reasonCategory(reason)}';

    switch (name) {
      case 'task_accepted':
        return _OperatorEvent(
          route.isEmpty ? 'Görev hazırlandı.' : 'Görev hazırlandı: $route.',
          '$task|görev_hazır',
        );
      case 'mission_started':
        return _OperatorEvent(
          route.isEmpty ? 'Görev başlatıldı.' : 'Görev başlatıldı: $route.',
          '$task|görev_başladı',
        );
      case 'mission_complete':
        if (event['success'] == true) {
          return _OperatorEvent(
              'Görev başarıyla tamamlandı.', '$task|görev_sonu');
        }
        return _OperatorEvent(
          _failureMessage(reason, station: station),
          failureKey,
        );
      case 'mission_failed':
        return _OperatorEvent(
          _failureMessage(reason, station: station),
          failureKey,
        );
      case 'state_transition':
        final next = event['next_node']?.toString();
        return _OperatorEvent(
          next == null || next.isEmpty
              ? 'Görev bir sonraki aşamaya geçti.'
              : 'Sıradaki hedef: $next.',
          '$task|hedef|${next ?? ""}',
        );
      case 'timed_reverse_docking_started':
      case 'timed_docking_started':
        return _OperatorEvent(
          '${station ?? "İstasyon"} istasyonuna yanaşma başladı.',
          '$task|yanaşma_başladı|${station ?? ""}',
        );
      case 'timed_reverse_docking_finished':
      case 'timed_docking_finished':
        return _OperatorEvent(
          '${station ?? "İstasyon"} istasyonuna yanaşma tamamlandı.',
          '$task|yanaşma_tamamlandı|${station ?? ""}',
        );
      case 'timed_reverse_docking_failed':
      case 'timed_docking_failed':
        return _OperatorEvent(
          '${station ?? "İstasyon"} istasyonuna yanaşma tamamlanamadı.',
          failureKey,
        );
      case 'plc_completion_unacknowledged':
        return _OperatorEvent(
          'Görev sonucu PLC tarafından onaylanmadı.',
          '$task|plc_onayı',
        );
      case 'station_turn_direction_selected':
      case 'station_turn_direction_unavailable':
        return _OperatorEvent(
          _stationTurnMessage(
            event,
            unavailable: name.endsWith('unavailable'),
          ),
          '$task|dönüş_yönü|${station ?? ""}',
        );
      case 'action_started':
        final action = event['action']?.toString() ?? '';
        if (action.contains('docking')) {
          return _OperatorEvent(
            '${station ?? _suffix(action) ?? "İstasyon"} istasyonuna yanaşma başladı.',
            '$task|yanaşma_başladı|${station ?? _suffix(action) ?? ""}',
          );
        }
        if (action.startsWith('follow_route')) {
          final target = _suffix(action);
          return _OperatorEvent(
            target == null
                ? 'Rota üzerinde hareket başladı.'
                : '$target rota noktasına hareket başladı.',
            '$task|rota_hareketi|${target ?? ""}',
          );
        }
        return _OperatorEvent(
          'Görev işlemi başlatıldı.',
          '$task|işlem_başladı|$action',
        );
      case 'route_execution_planned':
      case 'route_segment_started':
      case 'action_finished':
        // Faz ve segment ayrıntıları ham ROS ekranında korunur. Operatör
        // günlüğünde aynı hareket için gereksiz tekrar oluşturmaz.
        return _OperatorEvent('', '$task|teknik|$name', visible: false);
      default:
        if (name.isEmpty) {
          return _OperatorEvent('', '$task|bilinmeyen', visible: false);
        }
        if (name.endsWith('_failed') || reason.isNotEmpty) {
          return _OperatorEvent(
            _failureMessage(reason, station: station),
            failureKey,
          );
        }
        // Yeni/teknik olaylar kaybolmaz; ham ROS ekranında eksiksiz kalır.
        // Operatör günlüğünü anlaşılmayan event adlarıyla doldurmayız.
        return _OperatorEvent('', '$task|bilinmeyen|$name', visible: false);
    }
  }

  static String _failureMessage(String reason, {String? station}) {
    final lower = reason.toLowerCase();
    final reasonStation = station ?? _stationFromReason(reason);
    if (lower.contains('operator cancel')) {
      return 'Görev operatör tarafından iptal edildi.';
    }
    if (lower.contains('timed_docking') || lower.contains('reverse_docking')) {
      return 'Görev başarısız: ${reasonStation ?? "hedef"} istasyonuna yanaşılamadı.';
    }
    if (lower.contains('follow_route')) {
      final position = RegExp(r'konum hatasi=([0-9.]+)').firstMatch(lower);
      final heading = RegExp(r'yon hatasi=([0-9.]+)').firstMatch(lower);
      final details = <String>[
        if (position != null) 'konum hatası ${position.group(1)} m',
        if (heading != null) 'yön hatası ${heading.group(1)}°',
      ];
      return 'Rota takibi başarısız${details.isEmpty ? "." : ": ${details.join(", ")}."}';
    }
    if (lower.contains('rota yuk/yon kurallari uygulanamadi')) {
      return 'Görev başarısız: rota yük/yön kuralları uygulanamadı.';
    }
    if (reason.isEmpty) return 'Görev başarısız oldu.';
    return 'Görev başarısız oldu. Teknik ayrıntıları ROS loglarından inceleyin.';
  }

  static String? _stationFrom(Map<dynamic, dynamic> event) {
    final direct = event['station']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;
    return _stationFromReason(event['reason']?.toString() ?? '') ??
        _suffix(event['action']?.toString() ?? '');
  }

  static String? _stationFromReason(String reason) {
    final match = RegExp(r'(?:timed_docking|reverse_docking):([^ ,]+)')
        .firstMatch(reason);
    return match?.group(1);
  }

  static String _reasonCategory(String reason) {
    if (reason.contains('docking')) return 'yanaşma';
    if (reason.contains('follow_route')) return 'rota';
    if (reason.contains('operator cancel')) return 'iptal';
    return 'genel';
  }

  static String? _suffix(String value) {
    final separator = value.lastIndexOf(':');
    if (separator < 0 || separator == value.length - 1) return null;
    return value.substring(separator + 1).trim();
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<String>().where((value) => value.isNotEmpty).toList();
  }

  static String _stationTurnMessage(Map<dynamic, dynamic> event,
      {required bool unavailable}) {
    String arc(String label, dynamic raw) {
      final value = raw is Map ? raw : const {};
      final safe = value['safe'] == true;
      final clearance = value['minimum_clearance_m'];
      final reason = value['reason']?.toString().trim() ?? '';
      final clearanceText = clearance is num && clearance.isFinite
          ? ', minimum açıklık ${clearance.toStringAsFixed(2)} m'
          : '';
      final reasonText = reason.isEmpty ? '' : ', neden: $reason';
      return '$label: ${safe ? "Güvenli" : "Engelli"}$clearanceText$reasonText';
    }

    final station = event['station']?.toString() ?? 'İstasyon';
    final selected = event['selected_direction']?.toString();
    final heading = selected == 'left'
        ? 'Sol'
        : selected == 'right'
            ? 'Sağ'
            : 'Seçilemedi';
    final prefix = unavailable
        ? '$station dönüş yönü seçilemedi'
        : '$station dönüş yönü: $heading';
    return '$prefix · ${arc("Sol yay", event['left'])} · '
        '${arc("Sağ yay", event['right'])}';
  }

  /// Test / admin modu için örnek olay geçmişi.
  ///
  /// Tüm görev aşamalarını ve önemli sistem olaylarını içerir.
  void demoYukle() {
    _kayitlar.clear();
    _hamRosKayitlari.clear();
    final now = DateTime.now();
    final kayitlar = [
      // (kaç saniye önce, mesaj)
      (10, 'Yüklü hareket başladı → B3 istikameti'),
      (38, 'Yük alındı — Lift kaldırıldı'),
      (72, 'QR okundu: QA2.1 — Konum doğrulandı'),
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
    if (_kayitlar.isNotEmpty || _hamRosKayitlari.isNotEmpty) {
      _kayitlar.clear();
      _hamRosKayitlari.clear();
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
        if (zaman != null &&
            mesaj.isNotEmpty &&
            !_looksLikeLegacyRawRosMessage(mesaj)) {
          saved.add(GcsEventEntry(zaman: zaman, mesaj: mesaj));
        }
      }
      final existing = _kayitlar
          .map((e) => '${e.zaman.toIso8601String()}|${e.mesaj}')
          .toSet();
      _kayitlar.addAll(saved.where(
          (e) => existing.add('${e.zaman.toIso8601String()}|${e.mesaj}')));
      _kayitlar.sort((a, b) => b.zaman.compareTo(a.zaman));
      if (_kayitlar.length > capacity) {
        _kayitlar.removeRange(capacity, _kayitlar.length);
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

  static bool _looksLikeLegacyRawRosMessage(String message) {
    if (message.trimLeft().startsWith('{')) return true;
    return RegExp(r'^[a-z][a-z0-9_]*\s+·\s*\{').hasMatch(message.trimLeft());
  }
}
