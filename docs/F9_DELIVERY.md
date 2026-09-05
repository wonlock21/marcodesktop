# 1. İNCELENEN REPOLAR

| | ROS referans | Flutter hedef |
|---|---|---|
| Tam yol | /home/emre/marco_ws | /home/emre/marcodesktop |
| Branch | main | main |
| Başlangıç / incelenen SHA | f677bd533a58e89895fa1de6289596d6bf3e3cda | 3b2b7fdab73b31135cba290d0f13dc44a6a9e461 |
| Başlangıç status --short | boş / temiz | ?? AGENTS.MD |
| Remote fetch/push | https://github.com/wonlock21/marco_ws.git | https://github.com/wonlock21/marcodesktop |

ROS `git fetch origin` başarılı; local HEAD = origin/main. Pull, reset, checkout,
clean, force veya commit/push yapılmadı. Mevcut AGENTS.MD korundu.
ROS son çalışma ağacı temizdir; ROS kaynaklarında değişiklik yoktur.

# 2. İLK AUDIT SONUCU

Mevcut rosbridge reconnect/subscription, mapping save lifecycle, field list,
production node/edge CRUD, pixel_to_map, validator errors/warnings parse,
expected_hash aktivasyonu, active field subscriber, buzzer testleri ve HTTP
MJPEG görüntüleme altyapısı korundu. Ayrıntılı başlangıç matrisi
[F9_COMPATIBILITY_AUDIT.md](F9_COMPATIBILITY_AUDIT.md) içindedir.

# 3. ESKİ / EKSİK BULUNANLAR

- Gate Q6 rolü ve güncel iki yönlü crossing kuralı eksikti.
- StationApproachConfig modeli/servisleri/ekranı yoktu.
- RobotStatus kısmi ve widget içinde parse ediliyordu; route/gate/QR/docking alanları eksikti.
- Eski senaryo local/demo eşleşmelerinden production submit yapabiliyordu.
- Ana Start, hazır GUI görevi doğrulanmadan çağrılabiliyordu; hata/pending görünürlüğü eksikti.
- Kamera IP'si sabitti; alan değişimi/arka plan yaşam döngüsü eksikti.
- Reconnect sonrası graph freshness ve localization onayı doğru yenilenmiyordu.
- Saha adı ilk karakter kuralı ROS'tan farklıydı; node adı ise gereğinden fazla kısıtlıydı.

# 4. UYGULANAN DEĞİŞİKLİKLER

- Ortak ROS/model/repository/state katmanları Android ve Windows tarafından kullanılır.
- İstasyon/QR ekranı gerçek dock/station verilerini kullanır; QR, left/right, derece
  cinsinden heading ve 0.1–120 s süreyi doğrular, radyana çevirip ROS'a kaydeder ve yeniden okur.
- Gate rollerini ve yönlü event'leri destekleyen production graph editörü;
  node adı/rol/station/poz/yaw/yük/mod/metadata düzenleme, current pose ve harita tıklaması.
- Production görev ekranı aktif paketin hash'iyle eşleşen graph dock adlarından seçim yapar.
  Hazırla ve Başlat ayrı kullanıcı eylemleridir. Submit'in tamamlanması Start çağırmaz.
  Aynı işlem pending iken veya kabul edilmiş submit'in ROS durumu beklenirken yinelenmez.
- Cancel/reset ve **Yazılımsal Acil Durdurma** gerçek servis response'larıyla çalışır;
  hata SnackBar/panelde gösterilir. Fiziksel E-stop yerine geçtiği söylenmez.
- RobotStatus'un 56 alanı, route/gate/QR/docking panelleri ve ham alan görünümü eklendi.
  STATE_RETURNING artık görev tamamlandı olarak gösterilmez. Süre ROS'tan alınır.
- Mission event'leri ROS stamp sırasıyla, 200 kayıt kapasiteli buffer'da tutulur;
  bilinmeyen adlar ve payload alanları korunur.
- Disconnect/stale durumu komut yetkisini kaldırır. Reconnect list/active/graph/config
  sorgularını ve topic subscription'larını yeniden kurar; eski data canlı sayılmaz.
