# Liftant v2 — Sistem Analiz Raporu

> **Proje:** Flutter Desktop GUI — AGV (Otonom Yönlendirmeli Araç) kontrol arayüzü
> **Analiz Tarihi:** 14 Mayıs 2026
> **Hedef Platform:** Windows Desktop (linux/macos klasörleri de mevcut)
> **Flutter SDK:** `>=3.4.0-190.0.dev <4.0.0`

Bu rapor, `lib/` altındaki **13 Dart dosyasının** (yaklaşık **270.000 byte** kaynak kod) tek tek incelenmesiyle hazırlanmıştır. Aşağıdaki tablo, dosya-bazlı kritik sorun yoğunluğunu özetler:

| Dosya | Boyut | Kritik Sorun Sayısı | Öncelik |
|---|---|---|---|
| `controller_page.dart` | 81 KB | 14 | 🔴 ÇOK YÜKSEK |
| `parameter.dart` | 66 KB | 4 | 🟠 YÜKSEK |
| `map_page.dart` | 49 KB | 7 | 🟠 YÜKSEK |
| `data_page.dart` | 21 KB | 3 | 🟡 ORTA |
| `parameter_model.dart` | 8.6 KB | 2 | 🟡 ORTA |
| `qr_page.dart` | 6.3 KB | 2 | 🟡 ORTA |
| `vehicle_3d_page.dart` | 6.1 KB | 2 | 🟢 DÜŞÜK |
| `connection_page.dart` | 5.1 KB | 2 | 🟡 ORTA |
| `main.dart` | 3.5 KB | 1 | 🔴 ÇOK YÜKSEK (designSize) |
| `scenerio_page.dart` | 8.5 KB | 1 | 🟢 DÜŞÜK |
| `data_model.dart` | 2.0 KB | 0 | 🟢 DÜŞÜK |
| `timer.dart` | 1.1 KB | 1 | 🟡 ORTA |
| `deneme.dart` | 2.0 KB | **TAMAMEN ÖLÜ KOD** | 🔴 (silinmeli) |

---

## 1. Haberleşme & Threading

### 1.1. KRİTİK BULGU: WebSocket Aslında Hiç Kullanılmıyor

`pubspec.yaml` içinde `web_socket_channel: ^2.4.0` deklare edilmiş ve `controller_page.dart` dosyasında **iki kez import edilmiş** olmasına rağmen, projede **WebSocket bağlantısı hiçbir yerde açılmamış**:

```19:20:lib/controller_page.dart
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
```

- Tüm haberleşme **HTTP GET polling** ile yapılıyor (`http.get(Uri.parse("$_site/..."))`).
- `WebSocketChannel.connect()`, `.sink`, `.stream` çağrısı **sıfır**.
- AGV gibi real-time bir sistem için bu, **mimari açıdan yanlış bir tercih**: her saniye 4 ayrı HTTP isteği + 200ms'de bir pose isteği = **dakikada ~540 HTTP request**.
- Bunun yanında WebSocket'in **bloklayıcı stream listener**'ı olmadığı için UI thread bloklama sorunu da **yok** — ama bu bir avantaj değil, çünkü WebSocket hiç kurulmamış.

> **Sonuç:** Kullanıcının sorduğu "WebSocket UI thread'i bloklayan async/await/stream/Isolate hataları" **MEVCUT DEĞİL**, çünkü WebSocket'in kendisi mevcut değil. Ancak HTTP polling'in kendisi de aynı tipte problemleri yaratıyor (aşağıda 1.2 ve 1.3).

### 1.2. KRİTİK BULGU: Üstel Timer Sızıntısı (Exponential Timer Leak)

`controller_page.dart` içinde `chargingCheck()` fonksiyonu **`Timer.periodic` BAŞLATIYOR**, ama bu fonksiyon **dış bir `Timer.periodic` tarafından her saniye tekrar çağrılıyor**:

```73:86:lib/controller_page.dart
    Timer.periodic(const Duration(seconds: 1), (timer) async{
      await Future.delayed(const Duration(milliseconds: 100));
      imageCache.clearLiveImages(); 
      
      fetchQRData();
      await Future.delayed(const Duration(milliseconds: 10));
      fetchRfid();
      await Future.delayed(const Duration(milliseconds: 10));
      fetchSensorData();
      await Future.delayed(const Duration(milliseconds: 10));
      chargingCheck();    // ← HER SANİYE çağrılıyor
      await Future.delayed(const Duration(milliseconds: 10));
    });
```

