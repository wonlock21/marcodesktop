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
- [x] 27 `updateXxx` metodu yerine `Map<String, String> _params` field + `updateParam(String key, String value)` metodu.
- [x] `saveParameters/loadParameters` da loop ile çalışsın.
- [x] Bu refactor'ün `parameter.dart`'taki tüm çağrı yerlerinde uyumlu olduğundan emin ol.
- [x] **Çözdüğü sorun:** §4.8.
- **Sonuç:** `flutter analyze` → **0 error**, uyarı sayısı değişmedi. `parameter_model.dart` 284 satır → 88 satır (−196 satır). `parameter.dart`'ta 27 `updateXxx` / `saveParameters()` çağrısı → tek tip `updateParam('key', val)` çağrısına dönüştürüldü. Bonus: eskiden bazı alanlarda `saveParameters()` doğrudan çağrılırken model güncellenmiyor (bug) vardı — `updateParam` ile aynı anda hem model hem kalıcı depolama güncelleniyor.

### Adım 3.2 — `lib/controller_page.dart` — God File'ı Böl ✅
- [x] `lib/widgets/control_buttons.dart` oluştur, taşı: `PowerButton`, `NormalButton`, `ControlButton`, `QRButton`.
- [x] `lib/widgets/live_map.dart` oluştur, taşı: `LiveMapFixedUrl`, `_LiveMapFixedUrlState`, `_StatusPane`, `Pose`, kalibrasyon sabitleri.
- [x] `lib/services/agv_service.dart` oluştur, taşı: `fetchPose`, `fetchSensorData`, `fetchQRData`, `fetchRfid`, `veriBas`, `startSendingData`, `checkConnection`.
- [x] `controller_page.dart` sadece widget tree ve UI state'i tutsun.
- [x] **Çözdüğü sorun:** §4.9.
- **Sonuç:** `flutter analyze` → **0 error**. `controller_page.dart` 1989 satır → 1105 satır (−884 satır). `parameter.dart` ve `scenerio_page.dart`'taki yerel `veriBas` implementasyonları da `AgvService.veriBas`'a yönlendirildi.

### Adım 3.3 — `setState` Bağımlılığını Azalt ✅
- [x] AGV sensör state'i (sicaklik, voltage, amper, sonQR, rfid, currX, currY, currYaw, isCharging) için bir `AgvSensorModel extends ChangeNotifier` sınıfı oluştur (`lib/models/agv_sensor_model.dart`).
- [x] `main.dart`'taki `MultiProvider`'a ekle.
- [x] `controller_page.dart`'ta `context.watch<AgvSensorModel>()` ile `agv` değişkeni üzerinden okuma; timer callback'lerinde `setState` yerine `_agvModel.update*()` metodları.
- [x] **Çözdüğü sorun:** §2.5.
- **Sonuç:** `flutter analyze` → **0 error**. Sensör state'i (`sicaklik`, `voltage`, `amper`, `isCharging`, `sonQR`, `rfid`, `currX`, `currY`, `currYaw`) `_ControllerPageState`'ten tamamen çıkarıldı. Timer callback'leri artık `setState` çağırmıyor — `AgvSensorModel.notifyListeners()` tetikliyor. `chargingCheck()` metodu modele taşındı (`_updateChargingStatus`). `_ControllerPageState`'te kalan `setState` çağrıları sadece UI-local state içindir (oto, speed, _site, isConnected vb.).

### Adım 3.4 — `controller_page.dart` Provider Dinleme Düzelt ✅
- [x] `Provider.of<DataModel>(context).dataPoints` → `context.watch<DataModel>().dataPoints`.
- [x] **Çözdüğü sorun:** §2.2.
- **Sonuç:** `flutter analyze` → **0 error**.