- Validator errors/warnings kaydırılabilir; hash değişince validation kilidi düşer.
  Aktivasyon güncel robot/mapping/active bilgisi, duruş ve doğru hash ister; son karar ROS'tadır.
- Kamera `/camera/image_raw` HTTP MJPEG port 8080'de kalır, rosbridge 9090 ile karışmaz.
  Adres robot girişinden gelir; stream dispose/adres değişimi/sayfa örtülmesi/arka planda kapanır.
- AMCL kayıtlı başlangıç pozunu ROS manager otomatik yükler. GUI gerektiğinde map
  koordinatlarında `/initialpose` düzeltme komutu sunar; yerel başarı/localized durumu üretmez.
- PLC ve fiziksel mod anahtarı için donanım bekleme etiketi kullanılır. Yeni protokol,
  hareket timer'ı, navigation/junction sistemi veya ROS action kontrolü yazılmadı.

# 5. DEĞİŞTİRİLEN DOSYALAR

Aşağıdaki yolların tamamı `/home/emre/marcodesktop` altındadır. AGENTS.MD mevcut
kullanıcı dosyasıdır ve bu listeye dahil değildir.

- `docs/F9_COMPATIBILITY_AUDIT.md`
- `docs/F9_DELIVERY.md`
- `lib/controller_page.dart`
- `lib/main.dart`
- `lib/models/field_graph_models.dart`
- `lib/models/gcs_event_log_model.dart`
- `lib/models/gcs_field_graph_model.dart`
- `lib/models/gcs_mapping_model.dart`
- `lib/models/gcs_mission_model.dart`
- `lib/models/gcs_node_model.dart`
- `lib/models/robot_status.dart`
- `lib/node_teach_page.dart`
- `lib/production_mission_page.dart`
- `lib/route_edit_page.dart`
- `lib/saved_fields_page.dart`
- `lib/scenerio_page.dart`
- `lib/services/angles.dart`
- `lib/services/camera_stream_config.dart`
- `lib/services/field_graph_repository.dart`
- `lib/services/ros_bridge_client.dart`
- `lib/services/ros_mapping_contract.dart`
- `lib/station_config_page.dart`
- `lib/widgets/control_buttons.dart`
- `lib/widgets/mjpeg_camera_view.dart`
- `test/camera_dispose_test.dart`
- `test/camera_stream_config_test.dart`
- `test/field_graph_contract_test.dart`
- `test/fixtures/robot_status.json`
- `test/production_f9_test.dart`

# 6. ROS CONTRACT FARKLARI

- FieldNode `node_id` uint64 ve `pose.x/y/theta`; düz x/y/yaw yok.
- Mission `route_nodes` graph düğüm **adlarıdır**; sayısal node ID gönderilmez.
- FieldNode.msg yorumunda gate_q6 eksik olsa da graph_model/validator destekler; GUI destekler.
- Station config `auto` okunabilir ama production validator reddeder; GUI yalnız left/right sunar.
- q5'e komşu her kenar gate olayı istemez; yalnız iki gate rolü arasındaki crossing yön/event ister.
- Loaded edge için ROS validator reverse zorunluluğu korunmuştur.
- Mapping save boş request'tir; başarılı manager kaydı SLAM'i de kapatır.
- Localization INITIALIZING ve kayıtlı initial pose aktarımı manager sorumluluğundadır.
- Mapping 0–6, localization 0–6; field package draft/valid/active/archived/error gerçek enumları kullanılır.
- Competition validator WAIT/A1–A3/B1–B3 ister; GUI istasyon listesi hard-code edilmez, ROS sonuçları gösterilir.
- Field adı harf/rakamla başlar; node adında graph_model boş olmama kontrolü yapar.
- Aktivasyon ROS'ta IDLE/ERROR ve |linear_speed|≤0.02 ister; GUI bilinen koşulları buna göre kilitler.
- Mevcut güvenli JSON ID sınırı korunur; daha büyük dış uint64 kimlikleri açık parse hatasıdır.

# 7. ROS TARAFINDA BULUNAN GERÇEK PROBLEMLER

