# MarCO GCS — Saha Haritalama / Lokalizasyon / İstasyon / Rota Yol Haritası

> **Amaç:** Orange Pi ROS 2 tarafındaki yeni mapping–preview–fields sözleşmesine Flutter GCS’i bağlamak.  
> **Kaynak istek:** PC GUI’de saha adı, harita oluştur/bitir, PNG önizleme, robot pikseli, manuel sürüş kapısı, kayıtlı sahalar, lokalizasyon, dokunarak nokta ekleme, rota düzenleme.  
> **Kural:** Topic/servis adları widget içine yazılmaz; tek sabit dosyada tutulur.  
> **Doğrulama:** Her faz sonrası `flutter analyze` + mümkünse ROS’lu manuel sanity check.  
> **Not:** Eski `execution_plan.md` (Faz 0–1 stabilite) ile karışmaz. Bu dosya yalnızca yeni haritalama ürün akışıdır.

---

## Mimari özet (hedef)

```text
[Flutter GCS]
    │  ws://IP:9090  (rosbridge JSON)
    ▼
[Orange Pi ROS 2]
    ├── /mapping/start|stop|save|status
    ├── /map_preview/compressed|metadata|robot_pixel
    ├── /cmd_vel_manual
    ├── /fields/list
    ├── /localization/start|stop
    └── /stations/*  /routes/*
```

### Mapping durum makinesi (ROS `/mapping/status`)

| Kod | Anlam | UI |
|-----|--------|-----|
| 0 | IDLE / hazır | Harita Oluştur aktif |
| 1 | STARTING | Butonlar kilitli, yükleniyor |
| 2 | MAPPING | Joystick + Bitir/Kaydet aktif |
| 3 | STOPPING | Butonlar kilitli |
| 4 | ERROR | Hata + yeniden dene |
| 5 | SAVING | Butonlar kilitli, kayıt sürüyor |
| 6 | SAVED | Kayıt tamamlandı |

Manuel sürüş mapping durumundan bağımsızdır. Operatör GCS'teki
**Manuel/Otonom** anahtarıyla açıp kapatır; ROS bağlantısı yokken komut
gönderilmez.

---

## Mevcut altyapı (bu işe temel)

Aşağıdakiler projede **zaten var**; yeni işte yeniden yazılmayacak, üzerine kurulacak.

### Hazır olanlar
- [x] `ws://<IP>:9090` rosbridge WebSocket bağlantısı (`RosBridgeClient`)
- [x] Bağlantı kopunca otomatik yeniden bağlanma (backoff)
- [x] Bağlantı durumu AppBar / bağlantı panelinde gösterimi
- [x] `/cmd_vel_manual` advertise + Twist publish + heartbeat + `stopManual()`
- [x] Bağlantı kopunca / disconnect’te sıfır hız gönderimi
- [x] Ana ekranda WASD/QE manuel kontrol butonları (mevcut GCS)
- [x] Eski `/map` OccupancyGrid aboneliği + metadata modeli (`OccupancyGridMetadata`)
- [x] Eski grid tabanlı `map_page.dart` / senaryo rotası (2025 tarzı; yeni PNG preview akışından **ayrı** tutulacak)

### Bu planda değiştirilecek / yeni eklenecekler
- [ ] Mapping / preview / fields / localization / stations / routes sözleşmesi
- [ ] PNG `Image.memory` harita ekranı + robot pixel overlay
- [ ] Mapping durum makinesi ile buton/joystick kapıları
- [ ] Saha adı validasyonu + kayıtlı sahalar ekranı
- [ ] Dokunarak istasyon + rota UI (ROS servisleri sonra bağlanacak)

### PNG nereye gelecek? (net karar)

**Evet — PNG’ler mevcut ana GCS orta alandaki HARİTA sekmesine gelecek.**

Şu an gördüğün placeholder:

- Sekme: `HARİTA` / `KAMERA` / `LiDAR` / `3D`
- Metin: `ROS /map metadata bekleniyor...`

Bu alan `controller_page.dart` → `_buildWorkAreaContent` (sekme 0).  
Hedef: buradaki eski OccupancyGrid / “metadata bekleniyor” görünümünün yerine (veya öncelikli olarak) **`/map_preview/compressed` PNG + robot ikonu** gelsin.

