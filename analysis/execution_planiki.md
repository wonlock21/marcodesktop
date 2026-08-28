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

---

# TEKNOFEST 2026 yarışma ek planı — V1.0 şartname odaklı

> **Dayanak:** `2026_SRUY_TR_76gNu.pdf`, V1.0, 05.05.2026; özellikle 3.1.1,
> 4. bölümdeki yarışma senaryosu ve final puanlama tablosu.
>
> **Amaç:** Video teslimi sonrası sistemi sunum demosu değil, gerçek yarışma akışı için
> tamamlamak. Üretim kodunda mock, sahte başarı veya yalnız yerel kalıcı olmayan görev
> verisi kabul edilmez.
>
> **Uygulama kuralı:** Aşağıdaki fazlar sırayla ve tek tek tamamlanacak. Her fazın ROS 2
> sözleşmesi, Flutter bağlantısı ve testleri bitmeden sonraki faza geçilmeyecek.

## Bu ek planın önceki fazlara göre yetkisi

- Önceki Faz G/H içindeki `/stations/*` ve `/routes/*` maddeleri yalnız UI/stub hazırlığıdır;
  gerçek backend bulunmadığı için yarışma açısından tamamlanmış sayılmaz. Faz J/K ile
  yeniden açılmıştır.
- Önceki Faz D.3 içindeki “fiziksel anahtar yok, GCS switch seçer” kararı şartnameyle
  çelişir ve artık geçersizdir. Uzaktan manuel sürüş yalnız robot üzerindeki fiziksel anahtar
  **manuel** konumdayken açılacak; otomatik konumdayken GUI komut gönderemeyecektir.
- `/base/manual_mode` bir durum topic’idir; Flutter bu topic’e yazmayacaktır. Flutter,
  `RobotStatus.manual_mode_enabled` üzerinden fiziksel yetkiyi okuyacaktır.
- `/cmd_vel_manual` üretim sözleşmesi `geometry_msgs/msg/Twist` SI değerleridir. Flutter
  normalize slider değerini doğrulanmış lineer/açısal tavanlara dönüştürecektir; hız gerçek
  robotta düşük kademeden başlayarak ayrıca kabul edilecektir.
- “Backend yok” yazısı geliştirme sırasında doğru teşhistir fakat yarışma ekranının nihai
  metni değildir. Faz Q tamamlanınca yalnız çalışan özellikler gösterilecektir.

## Şartnameden çıkarılan zorunlu yarışma akışı

1. Yarışmadan 1–2 gün önce verilen **60 dakika** içinde 2D LiDAR ile haritalama yapılır.
2. Rotalar; alma, bırakma, QR, düğüm, bekleme ve kontrollü kapı/Q5 noktaları tanımlanır.
3. Robot ve takip bilgisayarı internetsiz saha Wi-Fi ağına bağlanır; yalnız iki cihaz için
   MAC adresi izni vardır.
4. Robot PLC’ye bağlanır; PLC bağlantının kurulduğunu teyit eder.
5. PLC, üç alma noktasından ve üç bırakma noktasından rastgele birer nokta seçip robota
   gönderir.
6. Robot en uygun tanımlı rotayla alma noktasına gider. Yaklaşık 1,5 m önceki QR/renkli
   çizgiden itibaren hassas yaklaşma ve yük alma uygulanır.
7. Yük alındıktan sonra yük hareket yönünün ters tarafında kalacak biçimde taşıma yapılır.
8. Robot yüklü olarak Q5 kapı kontrol noktasında durur, PLC’ye varış bildirir, açık/geçiş
   izni gelmeden ilerlemez.
9. Bırakma noktasına gider, yükü bırakır ve PLC’ye teslim bilgisini gönderir.
10. Bekleme noktasına dönerken Q5 kapı el sıkışmasını ikinci kez uygular.
11. Bekleme noktasına vardığını PLC’ye bildirir ve görevi tamamlar.
12. Hedef süre 30 dakika, üst sınır 45 dakikadır.

Ortak güvenlik/kabul koşulları:

- Engel görülünce güvenli mesafede durulur; engelden kaçma zorunlu değildir. Engel
  kalkınca aynı görev kontrollü biçimde devam eder.