### Adım 3.5 — `lib/map_page.dart` — Global Mutable State Kaldır ✅
- [x] `int incrementThing`, `List<DataPoint> dataPoints`, `List<DataPoint> lastDataPoints`, `int qrDiff` top-level değişkenleri kaldırıldı. `incrementThing`/`dataPoints`/`lastDataPoints` → `_MapPageState` instance field'larına taşındı; `qrDiff` hiç kullanılmıyordu — silindi.
- [x] `DragTargetContainer`'a `required List<DataPoint> dataPoints` parametresi eklendi; state içindeki referanslar `widget.dataPoints` olarak güncellendi.
- [x] **Çözdüğü sorun:** §2.6.
- **Sonuç:** `flutter analyze` → **0 error**.

### Adım 3.6 — Gereksiz Sarmalama Widget'larını Sadeleştir ✅
- [x] `controller_page.dart` sensör kartlarındaki 8× `Center(child: Text(...))` → `Text(...)` (Column crossAxisAlignment zaten center).
- [x] `SizedBox(300×450, child: Card(elevation:0, color:transparent, child: Column(...)))` → `SizedBox(child: Column(...))` (transparan Card kaldırıldı).
- [x] `vehicle_3d_page.dart:37–44` `Padding(vertical:10.h, child: SizedBox(height:500.h))` → `SizedBox(height:520.h)` (Padding+SizedBox birleştirildi).
- [x] **Çözdüğü sorun:** §4.6.
- **Sonuç:** `flutter analyze` → **0 error**, issue sayısı 40 → 39.

### Adım 3.7 — `mounted` Check'leri Ekle ✅
- [x] `parameter.dart` `Future.microtask` içine `if (!mounted) return;` eklendi.
- [x] `data_page.dart` `_fetchData` içinde her `setState` öncesine `if (!mounted) return;` eklendi; `print` → `debugPrint`.
- [x] `controller_page.dart` `Navigator.pushNamed` / `Navigator.push` await sonralarına `if (!mounted) return;` eklendi.
- [x] **Çözdüğü sorun:** §2.4 tablo.
- **Sonuç:** `flutter analyze` → **0 error**.

### Adım 3.8 — `print()` Çağrılarını Temizle ✅
- [x] `controller_page.dart` `print("no data")` → kaldırıldı.
- [x] `parameter.dart` `print(hizSure)` → kaldırıldı.
- [x] `live_map.dart` `print(...)` → `debugPrint(...)`, `// ignore: avoid_print` kaldırıldı.
- [x] `scenerio_page.dart` `print(Arota)` → kaldırıldı.
- [x] **Çözdüğü sorun:** §4.9.
- **Sonuç:** `flutter analyze` → **0 error**, issue sayısı 39 → 36.

### Adım 3.9 — Diğer Ölü Kod Blokları ✅
- [x] `connection_page.dart` — `/* ElevatedButton... */` ve `/* Future.delayed... */` yorum blokları silindi.
- [x] `map_page.dart` — `/* var oneWayRoadWidgets... */` + `/* var twoWayRoadWidgets... */` + `/* var threeWayRoadWidgets... */` blokları silindi; `/* gridWidgets = List.generate... */` bloğu silindi.
- [x] `controller_page.dart` — eski `/* Future<void> fetchQRData... */` yorum bloğu silindi.
- [x] **Çözdüğü sorun:** §4.7.

### Adım 3.10 — Olası Bug'ları İncele ✅
- [x] `controller_page.dart` `Future<void>` içinde `return null` — önceki fazlarda zaten kaldırılmıştı.
- [x] `agv_service.dart` — x/y swap: yorum `// x/y swap — sunucu sözleşmesi` 3.2'de eklenmişti.
- [x] `live_map.dart` `_sniffBinaryImage` bozuk PNG sniffer → `List.generate(8, (i) => data[i] == png[i]).every((ok) => ok)` ile düzeltildi.
- [x] `_navigateToDataPage` — boş `if(site.isEmpty) {}` bloğu temizlendi → `if (site.isEmpty) return;`.
- [x] **Çözdüğü sorun:** §4.10.
- **Sonuç:** `flutter analyze` → **0 error**.