```106:120:lib/controller_page.dart
  void chargingCheck() {
    Timer.periodic(const Duration(seconds: 1), (timer) async {  // ← HER ÇAĞRIDA YENİ TIMER!
      if(amper.isNotEmpty){
        if(double.parse(amper) >= 1.0){
          isCharging = "Şarj Doluyor";
        }
        ...
      }
    });
  }
```

Bu, **her saniye yeni bir `Timer.periodic` instance** ekliyor. Uygulama 10 dakika açık kalırsa **600 paralel timer** birikiyor; tümü `setState` çağırmayan ama `amper.isNotEmpty` kontrol eden zombiler hâline geliyor. Bu **bellek + CPU sızıntısının ana kaynağı**.

### 1.3. KRİTİK BULGU: Kapatılmamış Timer'lar (Memory Leak)

`_ControllerPageState.initState()` içinde **3 ayrı `Timer.periodic`** başlatılıyor ama **sadece 1'i `dispose()` içinde iptal ediliyor**:

| Konum | Timer | Değişkene atanmış mı? | Cancel ediliyor mu? |
|---|---|---|---|
| `controller_page.dart:72` | `_poseTimer` (200ms) | ✅ Evet | ✅ Evet |
| `controller_page.dart:73` | Anonim (1s, ana polling) | ❌ Hayır | ❌ Hayır |
| `controller_page.dart:89` | `startConnectionCheck` (1s) | ❌ Hayır | ❌ Hayır |
| `controller_page.dart:107` | `chargingCheck` (1s, üstel) | ❌ Hayır | ❌ Hayır |

`dispose()` metodu yetersiz:
```285:290:lib/controller_page.dart
  @override
  void dispose() {
    //_stopPythonServer();  // Python server'ı durdur
    super.dispose();
    _poseTimer?.cancel();
  } 
```

> ⚠️ Ek sorun: `super.dispose()` **`_poseTimer?.cancel()`'den ÖNCE** çağrılıyor. Dart konvansiyonunda `super.dispose()` **EN SON** çağrılmalı.

### 1.4. UI Thread Üzerinde Ağır İşler

`LiveMapFixedUrl._tick()` metodu (controller_page.dart:1729+) UI thread'de aşağıdaki **ağır operasyonları** yapıyor:

- HTML parse (regex tabanlı `_extractFirstImgSrc`, `_extractDataImageUrl`)
- `base64Decode` (potansiyel olarak büyük image bytes için)
- `jsonDecode + utf8.decode` (resp.bodyBytes üzerinde)
- `_sniffBinaryImage` (Uint8List sıralı tarama)
- `setState(() { _frame = bytes; })` doğrudan widget tree rebuild tetikliyor

Bu işlemler **Isolate veya `compute()` ile arka plana alınmamış**. 500ms periyot ile çalışan bu `_tick()`, büyük haritalarda **frame drop** ve **input gecikmesi** yaratır.

### 1.5. `startSendingData` Busy Loop

```225:232:lib/controller_page.dart
  void startSendingData(String command, Duration duration) async {
    final int endTime = DateTime.now().millisecondsSinceEpoch + duration.inMilliseconds;

    while (DateTime.now().millisecondsSinceEpoch < endTime) {
      veriBas(command);
      await Future.delayed(const Duration(milliseconds: 50)); // 0.1 saniye bekleyip tekrar gönder
    }
  }
```

500ms boyunca 20 ms'de bir komut atıyor → 10 HTTP request. `veriBas`'in `await`'i **yok**, yani fire-and-forget. Eş zamanlı HTTP request stack'i hızla doluyor; bağlantı kötüyse istek kuyruğu UI thread'i etkiliyor.

### 1.6. `dispose()` Bulunmayan/Eksik Widget'lar

| Widget | Sorun |
|---|---|
| `_ConnectionPageState` (connection_page.dart) | `_controller` (TextEditingController) hiç `dispose()` edilmiyor |
| `_ConnectButtonState` (connection_page.dart, map_page.dart) | `dispose()` metodu yok |
| `_PowerButtonState` (controller_page.dart:1214) | `dispose()` metodu yok |
| `_ControllerPageState` | `_controller`, `_focusNode` dispose edilmiyor |
| `_ParameterPageState` (parameter.dart:85) | Sadece `super.dispose()` çağrısı var, controller'lar dispose edilmiyor |
| `_TimerPageState` (timer.dart) | Timer cancel ediliyor ama widget unmount sonrası setState olabilir (mounted check yok) |