- Rota sapması en fazla 10 cm olmalıdır.
- Bekleme/alma/bırakma son poz toleransı ±7,5 cm, yön toleransı ±5° olmalıdır.
- GUI robot durumu, görev durumu, okunan QR, PLC bağlantısı ve PLC ile alınan/gönderilen
  mesajları göstermelidir. Eksik gösterilen her bilgi ceza puanı doğurur.
- GUI’de en az şu robot durumları açıkça gösterilir: idle, görev işleniyor, yüksüz hareket,
  yüklü hareket, PLC komutu bekleniyor, başlangıç/bekleme noktasına dönüş, hata, acil stop.

---

## Faz J — Genel düğüm/istasyon backend’i — GEÇİŞ KAPISI 1

> Kullanıcının 1. maddesi. Bu faz tamamlanmadan Faz K’ya geçilmez.

- [ ] **[ROS2]** Alma `A1..A3`, bırakma `B1..B3`, bekleme, QR, Q5/kapı ve gerektiğinde
  başlangıç düğümlerini aynı saha altında kalıcı saklayan veri modelini belirle.
- [ ] **[ROS2]** Düğüm ekleme, listeleme, güncelleme ve silme servislerini gerçek
  `marco_msgs/srv/*` arayüzleriyle sun; isimleri tek sözleşmede sabitle.
- [ ] **[ROS2]** Kayıtta `field_name`, benzersiz ad, tür, map-frame pose `(x,y,yaw)` ve
  gerekli piksel/önizleme bilgisini doğrula; servis cevaplarında açık `success/message` kullan.
- [ ] **[ROS2]** Düğümleri yeniden başlatma sonrasında kaybetmeyecek atomik saha
  persistence katmanı ekle; geçersiz/çakışan kayıtları reddet.
- [ ] **[ROS2]** Düğüm silme/güncellemede bağlı rotaların bozulmasını engelleyen referans
  kontrolü ekle.
- [ ] **[Flutter]** Mevcut `/stations/*` stublarını gerçek servis sözleşmesine bağla;
  başarılı ROS cevabı gelmeden yerel listeyi değiştirme.
- [ ] **[Flutter]** Robot konumundan ve haritaya dokunarak ekleme akışlarını aynı backend’e
  bağla; reconnect sonrasında listeyi ROS’tan yeniden yükle.
- [ ] **[Flutter]** A/B demo noktaları ile genel yarışma düğümlerini kavramsal olarak ayır;
  senaryo ekranında yalnız seçili sahanın gerçek kalıcı düğümlerini göster.
- [ ] **[ROS2+Flutter Test]** CRUD, duplicate ad, geçersiz tür/pose, farklı saha izolasyonu,
  restart persistence, stale response ve hızlı çift tıklama testleri geçsin.
- [ ] **[Kabul]** Yarışma öncesi 60 dakikalık öğretme sırasında A1..A3, B1..B3, Q5 ve
  bekleme noktası kaydedilip uygulama/ROS yeniden başlatıldıktan sonra geri gelmelidir.

## Faz K — Kalıcı rota tanımlama ve rota optimizasyonu — GEÇİŞ KAPISI 2

> Kullanıcının 2. maddesi. Bu faz tamamlanmadan Faz L’ye geçilmez.

- [ ] **[ROS2]** Saha bazlı rota/kenar veri modelini ve `save/list/update/delete` servislerini
  gerçek `marco_msgs` arayüzleriyle oluştur.
- [ ] **[ROS2]** Rota; sıralı düğümler, yön, maliyet/mesafe, hız sınıfı, yüklü-yüksüz
  uygunluğu ve kontrollü kapı geçiş bilgisini taşısın.
- [ ] **[ROS2]** PLC’den gelen alma/bırakma çifti için geçerli graph üzerinde en uygun rotayı
  hesapla; kopuk graph, bilinmeyen düğüm ve rota bulunamaması açıkça reddedilsin.
- [ ] **[ROS2]** Gidiş, yüklü taşıma ve bekleme noktasına dönüş rotalarını ayrı bacaklar
  halinde üret; dönüşte Q5 el sıkışmasını atlama.