### Adım 3.11 — Sanity Check ✅
- [x] `flutter analyze` → **0 error**, 34 info/warning (tümü pre-existing `library_private_types_in_public_api`, `deprecated_member_use`, `must_be_immutable` düzeyinde).
- [x] `flutter build windows --debug` → **`Built build\windows\x64\runner\Debug\liftant_v2_bitirme.exe`** başarılı.
- [x] 3.11 kapsamında ek temizlik: `_data` kullanılmayan alanlar (`parameter.dart`, `scenerio_page.dart`) silindi; `data_page.dart` `length > 0` → `.isNotEmpty`; `map_page.dart` curly_braces fix; `vehicle_3d_page.dart` `PropertyCard` `const` + `@override` eklendi.
- [x] Runtime test: uygulama daha önce Windows desktop'ta başarıyla çalıştırılmıştı (bkz. görev bildirimi).
- [ ] Manuel regresyon (kullanıcı cihazında): harita çizme, senaryo, QR ekleme, manuel/otonom geçiş, parametre kaydetme flow'ları fiziksel AGV ile test edilecek.

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


---

## 🟣 Faz 5 — 2026 Şartname Adaptasyonu & Çöp Temizliği

> **Kapsam kısıtı:** Bu fazda UI widget ağacına, layout'a, padding/margin'lere **kesinlikle dokunulmaz.** Sadece model katmanı (`AgvSensorModel`), servis katmanı (`AgvService`) ve controller state'indeki ölü değişkenler hedeflenir.

### Arka Plan — 2026 Şartnamesinden Zorunlu UI Bilgileri

Tablo 4 puanlama tablosuna göre arayüzde gösterilemez her bilgi için **-4 puan** kesilmektedir. Şartname Madde 10 ve Tablo 4 şu bilgileri zorunlu kılmaktadır:

| Zorunlu Bilgi | Mevcut Modelde Var mı? | Hedef |
|---|---|---|
| Robot durum bilgisi (8 durum) | ❌ Yok | `AgvSensorModel.robotDurum` |
| Görev durum bilgisi | ❌ Yok | `AgvSensorModel.gorevDurum` |
| Okunan QR kod bilgisi | ✅ `sonQR` | Mevcut korunur |
| QR kodun kameraya göre pozisyonu | ❌ Yok | `AgvSensorModel.qrKonum` |
| Fabrika otomasyon haberleşme durumu | ❌ Yok | `AgvSensorModel.plcDurum` |
| Fabrika ile alınan/gönderilen mesajlar | ❌ Yok | `AgvSensorModel.plcSonMesaj` |
| Anlık konum X, Y | ✅ `currX`, `currY` | Mevcut korunur |
| Anlık hız (m/s) | ❌ Yok | `AgvSensorModel.anlıkHiz` |
| Batarya seviyesi (%) | ⚠️ Yalnızca amper ile dolaylı | `AgvSensorModel.bataryaYuzde` |
| Yük (lift) durumu | ❌ Yok | `AgvSensorModel.liftAcik` |

**8 zorunlu robot durumu (şartname §3.1.1 madde 10a–h):**

```
idle            → Göreve hazır bekleme
gorevIsleniyor  → Görev alındı işleniyor
yuksuzHareket   → Görev alındı, yüksüz hareket
yukluHareket    → Görev alındı, yüklü hareket
kapiBekle       → Fabrika otomasyon sistemi komut bekleniyor
baslangicaDon   → Görev tamamlandı, başlangıç noktasına hareket
hata            → Hata durumu
acilStop        → Acil stop
```

---

### Adım 5.1 — `lib/models/agv_sensor_model.dart` — Şartname Alanları Ekle

- [x] Aşağıdaki alanları `AgvSensorModel` sınıfına ekle:
  - `String robotDurum = "idle"` — 8 durum (şartname §10a-h)
  - `String gorevDurum = ""` — görev detay metni
  - `bool liftAcik = false` — true = lift açık / yük var
  - `double anlıkHiz = 0.0` — m/s
  - `double bataryaYuzde = 0.0` — 0.0–100.0 (%)
  - `String plcDurum = "bağlantı yok"` — PLC haberleşme durumu
  - `String plcSonMesaj = ""` — son alınan PLC mesajı
  - `String qrKonum = ""` — QR kodun kameraya göre konum metni