| Kaynak | Eski (şu an) | Yeni (bu plan) |
|--------|----------------|----------------|
| Topic | `/map` OccupancyGrid | `/map_preview/compressed` (PNG) |
| Meta | `/map` info | `/map_preview/metadata` |
| Robot | pose → grid dönüşümü | `/map_preview/robot_pixel` |
| Gösterim yeri | Ana ekran **HARİTA** sekmesi | **Aynı HARİTA sekmesi** |

- Üst menüdeki ayrı **HARİTA** sayfası (`map_page.dart` grid editör) farklı kalır (nokta çizme editörü).
- “Kayıtlı Haritalar” ayrı liste ekranı olabilir; **canlı önizleme ana HARİTA sekmesindedir.**

---

## 🔵 Faz A — ROS sözleşme sabitleri ve istemci iskeleti

> Widget’lara topic adı yazılmadan önce tek kaynak oluştur.

### A.1 — Sabit dosya
- [x] `lib/services/ros_mapping_contract.dart` oluşturuldu.
- [x] Çalışan bağlantılar:
  - [x] `/mapping/start` → `marco_msgs/srv/StartMapping`
  - [x] `/mapping/stop` → `std_srvs/srv/Trigger` (ROS ile teyit notu var)
  - [x] `/mapping/status`
  - [x] `/map_preview/compressed`
  - [x] `/map_preview/metadata`
  - [x] `/map_preview/robot_pixel`
  - [x] `/cmd_vel_manual` → `geometry_msgs/msg/Twist` (+ client bu sabiti kullanıyor)
- [x] Yakında eklenecek bağlantılar (isimler hazır, çağrı stub):
  - [x] `/mapping/save`
  - [x] `/fields/list`
  - [x] `/localization/start`
  - [x] `/localization/stop`
  - [x] `/stations/add|update|delete|list`
  - [x] `/routes/save|list|delete`
- [x] Mapping status enum: `0..6` → `idle|starting|mapping|stopping|error|saving|saved`
- [x] Bilinen hata mesajı sabitleri / eşleme tablosu (`RosMappingErrors.toUserMessage`)
- [x] Bonus: saha adı kuralları, manuel hız limitleri, `FieldNodeType`, `MapPreviewSource`

### A.2 — `RosBridgeClient` genişletmesi
- [x] Mapping/preview topic’lerine `subscribe` ekle (bağlantı kurulunca).
- [x] Callback’ler: `onMappingStatus`, `onMapPreviewImage`, `onMapPreviewMetadata`, `onMapPreviewRobotPixel`.
- [x] Servis sarmalayıcıları:
  - [x] `startMapping({required String fieldName})`
  - [x] `stopMapping()`
  - [x] `saveMapping(...)` — stub hazır (servis yokken yükleniyor UI destekli)
  - [x] `listFields()` — stub
  - [x] `startLocalization(...)` / `stopLocalization()` — stub
- [x] Mevcut `/robot_status`, `/mission/*`, eski `/map` aboneliklerini bozma (geçiş döneminde yan yana kalabilir).
- [x] `AgvService` üzerinden ince facade ekle.
- [x] Geçici kopmada mapping preview `null` ile silinmez (last-good); `onMappingSubscriptionsReady` ile reconnect yenileme sinyali.

### A.3 — Sanity
- [x] `flutter analyze` temiz.
- [x] Widget içinde ham topic string yok (`rg "/mapping/" lib/widgets lib/**/*_page.dart` kontrolü).

---

## 🟢 Faz B — Bağlantı UX + Saha adı + Mapping başlat

### B.1 — Bağlantı durumu (görünürlük) + last-good harita
- [x] Temel bağlantı durumu zaten var.
- [x] Haritalama / HARİTA alanında net durum şeridi: Bağlı / Bağlanıyor / Kopuk / Hata.
- [x] **Kopunca haritayı ve mapping status’unu ERROR’a çekme / silme yok.**
  - Son gelen PNG + metadata (+ mümkünse robot pikseli) ekranda **last-good** olarak kalır.
  - Mapping status “eski / stale” tutulur; kopmayı status=ERROR ile karıştırma.
  - Kopukken start/stop/save ve manuel sürüş **komutları kilitli** (`commandsLocked`).
  - Acil manuel kontrol mobilden / başka istemciden yapılabilir; PC GCS eski haritayı tutmaya devam eder.