- [ ] **[Flutter]** Rota editörünü gerçek backend’e bağla; “Backend yok” ve yerel-only kayıt
  davranışını kaldır.
- [ ] **[Flutter]** Kayıtlı rotaları harita üzerinde yönlü ve sıralı göster; kaydetme/silme
  yalnız ROS başarısından sonra UI’a yansısın.
- [ ] **[Flutter]** Seçilen veya PLC’den gelen A/B için hesaplanan görev bacaklarını ve aktif
  bacağı operatöre göster.
- [ ] **[ROS2+Flutter Test]** Persistence, en kısa/uygun rota, Q5 zorunluluğu, geçersiz rota,
  farklı saha ve yeniden bağlantı testleri geçsin.
- [ ] **[Kabul]** Haritalama/rotalama tamamlanmadan yarışma görev modu başlatılamasın.

## Faz L — LED gerçek ROS bağlantısı — GEÇİŞ KAPISI 3

> Kullanıcının 3. maddesi. Şartnamede LED için puan/sözleşme yoktur; buna rağmen mevcut
> GUI düğmesinin sahte kalmaması ve donanım geri bildirimi için tamamlanacaktır.

- [ ] **[ROS2]** LED donanımının gerçek sürücüsünü, komut semantiğini ve state feedback
  ihtiyacını doğrula; genel string komut yerine tipli servis/topic tanımla.
- [ ] **[ROS2]** En az `set_enabled` veya yarışmada kullanılacak açık durumları sun;
  `success/message` ve gerçek state topic’i sağla.
- [ ] **[Flutter]** LED düğmesini gerçek sözleşmeye bağla; servis başarılı olmadan durum
  değiştirme, hızlı çift tıklamayı engelle, reconnect’te state topic’ini bekle.
- [ ] **[ROS2+Flutter Test]** Aç/kapat, reddedilme, timeout, reconnect ve state uyuşmazlığı
  testleri geçsin.

## Faz M — Lift/yük alma-bırakma yürütücüsü — GEÇİŞ KAPISI 4

> Kullanıcının anlamadığı 4. madde budur: GUI’de lift yukarı/aşağı butonları görünse de
> komutu kabul eden doğrulanmış bir ROS action server ve “hareket ediyor/tamamlandı/hata”
> geri bildirimi yoksa robot gerçek yük alma-bırakma işlemini güvenilir biçimde yapamaz.
> Şartnamenin ana görevi yük taşımak olduğu için bu yarışma açısından kritiktir.

- [ ] **[ROS2]** Mevcut lift/STM32 mekanizmasını incele; gerçek komut, limit switch,
  yük algısı, timeout, iptal ve hata koşullarını belirle.
- [ ] **[ROS2]** Tek sahipli, iptal edilebilir ve feedback veren `LiftLoad` action veya eşdeğer
  tipli arayüzü tamamla; yukarı/aşağı ham komutlarını yarışma iş akışından gizle.
- [ ] **[ROS2]** Yük alma ve bırakmayı navigasyon durum makinesiyle kilitle; hareket eden
  araçta lift komutunu ve doğrulanmamış yük sonrası göreve devamı engelle.
- [ ] **[Flutter]** Lift kontrollerini gerçek action/state’e bağla; pending, hareket,
  tamamlandı, reddedildi ve hata durumlarını göster.
- [ ] **[Flutter]** “Yük yerleştirildi / Devam Et” yalnız yarışma akışında gerçekten operatör
  onayı gerekiyorsa ve ROS bunu bekliyorsa etkin olsun.
- [ ] **[ROS2+Flutter Test]** Limit, timeout, iptal, çift komut, e-stop, bağlantı kopması,
  yük alındı/bırakıldı geri bildirimi testleri geçsin.

## Faz N — Kamera, LiDAR, 3D, QR ve çizgi takibi — GEÇİŞ KAPISI 5

> Kullanıcının 6. maddesi. Bu faz tamamlanmadan PLC yarışma entegrasyonuna geçilmez.

- [ ] **[ROS2]** Üretim kamera görüntüsü, LiDAR scan/point cloud, QR tespiti ve çizgi takip
  topic’lerini/adlarını/tiplerini/QoS değerlerini kesinleştir.
