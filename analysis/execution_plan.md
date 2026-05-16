# Liftant v2 — Düzeltme Yol Haritası (Execution Plan)

> **Strateji:** Önce **uygulamayı çökerten / üstel kaynak tüketen** hatalar (P0). Sonra mimari temizlik (P1). **Desktop responsive UI (P2)** eski planda tanımlıydı; **`MERGE_HANDOFF.md` ile proje kararı: Faz 2 iptal** — bu dosyada Faz 2 altında **artık checkbox yok**, sadece arşiv tablosu. Ortak sürümde taban **Faz 0–1 sonrası** kabul edilir. Sonra clean code (P3). Sonra opsiyonel mimari yenileme (P4).
>
> Her adımdan sonra `flutter analyze` ve `flutter run -d windows` ile **manuel sanity check** yapılacak; sonra bu dosyadaki ilgili checkbox işaretlenecek.

---

## 🔴 Faz 0 — Kritik Stabilite (P0)

> Bu faz tamamlanmadan AGV uzun süreli çalıştırılmamalı (üstel timer leak nedeniyle).

### Adım 0.1 — `lib/controller_page.dart` — Üstel Timer Leak'ini Durdur
- [x] `chargingCheck()` metodundaki **iç `Timer.periodic`** kaldır; yalnızca `amper` durumuna göre `isCharging` değişkenini güncelleyen **basit fonksiyon** yap (74. satırdaki ana timer zaten 1 saniyede bir çağırıyor).
- [x] `startConnectionCheck()` içindeki Timer'ı `_connectionTimer` field'ına ata.
- [x] Ana 1 saniyelik polling Timer'ını `_dataPollTimer` field'ına ata.
- [x] `dispose()` metodunda **bütün** timer'ları cancel et: `_poseTimer`, `_dataPollTimer`, `_connectionTimer`.
- [x] `dispose()` içinde `super.dispose()` çağrısını **EN SONA** taşı.
- [x] **Çözdüğü sorun:** Sistem analiz raporu §1.2, §1.3.

### Adım 0.2 — `lib/controller_page.dart` — `_controller` ve `_focusNode` Dispose
- [x] `_ControllerPageState.dispose()` içinde `_controller.dispose()` ve `_focusNode.dispose()` çağrılarını ekle.
- [x] Kullanılmayan `TextEditingController _controller` field'ı silinecekse (Faz 3'te değerlendir), şimdilik sadece dispose ekle. → Faz 1.6'da değerlendirilecek.
- [x] **Çözdüğü sorun:** §2.4 tablo satırı.

### Adım 0.3 — `lib/connection_page.dart` — `_controller` Dispose
- [x] `_ConnectionPageState.dispose()` ekle.
- [x] `_controller.dispose()` çağrısı koy.
- [x] `_ConnectButtonState`'e dispose ekleme gerekmez (sadece bool state'i var, ama tutarlılık için kontrol et). → Teyit edildi: `bool isOn` dışında kaynak yok.
- [x] **Çözdüğü sorun:** §2.4.

### Adım 0.4 — `lib/timer.dart` — Unmount Sonrası setState Koruması
- [x] `_TimerPageState.startTimer` içindeki `setState`'i `if (mounted) setState(...)` ile sar.
- [x] **Çözdüğü sorun:** §2.4 / §1.6.