- [x] **Reconnect sonrası harita yenilemesi (zorunlu):**
  - Yeniden bağlanınca mapping/preview topic’leri tekrar subscribe edilir.
  - UI `awaitingFreshPreview` bayrağı açar; last-good görüntü durur.
  - İlk yeni preview / OccupancyGrid gelince bayrak iner, görüntü **üzerine yazılır**.
  - Reconnect sonrası eski frame’i “canlı” sanma; taze frame gelene kadar şeritte
    “Bağlandı — harita güncelleniyor…” ifadesi.
  - Client kopunca preview/occupancy callback’lerini `null` ile silmez (yalnız yeni adres `connect`).
  - `GcsMappingModel` + `MappingConnectionBanner` eklendi.

### B.2 — Saha adı alanı
- [x] TextField: “Saha adı”.
- [x] Validator: yalnız `[A-Za-z0-9_-]+` (Türkçe karakter / boşluk yok) — `RosFieldNameRules`.
- [x] Örnek placeholder: `saha_01`.
- [x] Geçersizken “Harita Oluştur” pasif (`MappingFieldBar` + `GcsMappingModel.fieldName`).

### B.3 — Harita Oluştur
- [x] Buton → `/mapping/start` (`field_name: <saha_adı>`).
- [x] Cevap `accepted/message` kullanıcıya gösterilsin (olay günlüğü + `RosMappingErrors`).
- [x] Status 1 (STARTING) gelene kadar / gelince butonlar kilitlensin (`startInFlight` + `uiLocked`).
- [x] ROS bağlı değilken buton pasif (`canStartMapping`).

### B.4 — `/mapping/status` dinleme
- [x] Status kodunu merkezi state’e yaz (`GcsMappingModel`).
- [x] ROS `message` alanını ekranda göster (status chip + banner).
- [x] Kopukken status’u ERROR’a zorlama; komut kapıları `isConnected` / `liveMappingStatus` ile AND’lenir.
- [x] Buton durum makinesi (yalnız **bağlıyken** geçerli):
  - [x] IDLE → Harita Oluştur aktif
  - [x] STARTING → kilit + loading
  - [x] MAPPING → Joystick + Bitir/Kaydet aktif
  - [x] STOPPING → kilit
  - [x] ERROR → hata + Yeniden Dene

---

## 🟡 Faz C — Harita önizleme (PNG) + robot pikseli + metadata

> **Gösterim yeri (zorunlu):** Ana takip ekranı → orta çalışma alanı → **HARİTA** sekmesi  
> (`controller_page.dart` / `_buildWorkAreaContent`, sekme indeksi 0).  
> Ayrı tam sayfa “Saha Haritalama” zorunlu değil; canlı PNG buraya bağlanır.

### C.0 — Mevcut HARİTA sekmesine bağla
- [x] `_buildWorkAreaContent` → preview varsa `MapPreviewStage`, yoksa boş durum / OccupancyGrid fallback.
- [x] Preview yokken: “Harita önizlemesi bekleniyor…” + IDLE yönlendirme.
- [x] Kopukken last-good PNG + bağlantı şeridi.
- [x] Eski OccupancyGrid geçici fallback; öncelik PNG preview.

### C.1 — `/map_preview/compressed`
- [x] PNG byte/base64 çözümü (`RosCompressedImageCodec` + client).
- [x] `Image.memory(..., gaplessPlayback: true)` HARİTA sekmesinde.
- [x] Yeni mesajda güncelleme; reconnect’te taze frame.
- [x] Geçici kopmada buffer silinmez.
- [x] Döndürme / aynalama yok.
- [x] `BoxFit.contain`.

### C.2 — `/map_preview/metadata`
- [x] `MapPreviewMetadata` (width/height/resolution/origin/source).
- [x] Modelde saklanır; layout/robot için kaynak.

### C.3 — `/map_preview/robot_pixel`
- [x] Alanlar: `pixel_x/y`, `screen_yaw`, `inside_map` (+ `MapPixelPose` tip adı).
- [x] `inside_map == false` → ikon gizli + uyarı.
- [x] Yalnız ikon `screen_yaw` ile döner.
- [x] `mapPreviewLayout` ile contain scale/offset.

### C.4 — Ortak harita widget
- [x] `MapPreviewStage` (PNG + robot; overlay için hazır).
- [x] `source` bilgi etiketi.

---

## 🟠 Faz D — Manuel sürüş (operatör kontrollü)