- [ ] **[ROS2]** QR mesajında en az kod, zaman damgası, kamera göreli pozisyonu ve
  güven/geçerlilik bilgisi sağla.
- [ ] **[ROS2]** Alma/bırakma noktasından yaklaşık 1,5 m önce QR/renkli çizgiyle hassas
  yaklaşma durum makinesini navigation ve lift akışına bağla.
- [ ] **[ROS2]** Engel kalkınca kontrollü devamı ve LiDAR veri stale olduğunda güvenli
  duruşu doğrula.
- [ ] **[Flutter]** KAMERA, LiDAR ve 3D sekmelerini gerçek topic’lere bağla; bağlantı yokken
  sahte görüntü kullanma.
- [ ] **[Flutter]** Okunan QR kodunu, göreli konumunu, güncellik durumunu ve görevde
  beklenen QR ile eşleşmesini ana yarışma ekranında göster.
- [ ] **[Flutter]** Ağ bant genişliğini korumak için görüntü aboneliklerini yalnız ilgili sekme
  açıkken veya düşük oranlı preview olarak yönet.
- [ ] **[ROS2+Flutter Test]** Stale frame, bozuk görüntü, QR yanlış/eşleşen, topic reconnect,
  çizgiye geçiş ve engel dur/devam testleri geçsin.

## Faz O — PLC ve STM32 yarışma entegrasyonu — GEÇİŞ KAPISI 6

### Şartnamenin PLC için kesin söylediği

- PLC’ye bağlantı saha Wi-Fi ağı üzerinden kurulacaktır.
- PLC üç alma ve üç bırakma noktasından rastgele birer seçim yapıp robota gönderecektir.
- Robot Q5’te durduğunu PLC’ye bildirecektir.
- PLC kapının açık ve geçişin uygun olduğunu bildirmeden robot ilerlemeyecektir.
- Robot yükü bıraktığını ve daha sonra bekleme noktasına vardığını PLC’ye bildirecektir.
- Dönüş yolunda Q5 kapı el sıkışması tekrar yapılacaktır.
- GUI PLC bağlantı durumunu ve alınan/gönderilen mesajları gösterecektir.

### Şartnamenin söylemediği

- Modbus TCP, OPC UA, TCP socket, UDP veya başka bir wire protokol belirtilmemiştir.
- IP, port, register/adres, paket biçimi, sequence/ack, timeout ve retry değerleri yoktur.
- STM32 adı veya Orange Pi–STM32 seri protokolü şartnamede tanımlanmamıştır.
- Şartname, PLC haberleşme protokolünün ön aşamayı geçen takımlara ayrıca verileceğini
  açıkça belirtmektedir. Bu ayrı belge gelmeden alan isimleri uydurulmayacaktır.

### Yapılacaklar

- [ ] **[ROS2]** Organizasyonun ayrı PLC protokol belgesini kaynak olarak kaydet ve exact
  wire sözleşmesini çıkar: bağlantı, A/B görev mesajı, Q5 arrival, gate permission,
  load-delivered, waiting-arrival, ack/error, timeout/retry ve duplicate handling.
- [ ] **[ROS2]** PLC adapter düğümünü mission manager’dan ayır; bağlantı ve mesajları tipli
  ROS topic/service üzerinden sun.
- [ ] **[ROS2]** PLC’den gelen A/B değerini doğrula; bilinmeyen/tekrarlı/stale görevleri
  reddet ve görev kimliği/idempotency uygula.
- [ ] **[ROS2]** Q5’e her iki gelişte de “arrival → izin bekle → izin doğrula → devam”
  durum makinesini fail-closed uygula.
- [ ] **[ROS2]** PLC kopması, izin timeout’u ve hatalı mesajda robotu güvenli beklemeye al;
  otomatik olarak izin varmış gibi davranma.
- [ ] **[ROS2]** STM32 için mevcut seri sözleşmeyi ayrı doğrula: fiziksel manuel anahtar,
  e-stop, motor watchdog, batarya, lift limit/yük ve bağlantı sağlığı.
- [ ] **[Flutter]** PLC bağlantı durumu, gelen A/B görevi, kapı izni, son alınan/gönderilen
  mesajlar ve hata/timeout’u ana ekranda görünür yap.