### Adım 0.5 — Sanity Check
- [x] IDE built-in linter'da bu fazda dokunulan dosyalarda kırmızı yok (`controller_page.dart`, `connection_page.dart`, `timer.dart`, `pubspec.yaml`).
- [x] `flutter pub get` başarılı (Flutter 3.38.9, `web_socket_channel` kaldırıldıktan sonra).
- [x] `flutter analyze` çalıştırıldı: **66 issue** var ama hepsi **önceden var olan** kod kalitesi sorunları (Faz 1.2, 1.6 ve iptal sonrası Faz 3.x'te ele alınacak). Faz 0'da dokunulan kodlarda **yeni** hata YOK.
- [ ] **(KULLANICIYA AİT)** `flutter run -d windows` → uygulama açılıyor, 10 dakika açık kaldıktan sonra Task Manager'da RAM düz kalıyor (üstel artış yok).

---

## 🟠 Faz 1 — Mimari Temizlik (P1)

### Adım 1.1 — `pubspec.yaml` — Ölü Dependency Temizliği
- [x] Şu paketler **kaldırıldı**: `dio`, `get`, `cupertino_icons`, `fluentui_system_icons`, `font_awesome_flutter`.
- [x] `web_socket_channel` paketi **kaldırıldı** (Faz 4 askıya alındığı için).
- [ ] `path_provider`, `process_run` paketleri için karar: Faz 1.2'de kullanılmadıkları doğrulandığında kaldırılır.
- [x] `flutter pub get` çalıştırıldı, build temiz. Güvenlik advisory uyarıları kayboldu, 5 paket dependency tree'den çıktı.
- [x] **Çözdüğü sorun:** §4.5.

### Adım 1.2 — `lib/controller_page.dart` — Ölü Import'ları Sil
- [x] `import 'package:path_provider/path_provider.dart';` → silindi.
- [x] `import 'package:process_run/shell.dart';` → silindi + `var shell = Shell();` field'ı da silindi.
- [x] `import 'dart:ui' as ui;` → silindi.
- [x] `import 'package:flutter/scheduler.dart';` → silindi (`imageCache`, `PaintingBinding` zaten `flutter/material.dart`'tan geliyor).
- [x] `import 'package:web_socket_channel/web_socket_channel.dart';` ve `status.dart` → **silindi** (Faz 0.1 ile birlikte; paket pubspec'ten kaldırıldığı için build için zorunluydu).
- [x] **Bonus:** `import 'dart:io';` ve `import 'dart:typed_data';` de silindi (`flutter analyze` "unused/unnecessary" diyordu; `Uint8List` zaten `flutter/services.dart`'tan geliyor).
- [x] **Bonus:** `pubspec.yaml`'dan `path_provider` ve `process_run` paketleri kaldırıldı (kod tarafında kullanılmadıkları teyit edildi).
- [x] **Çözdüğü sorun:** §4.3.
- **Sonuç:** `flutter analyze` 66 → 61 issue (5 azalış), paket sayısı 28 → 22 (6 transitive dependency düştü).

### Adım 1.3 — `lib/map_page.dart` — Çift Import + Diğer Sil
- [x] `import 'data_model.dart';` iki kez yazılmıştı (1 ve 6. satır), ikincisi silindi.
- [x] **Bonus:** `import 'package:shared_preferences/shared_preferences.dart';` silindi (hiç kullanılmıyordu).
- [x] **Bonus:** `import 'dart:convert';` silindi (hiç kullanılmıyordu).
- [x] **Çözdüğü sorun:** §4.3 tablo.
- **Sonuç:** `flutter analyze` 61 → 58 issue (−3).

### Adım 1.4 — `lib/data_page.dart` — Kullanılmayan `dart:convert`
- [x] `import 'dart:convert';` → silindi.
- [x] **Çözdüğü sorun:** §4.3 tablo.

### Adım 1.5 — `lib/deneme.dart` — Tamamen Ölü Dosya Sil
- [x] Dosya silindi (1137 byte; komple yorumlu Arduino C kodu).
- [x] **Çözdüğü sorun:** §4.1.

### Adım 1.6 — `lib/controller_page.dart` — Kullanılmayan Field'ları Sil
- [x] Silindi: `String yukKutle`, `int actionTime`, `String bas`, `String bit`, `List<dynamic> qrVeri`, `TextEditingController _controller` (kullanılmıyor).
- [x] **Bonus:** `String _data` ve class-level `bool _mapReady` field'ları da silindi (lint `unused_field` uyarıları). `_data` atama satırları `veriBas()` içinden, `_mapReady = false` atama satırı BAĞLANTI button'un else dalından temizlendi.
- [x] Dispose'dan `_controller.dispose()` çağrısı kaldırıldı (field artık yok).
- [x] `voltage` ve `amper` field'ları sakland; UI'da hardcoded `"12.8"` → `voltage`, `""` → `amper` ile değiştirildi (eski 881/833 satırları → şimdi 859/811).
- [x] **Yan iyileştirme:** Amper text fontSize `3.sp` → `5.sp` (diğer sensör kartlarıyla tutarlılık; "boş" göstermek için küçültülmüştü, artık veri geliyor).
- [x] **Çözdüğü sorun:** §4.4.
- **Sonuç:** `flutter analyze` 58 → 54 issue (−4).

### Adım 1.7 — `lib/controller_page.dart` — Ölü Kod Bloklarını Sil
- [x] `LiveMapImage` yorum bloğu silindi (~76 satır — eski 1549-1624).
- [x] Eski `fetchQRData` yorumu silindi (~30 satır — eski 104-133).
- [x] Senaryo navigate sonrası eski if yorumu silindi (3 satır — eski 466-468).
- [x] **Çözdüğü sorun:** §4.2, §4.7.
- **Sonuç:** `flutter analyze` 54 → 54 (yorumlar lint'te değildi), ama `controller_page.dart` **1955 → 1748 satır** (−207 satır, %10.6 ölü kod azalışı).

### Adım 1.8 — `parameter_model.dart` — `loadParameters` Çift Çağrı
- [x] `main.dart`'taki `parameterModel.loadParameters()` çağrısı silindi — `controller_page.dart:initState`'deki çağrı yeterli. `ChangeNotifierProvider(create: (_) => ParameterModel())` tek satıra indi.
- [x] **Çözdüğü sorun:** §2.3.

### Adım 1.9 — Sanity Check
- [x] `flutter analyze` → **0 error-level issue** ✅ (54 toplam issue var ama hepsi warning/info; Faz 3'te ele alınacak — Faz 2 iptal).
- [x] `flutter run -d windows` → kullanıcı manuel test etti, uygulama açılıyor, ana sayfa geliyor, parametre yüklemesi çalışıyor.

---

## ⏸️ Faz 2 — Desktop Responsive UI (P2) — **İPTAL (görev listesi sıfırlandı)**

> **Proje kararı (`MERGE_HANDOFF.md`):** Faz 0–1 korunur; **Faz 2 hedef olarak iptal.** Bu yüzden bu bölümde **artık checkbox / “adım tamamlandı” takibi yok.** Aşağıdaki metin yalnızca arşiv: eski P2 planının ne konuştuğu ve `liftant_v2_bitirme_ilkversiyon` ↔ güncel `liftant_v2_bitirme` arasında **bilinen farklar** (birleştirme veya kod okurken referans). UI iyileştirmeleri devam edecekse **Faz 3** maddeleri veya yeni bir mini-plan ile açılır.

**Özet — P2 olarak artık yürütülmüyor:**
- Büyük ölçekli “tam desktop responsive refactor” takip edilen hedef **değil**; sanity / tamamlama kontrolü **zorunlu değil.**

**Karşılaştırma özeti (metin olarak, görev değil):**

| Alan | İlk versiyon (yedek) | Güncel proje |
|------|---------------------|---------------|
| `main.dart` | `designSize: 390×844`, doğrudan `ScreenUtilInit`, provider içinde `loadParameters()` | `designSize: 1280×720`, `LayoutBuilder` + `ScreenUtilInit`, provider sade (`loadParameters` Faz 1.8’de kaldırıldı) |
| `controller_page.dart` | AppBar’da `Spacer()`; çeşitli layout farkları | `Spacer()` kaldırılmış; tipografi çoğunlukla `.sp`; sensör kartları hâlâ çoğu `60.w` vb. `.sp`/ScreenUtil yapısı (P2’nin eski “sabit px / .sp sıfır” vizyonuna tam uymuyor) |
| `controller_page.dart` | Slider / Switch düzeni eski kalıba yakın | Slider tarafında `SliderTheme`; Switch hâlâ `FittedBox(fill)` içinde olabilir |
| `data_page.dart` | Daha uzun dosya (~497 satır) | Önemli ölçüde sadeleşmiş daha kısa sürüm; yine `.sp`/`.w`/`.h` kullanılıyor (eski planda yanlış “screenutil kalktı” notu düzeltildi) |
| `vehicle_3d_page.dart`, `map_page.dart`, `parameter.dart` | Daha geleneksel / taşmalı düzenler | `Wrap`, scroll, harita için `Expanded`+`LayoutBuilder` vb. kısmi düzen iyileştirmeleri zaman içinde yapılmış olsa bile **bunlar “Faz 2 tamamlandı” sayılmaz** |
| Harita kalibrasyonu | — | `kOriginPx` / `kHeadingOffset` gibi sabitlerde **çift tanım** riski (tek kaynak değil); ileride Faz 3 veya ayrı düzeltme |

---

## 🟡 Faz 3 — Clean Code & Refactor (P3)

### Adım 3.1 — `lib/parameter_model.dart` — Generic Update Metodu
- [ ] 27 `updateXxx` metodu yerine `Map<String, String> _params` field + `updateParam(String key, String value)` metodu.
- [ ] `saveParameters/loadParameters` da loop ile çalışsın.
- [ ] Bu refactor'ün `parameter.dart`'taki tüm çağrı yerlerinde uyumlu olduğundan emin ol.
- [ ] **Çözdüğü sorun:** §4.8.

### Adım 3.2 — `lib/controller_page.dart` — God File'ı Böl
- [ ] `lib/widgets/control_buttons.dart` oluştur, taşı: `PowerButton`, `NormalButton`, `ControlButton`, `QRButton`.
- [ ] `lib/widgets/live_map.dart` oluştur, taşı: `LiveMapFixedUrl`, `_LiveMapFixedUrlState`, `_StatusPane`, `Pose`, kalibrasyon sabitleri.
- [ ] `lib/services/agv_service.dart` oluştur, taşı: `fetchPose`, `fetchSensorData`, `fetchQRData`, `fetchRfid`, `veriBas`, `startSendingData`, `checkConnection`.
- [ ] `controller_page.dart` sadece widget tree ve UI state'i tutsun.
- [ ] **Çözdüğü sorun:** §4.9.

### Adım 3.3 — `setState` Bağımlılığını Azalt
- [ ] AGV sensör state'i (sicaklik, voltage, amper, sonQR, rfid, currX, currY, currYaw, isCharging) için bir `AgvSensorModel extends ChangeNotifier` sınıfı oluştur.
- [ ] `main.dart`'taki `MultiProvider`'a ekle.
- [ ] `controller_page.dart` widget'larında `Consumer<AgvSensorModel>` veya `context.select` ile sadece ilgili widget'ı rebuild et.
- [ ] **Çözdüğü sorun:** §2.5.

### Adım 3.4 — `controller_page.dart` Provider Dinleme Düzelt
- [ ] `Provider.of<DataModel>(context).dataPoints` → `context.watch<DataModel>().dataPoints` veya `Selector` ile spesifik dinle.
- [ ] **Çözdüğü sorun:** §2.2.

### Adım 3.5 — `lib/map_page.dart` — Global Mutable State Kaldır
- [ ] `int incrementThing`, `List<DataPoint> dataPoints`, `List<DataPoint> lastDataPoints`, `int qrDiff` top-level değişkenlerini `_MapPageState` instance field'larına taşı.
- [ ] **Çözdüğü sorun:** §2.6.

### Adım 3.6 — Gereksiz Sarmalama Widget'larını Sadeleştir
- [ ] `controller_page.dart` sensör kartlarındaki `Center > Column > Center > Text` zincirlerini sadeleştir.
- [ ] `Card > SizedBox > Card` zincirlerini sadeleştir.
- [ ] `Padding > Padding` (vehicle_3d_page.dart:37–44) birleştir.
- [ ] **Çözdüğü sorun:** §4.6.

### Adım 3.7 — `mounted` Check'leri Ekle
- [ ] `parameter.dart:53–82` `Future.microtask` içinde `if (mounted) setState(...)` kontrolü.
- [ ] `data_page.dart:31` `_fetchData` sonrası `if (mounted) setState(...)`.
- [ ] `controller_page.dart` tüm async sonrası setState çağrıları (191, 219, 239) → `if (mounted) setState(...)`.
- [ ] **Çözdüğü sorun:** §2.4 tablo.

### Adım 3.8 — `print()` Çağrılarını Temizle
- [ ] Production'da kalmaması gereken `print()` çağrılarını `debugPrint()` ile değiştir veya kaldır.
- [ ] **Çözdüğü sorun:** §4.9.

### Adım 3.9 — Diğer Ölü Kod Blokları
- [ ] `connection_page.dart:62–67` ve `94–98` yorum bloklarını sil.
- [ ] `map_page.dart:78–95` (ölü road widget listeleri) ve `188–194` (ölü gridWidgets init) sil.
- [ ] **Çözdüğü sorun:** §4.7.

### Adım 3.10 — Olası Bug'ları İncele
- [ ] `controller_page.dart:163, 176` — `Future<void>` içinde `return null` → kaldır.
- [ ] `controller_page.dart:192–193` — `currX = y*10; currY = x*10` swap'i için yorum ekle veya server endpoint sözleşmesini netleştir.
- [ ] `controller_page.dart:1861` — bozuk PNG sniffer'ı düzelt: `List.generate(8, (i) => data[i]).every((b) => b == png[data.indexOf(b)])` → indeksli loop kullan.
- [ ] **Çözdüğü sorun:** §4.10.

### Adım 3.11 — Sanity Check
- [ ] Tam regresyon: harita çizme, senaryo, QR ekleme, manuel/otonom geçiş, parametre kaydetme tüm flow'lar çalışıyor.

---

## ⏸️ Faz 4 (ASKIYA ALINDI — Donanım Desteklemiyor)

> **Karar (14.05.2026):** Backend (sunucu) kodu teyit edildi. Sistem HTTP GET üzerine kurulu, WebSocket endpoint'i (`/ws`, `/pose-stream` vb.) **yok**. Bu faz **askıya alındı**; aşağıdaki maddeler bilgi amaçlı tutulmaktadır. `web_socket_channel` paketi `pubspec.yaml`'dan kaldırıldı, ilgili import'lar `controller_page.dart`'tan silindi.

### Adım 4.1 — Karar
- [x] AGV sunucusu WebSocket destekliyor mu? → **HAYIR**, teyit edildi.
- [x] Bu faz iptal, `web_socket_channel` paketi pubspec'ten kaldırıldı.

### ~~Adım 4.2 — `lib/services/agv_socket_service.dart` Oluştur~~ (İPTAL)
- ~~`WebSocketChannel.connect(Uri.parse('ws://$ip:$port/'))`.~~
- ~~`channel.stream.listen(...)` için `StreamSubscription` field'ı ata, dispose'da cancel et.~~
- ~~Mesajları parse edip `AgvSensorModel`'i besle.~~
- ~~HTTP polling (`fetchPose`, `fetchSensorData`, `fetchRfid`, `fetchQRData`) yerini bu stream alsın.~~

### ~~Adım 4.3 — Ağır Parsing'i Isolate'e Taşı~~ (İPTAL — WebSocket'e bağlıydı; gerekirse Faz 3'e taşınır)
- ~~LiveMap görüntü base64 decode'unu `compute()` ile arka plana al (§1.4).~~

### ~~Adım 4.4 — Sanity Check~~ (İPTAL)
- ~~UI bağlantı kopukluğunda donmuyor.~~
- ~~Reconnect mekanizması çalışıyor.~~

---

## Faz-Bazlı Toplam İlerleme

- **Faz 0 (P0 — Stabilite):** 5 / 5 adım ✅ (manuel runtime testi kullanıcıya bırakıldı)
- **Faz 1 (P1 — Temizlik):** 9 / 9 adım ✅ (manuel runtime testi kullanıcıya bırakıldı)
- **Faz 2 (P2 — Responsive):** ⏸️ **İPTAL** (`MERGE_HANDOFF.md`) — **görev listesi sıfırlandı**; bölümde yalnızca ilkversiyon ↔ güncel **karşılaştırma özeti** (arşiv). **“Tamamlanan faz” sayılmaz.**
- **Faz 3 (P3 — Refactor):** 0 / 11 adım
- **Faz 4 (P4 — WebSocket):** ⏸️ ASKIYA ALINDI (donanım desteklemiyor)

**Toplam (Faz 0–1 tamamlandı sayılan aktif adımlar):** 14 / 14 ✅ · **Faz 3 için kalan:** 11 adım · **Faz 2 / Faz 4 plan dışı / askıda**

---

## Kurallar (Her Adım İçin)

1. **Tek adımda tek dosya** (veya çok-dosya değişiklik gerektiren küçük refactor).
2. Adım tamamlandığında bu dosyadaki ilgili checkbox `[x]` yapılacak (**iptal fazlar hariç:** Faz 2’de checkbox kullanılmaz).
3. Faz sonu **sanity check** geçilmeden bir sonraki faza geçilmeyecek.
4. Her adımda `flutter analyze` çıktısı kontrol edilecek; yeni warning eklenmeyecek.
5. Dokunulan kodda gereksiz/açıklayıcı olmayan yorum **eklenmeyecek**.