### D.1 — Hız sorumluluğu
- [x] Hız büyüklüğü **STM32** tarafında sınırlanır; GCS m/s–rad/s clamp etmez.
- [x] GCS yalnızca yön/ölçek komutu yayınlar (`/cmd_vel_manual`, −1…+1);
      `RosManualDriveLimits` + slider kademesi; güvenli tavan firmware’de.

### D.2 — Joystick / WASD
- [x] Ana GCS `ControlButton` WASD (HARİTA ile aynı sayfa).
- [x] Topic: yalnız `/cmd_vel_manual`.
- [x] Basılıyken heartbeat ~10 Hz (`RosManualDriveLimits.heartbeatDefaultMs = 100`).
- [x] Bırakınca `stopManual` → sıfır Twist (parmak + KeyUp).
- [x] Sayfa `dispose`, app lifecycle pause/inactive/detached/hidden, ROS disconnect → sıfır hız.
  - [x] Disconnect’te `stopManual` mevcut.
  - [x] `WidgetsBindingObserver` + Manuel’den Otonom’a geçince `stopManual`.

### D.3 — Operatör kontrolü
- [x] Mapping status (`IDLE/STARTING/MAPPING/STOPPING/ERROR`) joystick'i kilitlemez.
- [x] Fiziksel anahtar yok: Manuel/Otonom GCS Switch ile seçilir; ROS `manual_mode_enabled` override etmez.
- [x] Sürüş koşulu: GCS Manuel **ve** ROS bağlı.

---

## 🔴 Faz E — Haritalamayı bitir / kaydet + saha listesi

### E.1 — Bitir ve Kaydet
- [x] Buton: “Haritalamayı Bitir ve Kaydet”.
- [x] SLAM çalışırken doğrudan `/mapping/save` (`{}`) çağır; başarılı yanıttan sonra `SAVED=6` durumunu bekle.
- [x] `/mapping/stop` yalnız “Kaydetmeden İptal Et” işlemi için kullanılır.
- [x] Servis yokken: loading + “ROS hazır değil veya servis yanıt vermedi”.
- [x] Başarı → `/fields/list` ile saha listesi yenilenir (`SavedFieldInfo`).

### Faz E — değişen dosyalar (takip)
> E bitince sorulacak liste; E ilerledikçe güncellenir.
- `lib/controller_page.dart`
- `lib/models/gcs_mapping_model.dart`
- `lib/widgets/mapping_field_bar.dart`
- `lib/services/ros_bridge_client.dart`
- `lib/services/agv_service.dart`
- `lib/saved_fields_page.dart` *(yeni)*
- `lib/main.dart`
- `analysis/execution_planiki.md`

### E.2 — Kayıtlı Haritalar ekranı
- [x] Yeni sayfa: “Kayıtlı Haritalar” (`saved_fields_page` + AppBar nav).
- [x] `/fields/list` ile doldurulur (boş / hata / kart grid).
- [x] Kart alanları:
  - [x] saha adı
  - [x] harita önizlemesi (thumbnail veya placeholder)
  - [x] oluşturulma tarihi
  - [x] hazır / hatalı durumu

### E.3 — Haritayı Yükle → lokalizasyon
- [x] Kartta “Haritayı Yükle” butonu.
- [x] `/localization/start` çağrısı (servis yoksa “ROS hazır değil”).
- [x] Aynı `MapPreviewStage`; aktif lokalizasyonda etiket `amcl` (`previewSourceLabel`).
- [x] `/localization/stop` (AppBar “Lokalizasyonu Durdur”).

---

## 🟣 Faz F — Düğüm sayfası (robot konumundan öğretme)  ★ şartname akışı

> Şartnamedeki “robotu gezdirerek nokta tanımla” senaryosu.  
> Kullanıcı robotu (manuel) alma/bırakma/başlangıç noktasına götürür → **Yeni düğüm oluştur** → ad + tür seçer → düğüm **o anki robot konumuna** basılır.  
> Görsel olarak sağ üstteki eski **HARİTA** (`map_page.dart`) editörüne benzer ihtiyaç; **ama 0’dan yeni sayfa**.  
> **`map_page.dart` ve grid editör kodları silinmeyecek** (yedek / referans kalır; menüden ayrı tutulur).