### 1.7. `await Future.delayed` Anti-Pattern

`controller_page.dart:74-84` ve `parameter.dart:154-220` arasında `await Future.delayed(const Duration(milliseconds: 100))` sıralı çağrıları sıkça görülüyor. Bu, gerçek bir senkronizasyon değil; sadece tahmini bekleme. Network gecikmelerine karşı **kırılgan** ve thread'i gereksiz yere blokluyor.

---

## 2. State Management & Memory

### 2.1. Mimari Karmaşa: 3 Farklı State Yaklaşımı Karışmış

| Yaklaşım | pubspec'te? | Kodda gerçekten kullanılıyor mu? |
|---|---|---|
| **Provider** (`ChangeNotifier`) | ✅ Var | ✅ `DataModel`, `ParameterModel` için aktif |
| **GetX** (`get` paketi) | ✅ Var | ❌ **Hiçbir dosyada import edilmiyor** |
| **setState** (vanilla) | (built-in) | ✅ Heryerde — controller_page'de **25** ayrı çağrı |

> **Sonuç:** GetX paketi **tamamen ölü dependency**. Provider doğru şekilde kullanılıyor ama setState ile karışık çalışıyor. Bu, "hem GetX hem Provider" mimari karmaşası **değil**; "kullanılmayan GetX + Provider + aşırı setState" kombinasyonu.

### 2.2. `Provider.of` Kullanım Hatası (Performans)

`controller_page.dart:294` içinde, `build` metodu içinde `listen: true` (default) olarak Provider dinleniyor:

```294:lib/controller_page.dart
    List<DataPoint> dataPoints = Provider.of<DataModel>(context).dataPoints;
```

`DataModel`'in herhangi bir değişikliği **dev `ControllerPage` ağacının tamamını rebuild ediyor**. Doğru kullanım: `context.select<DataModel, List<DataPoint>>((m) => m.dataPoints)` veya `Consumer<DataModel>` ile sadece ihtiyaç duyan widget'ı sarmak.

### 2.3. `parameterModel.loadParameters()` İki Kez Çağrılıyor

- `main.dart:25` içinde Provider create edilirken bir kez,
- `controller_page.dart:71` `initState`'inde tekrar.

Aynı `SharedPreferences` okuması iki kez yapılıyor → gereksiz I/O + `notifyListeners` çift atılıyor.

### 2.4. Bellek Sızıntısı Riskleri (Özet Tablo)

| Dosya | Satır | Risk | Açıklama |
|---|---|---|---|
| `controller_page.dart` | 46 | 🔴 | `TextEditingController _controller` — dispose YOK + kullanılmıyor |
| `controller_page.dart` | 54 | 🔴 | `FocusNode _focusNode` — dispose YOK |
| `controller_page.dart` | 73, 89, 107 | 🔴 | 3 Timer.periodic — cancel YOK + üstel artış |
| `connection_page.dart` | 14 | 🟠 | `TextEditingController` — dispose YOK |
| `qr_page.dart` | 18 | 🟠 | `TextEditingController` dialog içinde — leak (modal kapansa da GC bekler) |
| `parameter.dart` | 53–82 | 🟠 | `Future.microtask` içinde `setState` ama `mounted` check yok |
| `timer.dart` | 24 | 🟡 | `setState` öncesi `mounted` check yok |
| `data_page.dart` | 31 | 🟡 | `_fetchData` sonrası `mounted` check yok |
| `controller_page.dart` | 191–195, 219–221, 239–241 | 🟡 | `setState` sonrası `mounted` check yok (state unmount sonrası setState exception) |

### 2.5. Gereksiz `setState` Kullanımları

`controller_page.dart` içinde **25 ayrı `setState`** mevcut. Bunlardan birçoğu, Provider içinde tutulması gereken state'i lokal state olarak tutmaktan kaynaklanıyor:

- `sicaklik, voltage, amper, sonQR, rfid, currX, currY, currYaw, isCharging, qrVeri, _data, sensor` → hepsi bir **sensor service / sensor provider** içinde tutulup `Consumer` ile dinlenmeli.
- Şu anki haliyle her veri geldiğinde **tüm ekran** rebuild oluyor.

### 2.6. Global Mutable State (map_page.dart)