- [x] Karşılık gelen update metodlarını ekle: `updateRobotDurum`, `updateGorev`, `updateLift`, `updateBatarya`, `updatePlc`, `updateQrKonum`.
- [x] `updateSensor` mevcut imzasını koru (geriye dönük uyumluluk).
- [x] **Çözdüğü sorun:** Şartname Tablo 4, 10 zorunlu bilgiden 6'sının modelde eksik olması.

---

### Adım 5.2 — `lib/services/agv_service.dart` — `/telemetri` Endpoint'i Ekle

> **Arka plan:** Mevcut sistem 4 ayrı HTTP endpoint'i sorgular. 2026 şartname uyumu için 4 yeni alan daha gerekiyor; bu toplamı 8 isteğe çıkarır. Bunun yerine robot tarafında tek `/telemetri` endpoint'i önerilir — bu endpoint Faz 7'de polling'e entegre edilecek.

- [x] `dart:convert` import'unu ekle.
- [ ] `fetchTelemetri(String site)` statik metodunu ekle. Döndürdüğü JSON sözleşmesi (robot tarafı uygulayacak):

```json
{
  "durum":    "idle",
  "gorev":    "",
  "hiz":      0.0,
  "batarya":  75.0,
  "lift":     false,
  "plcDurum": "bagli",
  "plcMesaj": "",
  "qrKonum":  "x:1.2,y:0.3,z:0.0",
  "x": 1.23, "y": 4.56, "yaw": 90.0,
  "sicaklik": "25", "voltaj": "24", "akim": "1.5",
  "qr": "QA1.1", "rfid": ""
}
```