### F.0 — Sayfa iskeleti
- [x] Yeni sayfa: `lib/node_teach_page.dart`.
- [x] Ana GCS nav: **“DÜĞÜMLER”** (eski HARİTA grid editöründen ayrı).
- [x] Aynı `MapPreviewStage` (PNG + robot); lokalizasyon / preview yoksa placeholder.
- [x] Robot konumu: `GcsMappingModel.robotPixel` (`/map_preview/robot_pixel`) — dokunma ile basılmaz.
- [x] `inside_map == false` (veya robot yok) iken “Yeni düğüm oluştur” pasif + uyarı.

### Faz F — değişen dosyalar (takip)
> F bitince sorulacak liste; F ilerledikçe güncellenir.
- `lib/node_teach_page.dart` *(yeni)*
- `lib/models/gcs_node_model.dart` *(yeni)*
- `lib/widgets/map_preview_stage.dart`
- `lib/main.dart`
- `lib/controller_page.dart`
- `lib/scenerio_page.dart`
- `lib/map_page.dart` *(F.4 etiket; silinmedi)*
- `analysis/execution_planiki.md`

### F.1 — Yeni düğüm oluştur
- [x] Belirgin buton: **Yeni düğüm oluştur**.
- [x] Dialog / panel:
  - [x] **Ad** (kullanıcı yazar): örn. `A1`, `B3`, `S1`, `BASLANGIC`
  - [x] **Tür** (`FieldNodeType`: alma, bırakma, başlangıç, şarj, kapı, QR — bekleme yok).
  - [x] Ad validasyonu: harf/rakam/`_`/`-` (boşluk yok); benzersiz ad
- [x] Onayda kaydedilen alanlar:
  - `name`, `type`, `pixel_x`, `pixel_y`, `screen_yaw`, `field_name`
- [x] Harita overlay’de renkli marker + etiket (`MapPreviewNodeMarker`).

### F.2 — Liste / düzenle / sil
- [x] Sayfada sağ panel: öğretilmiş düğüm listesi.
- [x] Düzenle (ad/tür), sil, “konumu robota taşı”.
- [x] Yerel state (`GcsNodeModel` + `id`); ROS `/stations/*` sonra.

### F.3 — Senaryo oluşturma ile bağ
- [x] Öğretilmiş alma/bırakma düğümleri Senaryo ekranında seçilebilir.
- [x] Eski harita `alma_/birak_` listesinin **yanına** `GcsNodeModel` havuzu merge.
- [x] Tip filtreleri: alma → bırakma sırası (`_isAlma` / `_isBirak`, A/B prefix + tür).
- [x] `scenerio_page.dart` + Senaryo nav kapısı; legacy kırılmadan migrate.

### F.4 — Eski map_page ile ilişki
- [x] Karar: `map_page.dart` **silinmez**.
- [x] Yeni Düğümler sayfası (`node_teach_page`) grid editöre bağımlı değil.
- [x] Üst menü: **“HARİTA EDİTÖRÜ (ESKİ)”** → `map-page`; kod kalır (silinmedi).

### F.5 — Şartname uyumu (kısa)
- [x] Haritalama sonrası / lokalizasyon: bağlı + önizleme + robot `inside_map` iken öğretme; ipucu şartname akışını anlatır.
- [x] Türler: alma / bırakma / başlangıç / şarj / kapı / QR (`FieldNodeType`).
- [x] Alma/bırakma → Senaryo (F.3) + Düğümler AppBar **Senaryoya geç**.

---

## 🟪 Faz G — İstasyon noktaları (dokunarak) — tamamlayıcı

> Faz F = robot konumundan öğretme (birincil şartname akışı).  
> Faz G = haritaya dokunarak ekleme (opsiyonel / hızlı düzenleme). İkisi aynı düğüm modelini paylaşır.

### G.1 — Dokunma → piksel
- [x] Tap: `mapPreviewViewToPixel` (contain tersi) → `pixel_x/y`.
- [x] Tip + ad: ortak `NodeEditorDialog` (`lib/widgets/node_editor_dialog.dart`).
- [x] Düğümler’de **Dokunarak ekle** anahtarı + `MapPreviewStage.onMapTap`.

### G.2 — CRUD
- [x] Overlay marker’lar ortak `GcsNodeModel` listesinden.
- [x] ROS stub: `/stations/add|update|delete|list` (`RosBridgeClient` + `AgvService`); yerel draft öncelikli soft-sync.