`src/marco_msgs/srv/StartMission.srv` ve
`src/marco_mission/marco_mission/mission_manager.py::_on_start`:
Start request'i task_id taşımaz; hazır GUI görevi yoksa PLC'den görev isteyebilir.
RobotStatus ayrı queued/running alanı sunmaz. GUI Start'ı gerçek hazır görevle
sınırlar; ancak başka istemcinin arada iptal etmesi gibi eşzamanlı durum değişimini
sunucuda expected task_id ile sabitleyemez. Bu bir arayüz kısıtıdır; ROS değiştirilmedi.

FieldNode.msg içindeki rol yorumunun gate_q6'yı listelememesi dokümantasyon
uyuşmazlığıdır; çalışan backend bu rolü kabul eder.

# 8. TEST SONUÇLARI

Flutter **3.38.9**, Dart **3.10.8** kullanıldı. Windows Flutter kurulumu değiştirilmedi;
aynı sürüm Linux araçları `/tmp/marco-flutter-sdk` altında hazırlandı. Pubspec ve lock
sürümleri yükseltilmedi.

| Komut | Sonuç | Açıklama |
|---|---|---|
| dart format | PASS | Değişen/yeni 26 Dart dosyası formatlandı |
| flutter analyze --no-pub | PASS | No issues found |
| flutter test --no-pub | PASS | Senaryo ekranı düzeltmesi sonrası 78 geçti; 1 gerçek ROS testi ROS_BRIDGE_URL yok diye atlandı |
| flutter build windows --no-pub | ENVIRONMENT UNSUPPORTED | İlk deneme Windows host gerektiriyor dedi; son kullanıcı talimatıyla Windows doğrulaması kullanıcıya bırakıldı |
| flutter build apk --debug --no-pub | ENVIRONMENT UNSUPPORTED | Araç indirmeleri tamamlandı; Linux Android SDK bulunamadı. APK üretilmedi |

Test kapsamı: JSON modelleri ve servis zarfları, opsiyonel durum alanları,
node/edge/station serialization, açı dönüşümü, validator errors/warnings widget
paneli, aktif saha kilidi, arbitrary gate/station kimlikleri, ayrı submit/start
widget eylemleri, otomatik start olmaması, duplicate pending ve kabul sonrası
submit kilidi, reconnect subscriptions ve list/active/graph/config sorguları,
bilinmeyen event/ring buffer, başlangıç pozu publish, servis unavailable hatası,
kamera dispose ve adres değişimi.

İlk sandbox test denemesi localhost soket açma iznine takıldı; izinli yeniden
çalıştırma tamamlandı. Kamera testinin fake-async cleanup beklemesi düzeltildi.
Canlı robot hareketi, PLC, QR/docking ve saha kabulü bu testlerden çıkarılamaz.

# 9. DONANIM NEDENİYLE BEKLEYENLER

- Gerçek PLC wire protokolü ve izin/tamamlanma entegrasyonu.
- Fiziksel mod anahtarı ve manuel yetki kabulü.
- Gerçek QR okuyucu, lane tracking ve docking tolerans/süre kabulü.
- Gerçek robotta kamera akışının ve arka plan/ağ kesintisi davranışının doğrulanması.
- Yük/lift/gate/junction ve tam görev fiziksel kabulü; iki süreli F9 provası,
  F10 üç tam koşu ve F11 release doğrulaması.

Kaynak planda haritalama/kayıt ve tekrarlı AMCL başlangıcı daha önce kullanıcı
onaylıdır; bu oturumda yeniden fiziksel test yapılmadı.

# 10. F9 HAZIRLIK SONUCU

**HAZIR DEĞİL**

Blocker'lar:

- Canlı production ROS ile GUI'den sıfırdan field → validation → activation →
  submit → explicit start → completion zinciri ve süreli F9 kabulü henüz doğrulanmadı.
- Gerçek PLC, fiziksel mod anahtarı ve QR/lane/docking/lift/gate/junction fiziksel
  kabul kapıları tamamlanmadan F10/F11 yarışma hazır denemez.