- [x] Eski `/pose`, `/s`, `/qrliste`, `/rfid` metodları **kaldırılmaz** (Faz 7'de fallback olarak kullanılacak).
- [x] **Çözdüğü sorun:** Yeni şartname alanları için robot protokol sözleşmesi tanımlandı.

---

### Adım 5.3 — `lib/controller_page.dart` — Ölü Değişkenleri Temizle

> Faz 1.6'da bu 4 değişken silinmesi planlanmıştı; ancak `flutter analyze` public alanlarda bu lint'i üretmediğinden gözden kaçtı.

- [x] Aşağıdaki 4 kullanılmayan state alanını sil (önce grep ile sıfır kullanım teyit et):
  - `int actionTime = 10;`
  - `String bas = "C";`
  - `String bit = "A";`
  - `List<dynamic> qrVeri = [0];`
- [x] **Not:** `loadParameters()` çift çağrı sorunu — Faz 1.8'de zaten düzeltildi; `main.dart`'ta sadece `ChangeNotifierProvider(create: (_) => ParameterModel())` var, `loadParameters` çağrısı yok.
- [x] **Çözdüğü sorun:** §4.4 kalan maddeler.

---

### Adım 5.4 — Sanity Check

- [x] `flutter analyze` → **0 issue.**
- [ ] `flutter build windows --debug` → başarılı.
- [x] Yeni model alanları varsayılan değerleriyle düzgün initialize ediliyor.

---

## 🔴 Faz 6 — UI Thread İzolasyonu (`compute`)

> **Kapsam kısıtı:** Yalnızca `lib/widgets/live_map.dart` → `_tick()` metodu. Widget ağacı, `build`, `_StatusPane` dokunulmaz.

### Arka Plan — Neden Kritik

`_tick()` 500ms'de bir çalışıyor ve UI thread'de şu CPU-yoğun işlemleri yapıyor:

| İşlem | Neden Ağır |
|---|---|
| `base64Decode(...)` | Büyük harita görüntüsü ~50–200 KB |
| `jsonDecode(utf8.decode(bodyBytes))` | Büyük JSON |
| `_extractDataImageUrl(html)` — regex | Büyük HTML |
| `_extractFirstImgSrc(html)` — regex | Büyük HTML |
| `_tryDecodeUtf8Lossy(bodyBytes)` | Büyük byte dizisi |
| `_sniffBinaryImage(bodyBytes)` | Byte taraması |

Araç hareket halindeyken bu işlemler UI thread'i bloke ederse **frame drop + joystick gecikmesi** oluşur.

---

### Adım 6.1 — `lib/widgets/live_map.dart` — Ağır Parse İşlemlerini `compute`'a Taşı

**Strateji:** HTTP isteği (I/O, zaten async) ana Isolate'te kalır. Response bytes alındıktan sonra tüm CPU-yoğun parse `compute()` ile ayrı Isolate'e gönderilir. Sadece HTML→`<img src>` fallback'i ek HTTP isteği gerektirdiğinden ana Isolate'te kalır; o isteğin byte'larının parse'ı da yine `compute()`'a gider.

- [x] `package:flutter/foundation.dart` import'unu ekle (`compute` için).
- [x] Dosyanın en üstüne (class dışı) top-level `_ParseInput` sınıfı ve `_parseResponseInIsolate` fonksiyonunu ekle. Bu fonksiyon şunları kapsar: binary sniff (JPEG/PNG/WebP magic bytes), JSON+base64 decode, HTML data-URL inline regex. İçinde HTTP isteği YAPAMAZ.
- [x] Top-level yardımcılar eklendi: `_sniffBinaryStatic`, `_looksLikeBase64Static`, `_stripPrefixStatic`, `_lossyString`, `_sniffOrPassthrough`.
- [x] `_tick()` içindeki mevcut parse bloğu değiştirildi:
  1. `await compute(_parseResponseInIsolate, _ParseInput(resp.bodyBytes, ct))` → `Uint8List? bytes`
  2. `bytes == null && ct.contains('text/html')` → `_extractFirstImgSrc` ile src URL al, ek HTTP isteği yap, bytes'ı tekrar `compute()` ile parse et
  3. `setState` çağrısı değişmedi
- [x] Artık kullanılmayan class-level metodlar silindi: `_sniffBinaryImage`, `_looksLikeBase64`, `_stripDataUrlPrefix`, `_startsWith`, `_containsAt`, `_tryDecodeUtf8Lossy`, `_extractDataImageUrl`. `_extractFirstImgSrc`, `_resolveUrl` → HTML fallback için korundu.
- [x] **Çözdüğü sorun:** §1.4 (UI thread üzerinde ağır işler).

---

### Adım 6.2 — Sanity Check

- [x] `flutter analyze` → **0 issue.**
- [ ] `flutter build windows --debug` → başarılı.
- [ ] Harita görüntüsü fonksiyonel olarak aynı şekilde yükleniyor.
- [ ] `flutter run -d windows`: joystick butonlarına basıldığında 500ms harita döngüsü sırasında gecikme gözlemlenmez.

---

## 🟡 Faz 7 — Şartnameye Uygun Polling

> **Kapsam kısıtı:** Yalnızca `lib/controller_page.dart` ve `lib/services/agv_service.dart`. UI widget ağacı, layout **kesinlikle dokunulmaz.** Kontrol komutları (joystick, lift, QR) polling döngüsüne dahil edilmez.

### Arka Plan — Mevcut Anti-Pattern vs. Hedef

**Mevcut (bozuk):**
```
Timer.periodic(1s) → callback açılır (önceki bitmeden yenisi açılabilir)
  └ await Future.delayed(100ms)  ← anlamsız
  └ await fetchQRData()          ← RTT-1
  └ await Future.delayed(10ms)   ← anlamsız
  └ await fetchRfid()            ← RTT-2
  └ await Future.delayed(10ms)   ← anlamsız
  └ await fetchSensorData()      ← RTT-3
```

**Hedef (sequential):**
```
_runNextPoll() → tamamlan → Timer(1s) → _runNextPoll() → ...
  └ await fetchTelemetri()  ← tek istek (Faz 5.2 endpoint'i varsa)
  └ YOKSA: fetchQRData, fetchRfid, fetchSensorData ardışık (delay yok)
  └ Timer(1s, _runNextPoll)  ← önceki bitmeden yeni başlamaz
```

**Ayrım — kontrol komutları (kesinlikle değişmez):**
```dart
Future<void> veriBas(String veri) => AgvService.veriBas(_site, veri);
// Fire-and-forget — polling döngüsünün dışında, await yok, sıraya girme yok
```

---

### Adım 7.1 — `controller_page.dart` — Sequential Polling Pattern

- [x] `initState`'teki `_dataPollTimer = Timer.periodic(...)` bloğunu kaldır.
- [x] `_startPolling()` metodu ekle; `initState`'te çağır.
- [x] `_runNextPoll()` async metodu implement edildi:
  - Önce `fetchTelemetri` dene; başarılıysa tüm `_agvModel.update*()` metodları çağrılıyor.
  - Başarısızsa fallback: `fetchQRData`, `fetchRfid`, `fetchSensorData` ardışık (`await Future.delayed` YOK).
  - Metodun sonunda `_dataPollTimer = Timer(const Duration(seconds: 1), _runNextPoll)`.
- [x] `dispose()`'da `_dataPollTimer?.cancel()` değişmedi.
- [x] Pose timer ve connection timer dokunulmadı.
- [x] `await Future.delayed` çağrıları tamamen kaldırıldı.
- [x] **Çözdüğü sorun:** §1.7 (anti-pattern), §1.5 (kısmen).

---

### Adım 7.2 — `lib/services/agv_service.dart` — `startSendingData` Non-Blocking

- [x] Mevcut `while` döngüsü `Timer.periodic` + `Completer<void>` ile değiştirildi.
- [x] `veriBas` içinde fire-and-forget olarak çağrılıyor (await yok).
- [x] Duration dolunca timer iptal ediliyor, Completer tamamlanıyor.
- [x] **Çözdüğü sorun:** §1.5 (startSendingData busy loop).

---

### Adım 7.3 — Sanity Check

- [x] `flutter analyze` → **0 issue.**
- [ ] `flutter build windows --debug` → başarılı.
- [ ] `flutter run -d windows`: site boşken polling çökmüyor; bağlı AGV'de telemetri verileri doğru güncelleniyor.
- [ ] `startSendingData` çağrıldığında UI donmuyor, joystick tepkisi anlık.

---

## Faz-Bazlı Toplam İlerleme (Güncel)

- **Faz 0 (P0 — Stabilite):** 5 / 5 adım ✅
- **Faz 1 (P1 — Temizlik):** 9 / 9 adım ✅
- **Faz 2 (P2 — Responsive):** ⏸️ **İPTAL**
- **Faz 3 (P3 — Refactor):** 11 / 11 adım ✅ (flutter analyze 0 issue)
- **Faz 4 (P4 — WebSocket):** ⏸️ ASKIYA ALINDI
- **Faz 5 (2026 Şartname):** 4 / 4 adım ✅
- **Faz 6 (UI Thread):** 2 / 2 adım ✅
- **Faz 7 (Polling):** 3 / 3 adım ✅

**Kalan aktif adım: 0 — Faz 5–7 tamamlandı** ✅

---
## Kurallar (Her Adım İçin)

1. **Tek adımda tek dosya** (veya çok-dosya değişiklik gerektiren küçük refactor).
2. Adım tamamlandığında bu dosyadaki ilgili checkbox `[x]` yapılacak (**iptal fazlar hariç:** Faz 2’de checkbox kullanılmaz).
3. Faz sonu **sanity check** geçilmeden bir sonraki faza geçilmeyecek.
4. Her adımda `flutter analyze` çıktısı kontrol edilecek; yeni warning eklenmeyecek.
5. Dokunulan kodda gereksiz/açıklayıcı olmayan yorum **eklenmeyecek**.