### Faz G — değişen dosyalar
- `lib/services/map_preview_layout.dart`
- `lib/widgets/map_preview_stage.dart`
- `lib/widgets/node_editor_dialog.dart` *(yeni)*
- `lib/models/gcs_node_model.dart`
- `lib/node_teach_page.dart`
- `lib/services/ros_bridge_client.dart`
- `lib/services/agv_service.dart`
- `test/map_preview_layout_test.dart` *(yeni)*
- `analysis/execution_planiki.md`

---

## 🟤 Faz H — Rota düzenleme

### H.1 — Sıralı seçim
- [x] Öğretilmiş düğümler sırayla seçilir (`RouteEditPage` + marker/liste).
- [x] Seçim şeridi (chip + geri al / temizle).
- [x] Noktalar arası polyline (`MapPreviewStage.routePolylinePixels`).
- [x] Tek kaynak: `GcsNodeModel` (Senaryo ile aynı havuz).

### H.2 — Kaydet (ileriye dönük)
- [x] Kaydet → yerel draft + `/routes/save` stub.
- [x] Liste/sil → yerel + `/routes/delete` stub (`listRoutes` istemci hazır).
- [x] ROS yokken yerel `GcsRouteModel.savedRoutes` saklanır.

### Faz H — değişen dosyalar
- `lib/models/gcs_route_model.dart` *(yeni)*
- `lib/route_edit_page.dart` *(yeni)*
- `lib/widgets/map_preview_stage.dart`
- `lib/services/ros_bridge_client.dart`
- `lib/services/agv_service.dart`
- `lib/main.dart`
- `lib/controller_page.dart`
- `analysis/execution_planiki.md`

---

## ⚫ Faz I — Hata UX + buton state + entegrasyon cilası

### I.1 — Hata gösterimi
- [x] SnackBar + olay günlüğü + banner; `RosMappingErrors` (A.1) Türkçe.
- [x] ERROR → SnackBar; buton **Yeniden Dene** → `startMapping` tekrar (`canStartMapping` idle|error).

### I.2 — Navigasyon
- [x] Canlı önizleme = ana ekran **HARİTA** sekmesi (`MapPreviewStage`).
- [x] Menü: **DÜĞÜMLER**, **KAYITLI HARİTALAR**, **ROTA**.
- [x] Saha adı + Harita Oluştur = `MappingFieldBar` (HARİTA sekmesi üstü).
- [x] Eski editör: **HARİTA EDİTÖRÜ (ESKİ)** — `map_page.dart` silinmedi.

### I.3 — Test planı
- [x] `flutter analyze` temiz (I kapanışında doğrulanır).
- [x] Unit: saha adı, hata mesajı, status→buton, düğüm benzersizliği, contain→pixel.
- [ ] ROS canlı (saha doğrulama — manuel):
  1. Bağlan
  2. `saha_01` ile start / veya kayıtlı harita yükle
  3. Status 2 + PNG + robot ikonu
  4. Joystick ile alma noktasına git → Yeni düğüm → `A1` / Alma
  5. Bırakma için tekrarla → `B1`
  6. Senaryo ekranında `A1`/`B1` seçilebilsin
  7. Save / fields / koparma testleri

### Faz I — değişen dosyalar
- `lib/controller_page.dart`
- `lib/widgets/mapping_field_bar.dart`
- `test/gcs_mapping_ux_test.dart` *(yeni)*
- `analysis/execution_planiki.md`

---

## Önerilen dosya yapısı

```text
lib/
  services/
    ros_mapping_contract.dart   # topic/srv/enum/hata sabitleri
    ros_bridge_client.dart      # abonelik + servis (genişlet)
    agv_service.dart            # facade
  models/
    gcs_mapping_model.dart      # status, preview bytes, robot pixel, metadata
    gcs_field_model.dart        # saha listesi kartı
    gcs_node_model.dart         # öğretilmiş düğümler (ad, tür, pose)  ★ yeni
    gcs_station_draft.dart      # yerel istasyon/rota draft
  pages/  (veya mevcut lib/)
    field_mapping_page.dart     # oluştur + preview kontrolleri
    node_teach_page.dart        # Düğümler sayfası (robot konumundan)  ★ yeni
    saved_fields_page.dart      # kayıtlı haritalar
    field_route_editor_page.dart
    map_page.dart               # ESKİ grid editör — SİLİNMEZ
    scenerio_page.dart          # düğüm havuzuna bağlanacak
  widgets/
    map_preview_stage.dart
    mapping_status_banner.dart
    field_name_field.dart
    create_node_dialog.dart     # ad + tür seçimi  ★ yeni
```