Windows build, kullanıcının son talimatına göre bu görevin blocker'ı değildir.

## GUI üzerinden F9 operasyon kartı

1. Ana bağlantı panelinde robot adresini gir ve Bağlan; connected durumunu doğrula.
2. Harita Oluştur ile yeni saha adını gir; MappingStatus'u izle.
3. Bitir/Kaydet ile SaveMapping sonucunu ve SAVED durumunu bekle. Manager normalde
   SLAM'i kapatır; hata/iptal için mevcut mapping durdur kontrolü kullanılır.
4. Kayıtlı Haritalar'ı yenile; saha için Lokalizasyon başlat. INITIALIZING →
   LOCALIZING izle; gerekirse Başlangıç pozu ile map X/Y/yaw düzeltmesi gönder.
5. Sahanın Düğümler ekranını aç. Localization/preview sahasının seçili field ile
   eşleştiğini doğrula. Robot pozundan öğret veya haritaya tıkla; isim/rol/station,
   yük/mod ve yaw gir. Mevcut düğümde X/Y/yaw da düzenlenebilir.
6. Transit junction, outbound gate_q5, return gate_q6, pickup/dropoff approach/dock
   rollerini saha geometrisine göre oluştur. Aynı istasyonda station_id aynı olmalı.
7. Rota ekranında edge ekle/düzenle/sil; cost/hız/yük/yön gir. İki gate arasına
   ayrı yönlü q5_outbound ve q6_return crossing kenarlarını koy. Junction açısı girilmez.
8. Rota → İstasyon / QR'da graph dock'larından her istasyonu seç; yaklaşım QR,
   heading, left/right ve süreyi kaydet. Ayarlar ROS'tan yeniden okunur.
9. Doğrula; tüm hataları/uyarıları kaydırıp incele. Değişiklik sonrası tekrar doğrula.
10. Robot durmuş, mapping kapalı, görev yok ve durumlar güncelken Aktifleştir.
    Gerçek active field adı, package version/hash ve robot ready bilgisini doğrula.
11. Ana Senaryo ekranında aktif graph'tan alma/bırakma duraklarını sırayla seç;
    birden çok çift ve başlangıca dönüş desteklenir. Yerel taslağı bağlantı olmadan
    da düzenleyip Senaryoyu Kaydet ile cihazda saklayabilirsin. Bu kayıt ROS submit değildir.
12. Görevi Hazırla / Submit'e bas. Gerçek ROS hazır görevini gör; ayrıca Başlat / Start'a bas.
13. Görev/rota, gate yön/entry/crossing/izin, QR/armed/rejection, docking süre/kamera/
    lane/stopped/error ve mission event'lerini izle. Tamamlanma ROS event'inden görülür.
14. Gerektiğinde Görevi İptal Et, Safety Reset veya Yazılımsal Acil Durdurma kullan.
    Bağlantı koparsa eski durumdan hareket/başarı sonucu çıkarma; yeniden senkronizasyonu bekle.

Bu kart istenen 38 adımın GUI karşılıklarını kapsar; fiziksel koşu kanıtı değildir.

## Senaryo ekranı düzeltmesi

Ana Senaryo tuşu ve Düğümler ekranındaki Senaryoya geç, mevcut görsel senaryo
editörünü açar. Harita üzerinde durak seçme, çoklu alma/bırakma çiftleri, geri alma,
sıfırlama ve taslak kaydetme korunur. Saha başına yerel taslak yeniden açılışta
yüklenir. Görev İzleme, senaryo ekranının üst çubuğundan ayrı açılır.

ROS bağlantısı ve aktif saha koşulları yerel düzenlemeyi kilitlemez. Yalnız
Görevi Hazırla ve Başlat için ortak mission state koşulları uygulanır;
engelleyen neden ekranda görünür. Submit sonrasında otomatik Start çağrılmaz.
Yerel harita noktaları production graph düğümü yerine gönderilemez.

Bu düzeltmede format ve analyze temiz; tam test paketi 78 PASS / 1 SKIP.
Windows build kullanıcıya bırakıldı; önceki donanım kabul sınırları devam eder.