```832:835:lib/map_page.dart
int incrementThing = -1;
List<DataPoint> dataPoints = [];
List<DataPoint> lastDataPoints = [];
int qrDiff = 0;
```

Bu **top-level global değişkenler**, MapPage'den çıkıp tekrar girildiğinde **temizlenmiyor** → harita kalıntıları bir sonraki açılışa sızıyor. Test edilemez, race-condition'a açık.

### 2.7. Kapatılmamış Stream

Projede `StreamSubscription` veya `StreamController` **kullanılmıyor** — bu yönden temiz. Tek "stream-vari" yapı `Timer.periodic`'ler, onlar da yukarıda anlatıldığı gibi kapatılmıyor.

---

## 3. Desktop Responsive UI

### 3.1. KRİTİK BULGU: `flutter_screenutil` MOBİL designSize ile Yapılandırılmış

```40:43:lib/main.dart
    ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: false,
      builder: (context, child) {
```

`Size(390, 844)` = **iPhone 13 portrait** boyutu. Desktop pencere boyutu (örn. 1920×1080) ile bu referansa göre tüm `.w`, `.h`, `.r`, `.sp` değerleri **~5× büyüyor**. Yani:
- `fontSize: 4.sp` → desktop'ta `~20pt` görünür (tasarımcının kafasındaki "küçük" boyut)
- `width: 60.w` → desktop'ta `~300px`
- Pencere yeniden boyutlandırıldığında **`ScreenUtilInit.builder`** rebuild olmuyor (sadece ilk MediaQuery'i alıyor) → değerler **donuyor**.

> **Önemli:** Bunu çözmek için ya `flutter_screenutil` desktop için tamamen kaldırılmalı (LayoutBuilder + MediaQuery + Flexible/Expanded), ya da designSize masaüstü değerine çekilip pencere resize listener eklenmelidir.

### 3.2. `4.sp` ve `3.sp` Yazı Boyutları — Mantık Hatası

Tüm kodda `fontSize: 3.sp`, `4.sp`, `5.sp` yoğun. `ScreenUtil` mobil designSize ile bu değerler tipik telefon ekranında ~10–13pt'a karşılık geliyor. Desktop'ta pencere büyüdükçe yazılar da büyüyor — ama **garip oranlarla**. Tasarım dili **piksel-bağımsız** değil.

### 3.3. Hardcoded Piksel ve `sp` Karışımı

Karışık birim kullanımı (controller_page.dart):

```557:559:lib/controller_page.dart
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
```
Burada `sp` değil, sabit `13` kullanılmış. Ama yanındaki widget'lar `.sp` kullanıyor → **tutarsız ölçeklenme**.

`Slider` etrafına `FittedBox(fit: BoxFit.fill)` sarılarak boyut zorlanmış (controller_page.dart:565). Bu, slider thumb'ının boyutsuz/orantısız büyümesine yol açar — desktop'ta dokunmatik gibi davranır.

### 3.4. Overflow Riskine Açık Widget'lar

| Konum | Sorun |
|---|---|
| `controller_page.dart` (sensör kartları, satır 600+) | `Row` içinde 2 `SizedBox(width: 60.w, height: 80.h)` Card → pencere daralırsa overflow. Expanded yok. |
| `controller_page.dart:614–650` arası nested `SizedBox > Card > Center > Row > Column > Center > Text` zinciri — Flexible/Expanded yok |
| `data_page.dart:62–276` | 8 PIN kartı tek `Row` içinde sıralı, sabit `width: 30.w` — toplam ~240.w + boşluklar. Pencere küçükse taşma garantili |
| `map_page.dart:298–353` | `SizedBox(width: 250.w, height: 610.h)` içinde `GridView` ile 29 kolon — desktop'ta veya küçük pencerede 29 hücrenin her biri yaklaşık 8 piksele iniyor → gridler basılamaz hale geliyor |
| `vehicle_3d_page.dart:29–112` | Tüm sayfa `Row > [Column, Column]` ama her ikisi de `Expanded` değil. PropertyCard'ların `Row`'u (3 tane yan yana) `Expanded` olmadığı için pencere daralırsa overflow |
| `parameter.dart:120–...` | Onlarca `TextField` `SizedBox(width: 60.w, height: 50.h)` ile sarılı, parent Row'da Expanded yok |
| `scenerio_page.dart:184` | `Wrap` kullanılmış (iyi), ama `SizedBox(width: 50.w, height: 100.h)` ile butonlar sabit boyutta — Wrap için zaten gerek yok |

### 3.5. AppBar `actions` Bölümü `Spacer` ile Doldurulmuş

```306:384:lib/controller_page.dart
          actions: [
            const Spacer(),
            TextButton(... "BAĞLANTI" ...),
            const Spacer(),
            ...
          ]
```

7 `TextButton` arasına 8 `Spacer` konmuş. `Spacer` `Row`'un esnek olmasını gerektirir. Geniş pencerede çok dağılıyor, dar pencerede **butonlar taşıyor ve kesiliyor**. Doğru çözüm: `Wrap` veya `Row + Flexible`.

### 3.6. Sabit `kPixelsPerMeter`, `kOriginPx`

Harita render kalibrasyon sabitleri (controller_page.dart:295–299 **ve** 1656–1659'da **çift kopya**):
```dart
const Offset kOriginPx = Offset(120.0, 420.0);
const double kPixelsPerMeter = 20.0;
```
Pencere yeniden boyutlandığında **araç ikonunun hizalaması bozulur** çünkü `kPixelsPerMeter` haritanın gerçek pixel boyutuna oransal değil, sabit.

---

## 4. Clean Code

### 4.1. Tamamen Ölü Dosyalar

| Dosya | Durum |
|---|---|
| `lib/deneme.dart` | Tüm içerik **commented-out Arduino C kodu**. Hiçbir yerden import edilmiyor. **SILINMELI**. |

### 4.2. Tamamen Ölü Sınıflar (Dosya İçinde)

| Konum | Sınıf | Durum |
|---|---|---|
| `controller_page.dart:1578–1652` | `LiveMapImage` ve `_LiveMapImageState` | **Komple yorum bloğu** içinde (`/* ... */`) |

### 4.3. Kullanılmayan Import'lar

| Dosya | Satır | Import | Kullanım |
|---|---|---|---|
| `controller_page.dart` | 15 | `path_provider` | Hiç |
| `controller_page.dart` | 16 | `process_run/shell.dart` | `var shell = Shell();` (55. satır) — sadece tanımlanmış, hiç kullanılmamış |
| `controller_page.dart` | 17 | `dart:ui as ui` | Hiç (`ui.` prefix'i hiçbir yerde yok) |
| `controller_page.dart` | 18 | `flutter/scheduler.dart` | Sadece yorum bloğu içindeki ölü kodda |
| `controller_page.dart` | 19, 20 | `web_socket_channel/*` | **Hiç** (yukarıda 1.1) |
| `data_page.dart` | 4 | `dart:convert` | Hiç |
| `map_page.dart` | 1, 6 | `data_model.dart` (**iki kez!**) | Tek seferi yeterli |

### 4.4. Kullanılmayan State Değişkenleri (controller_page.dart)

| Satır | Değişken | Sorun |
|---|---|---|
| 33 | `String yukKutle = ""` | Asla atanmıyor, asla okunmuyor |
| 34 | `String voltage = ""` | Atanıyor (211. satır) ama UI'da hardcoded `"12.8"` gösteriliyor (881. satır) |
| 35 | `String amper = ""` | Atanıyor (212. satır) ama UI'da `""` gösteriliyor (833. satır) |
| 41 | `int actionTime = 10` | Hiç kullanılmıyor |
| 45 | `String _data = 'Veri yükleniyor...'` | Atanıyor ama hiçbir Text widget'ına bağlanmamış |
| 46 | `TextEditingController _controller` | Hiç kullanılmıyor (kontroller bir TextField'a bağlı değil) |
| 47 | `String bas = "C"` | Hiç kullanılmıyor |
| 48 | `String bit = "A"` | Hiç kullanılmıyor |
| 49 | `List<dynamic> qrVeri = [0]` | Sadece **yorumdaki** ölü `fetchQRData`'da |

### 4.5. Kullanılmayan Dependency'ler (pubspec.yaml)

| Paket | pubspec | Kullanım |
|---|---|---|
| `dio: ^4.0.0` | ✅ | `import 'package:dio'` **hiçbir yerde yok** |
| `get: ^4.6.5` (GetX) | ✅ | **Hiç import yok** |
| `cupertino_icons: ^1.0.6` | ✅ | `CupertinoIcons.` çağrısı yok |
| `fluentui_system_icons: ^1.1.230` | ✅ | Hiç import yok |
| `font_awesome_flutter: ^10.7.0` | ✅ | Hiç import yok |
| `web_socket_channel: ^2.4.0` | ✅ | Sadece import edilmiş, kullanılmamış |
| `path_provider: ^2.0.13` | ✅ | Sadece import edilmiş, kullanılmamış |
| `process_run: ^0.12.0` | ✅ | `Shell()` tanımlanmış ama hiç metot çağrılmamış |

> Yaklaşık **8 ölü dependency** var. Bunlar:
> - APK/EXE boyutunu şişiriyor,
> - `flutter pub get` süresini uzatıyor,
> - Güvenlik denetiminde gereksiz attack surface yaratıyor.

### 4.6. Gereksiz Sarılmış (Wrapped) Widget'lar

Tipik anti-pattern örnekleri:

- **`Center > Column > Center > Text`** (controller_page.dart:629–637 ve onlarca yerde): Column'un tek child'ı Text'i Center'a sarmak gereksiz.
- **`Card > SizedBox > Card`** zincirleri (controller_page.dart sensör kartlarında her biri).
- **`Row > [Column, Column]`** ama her Column'da tek widget var (controller_page.dart:619–649).
- **`Row > SizedBox(width: 50.w) > Text`** içinde SizedBox yerine `Padding` daha okunaklı olurdu.
- **`Padding > Padding`** (vehicle_3d_page.dart:37–44).
- **vehicle_3d_page.dart:160**: `SizedBox(width: 50.w)` bir `Column` içinde — bu **yataya değil dikeye** boşluk ekleyemez; muhtemelen `height` yazılmak istenmiş.

### 4.7. Dead Code Blokları (Commented Out)

| Konum | İçerik |
|---|---|
| `controller_page.dart:122–151` | Eski `fetchQRData` implementasyonu |
| `controller_page.dart:494–496` | Senaryo navigate sonrası eski if bloğu |
| `controller_page.dart:1577–1652` | Tüm `LiveMapImage` sınıfı |
| `connection_page.dart:62–67` | Eski `ElevatedButton` |
| `connection_page.dart:94–98` | Eski `Future.delayed` reset bloğu |
| `map_page.dart:78–95` | Eski road widget listeleri |
| `map_page.dart:188–194` | Eski `gridWidgets` initialization |

### 4.8. Tekrar Eden Kod (DRY İhlali)

- **27 adet özdeş `void updateXxx(String newValue)`** parameter_model.dart:131–282 → 1 generic metod ile çözülebilir.
- **27 adet özdeş `prefs.setString/getString`** parameter_model.dart:67–127 → loop ile yapılabilir.
- **8 adet özdeş PIN-kartı Container** data_page.dart:74–276 → `List.generate` ile tek bir builder yeterli.
- **AppBar TextButton'ları** controller_page.dart:306–384 → bir liste + map → widget.
- Map sayfasındaki **40+ özdeş Draggable** map_page.dart:420–800+ arası → veri-driven (List + builder) hâle getirilebilir.

### 4.9. Genel Stil Problemleri

- `controller_page.dart` **1984 satır** — God file. En az 5 dosyaya bölünmeli:
  - `controller_page.dart` (sadece widget tree)
  - `agv_service.dart` (HTTP çağrıları)
  - `agv_state.dart` (state model)
  - `live_map_widget.dart` (LiveMapFixedUrl)
  - `control_buttons.dart` (PowerButton, NormalButton, ControlButton, QRButton)
- `import` sıralaması rastgele (proje dosyaları arasında `package:` import'ları karışık).
- `print()` çağrıları üretim kodunda var (controller_page.dart:274, 1921; map_page.dart birden fazla; data_page.dart:40 vb.).
- `var` ve explicit type karışık (örn. `final TextEditingController _controller = TextEditingController();` ve hemen sonra `var dataPoints = ...`).

### 4.10. Olası Bug

- `controller_page.dart:163, 176`: `Future<void>` döndüren bir fonksiyon içinde `return null;` — derleyici lint uyarısı veriyor olmalı.
- `controller_page.dart:192–193`: `currX = y*10; currY = x*10;` — **x ile y yer değiştirilmiş**, kasıtlı mı yoksa hata mı belirsiz, yorumda açıklama yok.
- `controller_page.dart:1861`: `List.generate(8, (i) => data[i]).every((b) => b == png[data.indexOf(b)])` — `data.indexOf(b)` ilk eşleşmeyi döndürür, sıra kontrolünü **doğru yapmaz**. PNG sniffer **bozuk**.

---

## Genel Skor Kartı (Başlangıç — Mayıs 2026)

| Kategori | Skor | Açıklama |
|---|---|---|
| Haberleşme & Threading | 🔴 2/10 | Timer sızıntıları, üstel artış, HTTP polling, WS hiç kullanılmamış |
| State Management | 🟠 4/10 | Provider doğru, ama setState bağımlılığı + ölü GetX + global state |
| Desktop Responsive | 🔴 2/10 | Mobil designSize, hardcoded px, overflow garantili |
| Clean Code | 🟠 3/10 | 8 ölü dependency, 1984-satır god file, ölü kod blokları, kullanılmayan state |

> **Sonuç:** Proje çalışır durumda olabilir, ama **kararsız, sızıntılı ve desktop için uygunsuz** durumda.

---

## Faz 3 Sonrası Durum Raporu (Haziran 2026)

> Faz 3.1–3.11 + Uyarı düzeltmeleri tamamlandı. `flutter analyze` → **0 sorun**.

### Yapılan / Yapılmayan Özeti

| # | Bulgu | Durum | Notlar |
|---|---|---|---|
| **1. Haberleşme & Threading** | | | |
| 1.1 | WebSocket hiç kullanılmıyor | ⏭️ Mimari karar | HTTP polling AGV için yeterli kabul edildi |
| 1.2 | Üstel Timer Sızıntısı (chargingCheck) | ✅ Düzeltildi | `chargingCheck` kaldırıldı; `AgvSensorModel` içine taşındı |
| 1.3 | Kapatılmamış Timer'lar | ✅ Düzeltildi | 3 timer değişkene atandı, `dispose()` içinde iptal ediliyor; `super.dispose()` en sona alındı |
| 1.4 | UI thread'de ağır işler (`_tick`) | ❌ Kaldı | `LiveMapFixedUrl._tick()` hâlâ base64/JSON decode UI thread'de yapıyor |
| 1.5 | `startSendingData` busy loop | ✅ Kısmen | `AgvService`'e taşındı; loop mantığı aynı ama merkezi |
| 1.6 | `dispose()` eksiklikleri | ✅ Düzeltildi | `_focusNode`, 3 timer, `TextEditingController` hepsi dispose ediliyor; `mounted` check'ler eklendi |
| 1.7 | `await Future.delayed` anti-pattern | ❌ Kaldı | Polling timer'larında hâlâ var |
| **2. State Management** | | | |
| 2.1 | 3 farklı state yaklaşımı | ✅ İyileşti | GetX zaten kullanılmıyordu; `AgvSensorModel` eklendi; setState azaldı |
| 2.2 | `Provider.of` / rebuild sorunu | ✅ Düzeltildi | `context.watch<>()` kullanımına geçildi |
| 2.3 | `loadParameters()` iki kez çağrılıyor | ❌ Kaldı | `initState` hâlâ `parameterModel.loadParameters()` çağırıyor |
| 2.4 | Bellek sızıntısı riskleri | ✅ Büyük ölçüde | Timer'lar, FocusNode, mounted check'ler tamamlandı |
| 2.5 | Aşırı `setState` | ✅ Önemli ölçüde azaltıldı | Sensör verisi `AgvSensorModel`'a taşındı |
| 2.6 | Global mutable state (`map_page`) | ✅ Düzeltildi | Top-level değişkenler instance field'a dönüştürüldü |
| 2.7 | Kapatılmamış stream | ✅ Yok | Sorun baştan da yoktu |
| **3. Desktop Responsive UI** | | | |
| 3.1 | `screenutil` mobil designSize | ⏭️ Kapsam dışı | Kullanıcı talebiyle bu fazda ele alınmadı |
| 3.2 | `3.sp / 4.sp` yazı boyutları | ⏭️ Kapsam dışı | screenutil'e bağlı |
| 3.3 | Hardcoded px + sp karışımı | ❌ Kaldı | screenutil kapsam dışında ama karışık birim kullanımı devam ediyor |
| 3.4 | Overflow riskli widget'lar | ❌ Kaldı | `Row`/`SizedBox` overflow riski, `Flexible`/`Expanded` eksik |
| 3.5 | AppBar `Spacer` sorunu | ❌ Kaldı | 8 `Spacer`, dar pencerede butonlar kesiliyor |
| 3.6 | `kPixelsPerMeter` sabit | ❌ Kaldı | Harita kalibrasyonu pencere boyutuna duyarsız |
| **4. Clean Code** | | | |
| 4.1 | `deneme.dart` ölü dosya | ✅ Silindi | Dosya kaldırıldı |
| 4.2 | `LiveMapImage` ölü sınıf | ✅ Silindi | Yorum bloğu tamamen kaldırıldı |
| 4.3 | Kullanılmayan import'lar | ✅ Düzeltildi | `web_socket_channel`, `path_provider`, `dart:ui`, `scheduler` vb. hepsi kaldırıldı |
| 4.4 | Kullanılmayan state değişkenleri | ✅ Büyük ölçüde | Sensör alanları `AgvSensorModel`'a, `_data` silindi; `bas`, `bit`, `qrVeri`, `actionTime` hâlâ kalıyor |
| 4.5 | Ölü dependency'ler (pubspec) | ✅ Düzeltildi | `dio`, `get`, `cupertino_icons`, `fluentui`, `font_awesome`, `web_socket_channel`, `path_provider`, `process_run` — hepsi kaldırıldı (8 → 4 paket) |
| 4.6 | Gereksiz sarılmış widget'lar | ✅ Düzeltildi | `Center`, `Card(transparent)` zincirleri sadeleştirildi |
| 4.7 | Dead code blokları | ✅ Düzeltildi | Tüm yorum blokları kaldırıldı |
| 4.8 | DRY ihlalleri | ✅ Kısmen | `ParameterModel` birleştirildi, god file bölündü; AppBar butonları, PIN kartları, harita Draggable'ları hâlâ tekrar ediyor |
| 4.9 | Stil sorunları | ✅ Büyük ölçüde | `print` → `debugPrint`, import temizliği, god file ayrıştırıldı |
| 4.10 | PNG sniffer bug | ✅ Düzeltildi | `data.indexOf(b)` → `png[i]` olarak düzeltildi |

---

## Güncel Genel Skor Kartı (Haziran 2026)

| Kategori | Başlangıç | Güncel | Değişim | Açıklama |
|---|---|---|---|---|
| Haberleşme & Threading | 🔴 2/10 | 🟡 6/10 | ▲ +4 | Kritik timer sızıntıları ve dispose sorunları giderildi; `_tick()` UI thread sorunu ve `Future.delayed` anti-pattern kaldı |
| State Management | 🟠 4/10 | 🟢 8/10 | ▲ +4 | `AgvSensorModel` eklendi, global state kaldırıldı, `context.watch` kullanıldı; yalnızca `loadParameters` çift çağrı küçük sorun olarak kaldı |
| Desktop Responsive | 🔴 2/10 | 🔴 2/10 | — | screenutil kapsam dışı; overflow riskleri, AppBar Spacer ve hardcoded değerler dokunulmadı |
| Clean Code | 🟠 3/10 | 🟢 9/10 | ▲ +6 | 8 ölü paket silindi, god file bölündü, dead code temizlendi, `flutter analyze` 0 sorun; 4 ufak kullanılmayan değişken kaldı |

### Genel Ortalama

| | Başlangıç | Güncel |
|---|---|---|
| **Ortalama Skor** | **2.75 / 10** | **6.25 / 10** |

### Kalan Açık Maddeler (screenutil hariç)

| Öncelik | Madde | Dosya |
|---|---|---|
| 🟠 Orta | `_tick()` metodu UI thread'de ağır I/O | `widgets/live_map.dart` |
| 🟠 Orta | Overflow riskleri (`Row` + `SizedBox`, `Flexible` eksik) | `controller_page`, `data_page`, `vehicle_3d_page` |
| 🟡 Düşük | `loadParameters()` iki kez çağrılıyor | `controller_page.dart:52` |
| 🟡 Düşük | `AppBar actions` içinde `Spacer` (dar pencerede taşma) | `controller_page.dart:147+` |
| 🟡 Düşük | 4 kullanılmayan alan: `actionTime`, `bas`, `bit`, `qrVeri` | `controller_page.dart:29–35` |
| 🟡 Düşük | `await Future.delayed` anti-pattern (polling timer'larında) | `controller_page.dart:64–84` |
| 🟡 Düşük | `kPixelsPerMeter` sabit, pencere boyutuna duyarsız | `widgets/live_map.dart` |