- [ ] **[Flutter]** STM32 bağlantısını yalnız gerçek heartbeat/state ile göster; süre aşımında
  bağlı durumunu temizle.
- [ ] **[ROS2+Flutter Test]** PLC simülatörüyle normal görev, duplicate, bozuk paket,
  reconnect, Q5 iki geçiş, izin yok/timeout ve bekleme bildirimi testleri geçsin.
- [ ] **[Saha hazırlığı]** İnternetsiz `YARISMA DENEME AGI` ve `YARISMA AGI` için robot ve
  takip bilgisayarı MAC adreslerini kaydet; sistemin internet/bulut bağımlılığı olmadığını
  doğrula.

## Faz P — Yarışma görev orkestrasyonu ve durum makinesi

- [ ] **[ROS2]** PLC’den A/B görevi alma → rota seçme → yüksüz alma noktasına gitme →
  QR/çizgi yaklaşma → lift ile yük alma → yüklü ters yön taşıma → Q5 izni → bırakma →
  teslim bildirimi → Q5 dönüş izni → bekleme → tamamlandı akışını tek kalıcı mission
  state machine olarak uygula.
- [ ] **[ROS2]** En az `idle`, `processing`, `moving_unloaded`, `moving_loaded`,
  `waiting_plc`, `returning_home`, `error`, `emergency_stop` durumlarını yayınla.
- [ ] **[ROS2]** Engel kalkınca aynı görevden devam et; e-stop/safety reset sonrasında
  operatör onayı olmadan otomatik hareket başlatma.
- [ ] **[ROS2]** ±7,5 cm konum, ±5° yön ve 10 cm rota sapma metriklerini telemetry/event
  olarak ölçülebilir hale getir.
- [ ] **[Flutter]** PLC’den gelen yarışma görevini manuel senaryo oluşturulmuş gibi taklit
  etme; gerçek görev kimliği, A/B, aktif bacak, durum ve beklenen sonraki olayı göster.
- [ ] **[Flutter]** Görev durum çizelgesini şartnamedeki sekiz durumla birebir göster;
  yük durumu, Q5 izni, engel bekleme ve dönüş durumunu görünür yap.
- [ ] **[Flutter]** Görev süresi, 30 dakika hedefi ve 45 dakika üst sınırı operatöre göster;
  bu sayaç yalnız bilgilendirme amaçlı olsun ve ROS görev sonucunu değiştirmesin.
- [ ] **[ROS2+Flutter Test]** Her A/B kombinasyonu, iki Q5 geçişi, engel dur/devam,
  PLC kopması, lift hatası, e-stop, cancel ve tamamlanma testleri geçsin.

## Faz Q — Yarışma GUI sadeleştirmesi ve destek kapıları

> 9. madde için karar: Yarışma sürümünde “Backend yok” yazan buton/sekme bırakılmayacak.
> Geliştirmede dürüst hata gösterimi korunur; yarışma build’inde yalnız gerçek backend’i ve
> canlı state’i olan özellikler görünür/etkin olur. Çalışmayan özellik asla başarılı gösterilmez.

- [ ] **[Flutter]** Merkezi capability modeli oluştur; ROS envanteri/state üzerinden hangi
  özelliğin hazır olduğunu belirle.
- [ ] **[Flutter]** Geliştirme teşhis mesajlarını olay günlüğüne taşı; yarışma ana ekranında
  “Backend yok” gibi iç mimari ifadeleri kaldır.
- [ ] **[Flutter]** Tamamlanan Faz J/K/L/M/N/O özelliklerini sırayla etkinleştir; eksik
  özellikleri gizle veya nötr biçimde pasif bırak.
- [ ] **[Flutter]** Ana yarışma görünümünü puanlanan bilgilere önceliklendir: robot durumu,
  görev durumu, QR, PLC bağlantısı, alınan/gönderilen PLC mesajları, hata ve e-stop.
- [ ] **[Flutter]** Operatörün yarışma sırasında yanlışlıkla harita silme, rota silme veya
  öğretme moduna girme riskini yarışma kilidi/onaylarıyla azalt.
- [ ] **[Flutter Test]** Her zorunlu bilginin görünür olduğu widget kabul testi ekle; eksik
  her bilgi yarışma öncesi blocker sayılsın.