---

## Faz sırası ve bağımlılık

```text
A (sözleşme + client)
  → B (start + status UI)
    → C (PNG + robot + metadata)
      → D (joystick kapısı)
        → E (save + fields + localization stub)
          → F (Düğüm sayfası — robot konumundan)  ★ şartname
            → G (dokunarak ekleme, opsiyonel)
              → H (rota / senaryo seçimi)
                → I (cila + test)
```

Paralel: **F UI iskeleti** mock pose ile A–C bitmeden denenebilir; gerçek PNG/robot gelince bağlanır.

---

## Kabul kriteri (ürün)

1. `ws://IP:9090` bağlanır, kopunca yeniden bağlanır, durum görünür.
2. Geçerli saha adı ile `/mapping/start` çağrılır.
3. Status akışı mapping butonlarını doğru kilitler; manuel sürüşü operatörün Manuel/Otonom seçimi belirler ve kopukken komut gönderilmez.
4. PNG harita ana **HARİTA** sekmesinde güncellenir; robot ikonu doğru; yalnız ikon döner.
5. Kopunca last-good PNG kalır; reconnect sonrası yeni preview ile yenilenir (stale≠canlı).
6. Metadata saklanır.
7. Joystick `/cmd_vel_manual` (hız tavanı STM32); bırakınca ve lifecycle’da sıfır.
8. **Düğümler sayfası:** robot konumuna ad+tür ile düğüm basılır; listelenir; senaryoda seçilir.
9. Eski `map_page.dart` silinmez.
10. Save / fields / localization / stations / routes için istemci stub + UI hazır.
11. Hatalar Türkçe ve anlaşılır; topic adları tek dosyada.

---

## İlerleme özeti (işaretleme)

| Faz | Durum |
|-----|--------|
| A Sözleşme + client | [x] |
| B Saha adı + start/status | [x] |
| C Preview PNG + robot + meta | [x] |
| D Manuel sürüş (operatör kontrollü) | [x] |
| E Save + fields + loc stub | [x] |
| F Düğüm sayfası (robot konumundan) | [x] |
| G Dokunarak istasyon (opsiyonel) | [x] |
| H Rota / senaryo bağlama | [x] |
| I Cila + test | [x] (ROS canlı manuel) |

**Temel ROS köprüsü (bağlantı/reconnect/cmd_vel):** hazır — Faz A/D altında kısmi tiklerle işlendi.  
**Eski grid HARİTA (`map_page.dart`):** korunur — silinmez.

---

*Bu plan uygulandıkça checkbox’lar işaretlenecek. ROS tarafı servisleri geldikçe stub’lar gerçek `callService` çağrılarına çevrilecek.*

---

## 2026-08-09 mapping/lokalizasyon sözleşme denetimi

- [x] `/mapping/start`: `marco_msgs/srv/StartMapping` — başarı alanı `accepted`.
- [x] `/mapping/stop`: `std_srvs/srv/Trigger` — başarı alanı `success`.
- [x] `/mapping/save`: `marco_msgs/srv/SaveMapping` — başarı alanı `success`.
- [x] `/fields/list`: `marco_msgs/srv/ListFields` — başarı alanı `success`.
- [x] `/localization/start`: `marco_msgs/srv/StartLocalization` — başarı alanı `accepted`.
- [x] `/localization/stop`: `std_srvs/srv/Trigger` — başarı alanı `success`; `StopLocalization.srv` yok ve oluşturulmadı.
- [x] Genel `success || accepted` kontrolü kaldırıldı; her servis kendi response alanıyla doğrulanıyor.
- [x] Boş `values: {}` ve yalnız rosbridge `result: true` uygulama başarısı sayılmıyor.
- [x] Save → SAVED sırası tek workflow ile korunuyor; kayıt öncesinde SLAM durdurulmuyor.
- [x] Kaydetmeden iptal için `/mapping/stop` ayrı bir UI eylemi olarak tutuluyor.
- [x] `flutter analyze`: temiz.
- [x] İlgili Flutter testleri: 29 geçti, canlı `ROS_BRIDGE_URL` testi ortam değişkeni olmadığı için atlandı.
- [x] `colcon build --symlink-install`: 13 paket geçti.
- [x] `marco_localization` sözleşme testleri: 3 geçti.