## Faz R — Parametre ekranı — ERTELENMİŞ

> Kullanıcının 5. maddesi. Çekirdek yarışma akışı tamamlandıktan sonra ele alınacaktır.

- [ ] **[ROS2]** Yarışma sırasında güvenle değiştirilebilecek parametreleri allowlist ile
  tanımla; salt okunur ve restart gerektiren parametreleri ayır.
- [ ] **[ROS2]** Atomik get/set, doğrulama, aralık ve kalıcılık sözleşmesi sun.
- [ ] **[Flutter]** Yerel `ParameterModel` güncellemelerini gerçek ROS cevaplarına bağla;
  başarılı cevap gelmeden değer kaydedilmiş görünmesin.
- [ ] **[ROS2+Flutter Test]** Aralık dışı değer, kısmi hata, restart persistence ve yetkisiz
  parametre testleri geçsin.

## Faz S — Canlı robot ve yarışma kabulü — EN SON

> Kullanıcının 10. maddesi. Önceki fazlar bitmeden fiziksel uçtan uca kabul yapılmaz.

- [ ] **[Test]** Tekerler havadayken read-only ROS envanteri, rosbridge reconnect,
  RobotStatus/manual switch, e-stop, watchdog ve sıfır Twist doğrulansın.
- [ ] **[Test]** Düşük hızda W/S ve A/D; tuş bırakma, pencere focus kaybı ve bağlantı
  kopmasında duruş doğrulansın.
- [ ] **[Test]** 60 dakikalık haritalama/öğretme provası yapılıp persistence doğrulansın.
- [ ] **[Test]** PLC simülatörüyle tüm 3×3 A/B kombinasyonları ve iki yönlü Q5 el sıkışması
  hareket vermeden kabul edilsin.
- [ ] **[Test]** Kontrollü alanda gerçek yükle alma, ters yön taşıma, bırakma ve beklemeye
  dönüş tamamlanıp konum/yön/rota sapma metrikleri kaydedilsin.
- [ ] **[Test]** Engel dur/devam, PLC kopması, rosbridge kopması, STM32 stale, lift hatası,
  e-stop ve güvenli reset senaryoları çalıştırılsın.
- [ ] **[Test]** İnternetsiz yarışma Wi-Fi provası, MAC filtreleme ve yalnız iki cihazla
  çalışma doğrulansın.
- [ ] **[Test]** GUI’de şartnamenin zorunlu bütün bilgilerinin hakem tarafından tek ekranda
  okunabildiği kontrol edilsin.
- [ ] **[Kabul]** “Yarışmaya hazır” kararı yalnız gerçek robotla en az bir tam görev ve
  hata senaryoları kanıtlandıktan sonra verilsin.

## Yeni faz sırası

```text
J Genel düğüm backend'i
  → K Kalıcı rota + optimizasyon
    → L LED
      → M Lift/yük yürütücüsü
        → N Kamera/LiDAR/3D + QR/çizgi
          → O PLC/STM32
            → P Yarışma görev orkestrasyonu
              → Q Yarışma GUI sadeleştirmesi
                → R Parametreler (ertelenmiş)
                  → S Canlı robot kabulü
```

| Yeni faz | Durum | Değişiklik alanı |
|---|---|---|
| J Genel düğüm/istasyon backend’i | [ ] | ROS2 + Flutter |
| K Kalıcı rota ve optimizasyon | [ ] | ROS2 + Flutter |
| L LED gerçek bağlantı | [ ] | ROS2 + Flutter |
| M Lift/yük alma-bırakma | [ ] | ROS2 + Flutter |
| N Kamera/LiDAR/3D, QR ve çizgi | [ ] | ROS2 + Flutter |
| O PLC/STM32 yarışma entegrasyonu | [ ] | ROS2 + Flutter |
| P Yarışma görev orkestrasyonu | [ ] | ROS2 + Flutter |
| Q Yarışma GUI sadeleştirmesi | [ ] | Flutter |
| R Parametre ekranı | [ ] ertelendi | ROS2 + Flutter |
| S Canlı robot kabulü | [ ] en son | Test / fiziksel sistem |
