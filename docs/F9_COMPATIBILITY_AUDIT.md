# F9 uyumluluk denetimi

ROS salt okunur kaynak: `/home/emre/marco_ws`, main,
`f677bd533a58e89895fa1de6289596d6bf3e3cda`. Başlangıç temiz; fetch sonrası
origin/main aynı SHA. Flutter: `/home/emre/marcodesktop`, main,
`3b2b7fdab73b31135cba290d0f13dc44a6a9e461`; başlangıçta yalnız `?? AGENTS.MD`.
Remote: ROS https://github.com/wonlock21/marco_ws.git,
GUI https://github.com/wonlock21/marcodesktop (fetch/push).

Bu tablo değişiklik öncesi durumdur. Kaynaklar: marco_msgs msg/srv/action,
route_editor_node, graph_model, validator, station_config, field_store,
mapping_manager, localization_manager, mission_manager, real_system.launch,
yarisma_plani F3/F4/F7A–F8C/F9–F11.

| ROS interface | Gerçek ROS tipi | GUI mevcut/doğruluk | Eksik / uygulanacak değişiklik |
|---|---|---|---|
| rosbridge :9090 | WebSocket JSON v2 | Var; reconnect/subscription ve timeout mevcut | Servis hata envelope görünürlüğü, duplicate koruması |
| /mapping/start | marco_msgs/srv/StartMapping | Var, field_name/accepted doğru | Koru; güncel durum kilitleri |
| /mapping/save | marco_msgs/srv/SaveMapping | Var, boş request/success doğru | Koru; manager kayıttan sonra SLAM'i kapatır |
| /mapping/stop | std_srvs/srv/Trigger | Var | Koru |
| /mapping/status | marco_msgs/msg/MappingStatus | Var, enum 0–6 doğru | header/field_name/process_id tamamla |
| /localization/start | marco_msgs/srv/StartLocalization | Var, accepted doğru | Koru |
| /localization/stop | std_srvs/srv/Trigger | Var | Koru |
| /localization/status | marco_msgs/msg/LocalizationStatus | Var, enum 0–6 doğru | header/process_id tamamla; stale kilidi |
| /initialpose | geometry_msgs/msg/PoseWithCovarianceStamped | GUI yok | Manager kayıtlı initial pose'u otomatik uygular; GUI düzeltme komutu |
| /fields/list | marco_msgs/srv/ListFields | Var | Mevcut typed FieldInfo koru |
| /fields/get_graph | marco_msgs/srv/GetFieldGraph | Var | gate_q6 parse; reconnect freshness |
| /fields/save_node | marco_msgs/srv/SaveFieldNode | Var | gate_q6 rolü |
| /fields/save_current_pose_node | marco_msgs/srv/SaveCurrentPoseNode | Var | Koru, localized pose ROS'ta alınır |
| /fields/delete_node | marco_msgs/srv/DeleteFieldNode | Var; bağlı kenar onayı var | Koru |
| /fields/save_edge | marco_msgs/srv/SaveFieldEdge | Var, eski gate kuralı | Tüm q5 komşularına event zorlamasını kaldır; rol çiftinden gate event |
| /fields/delete_edge | marco_msgs/srv/DeleteFieldEdge | Var | Koru |
| /fields/pixel_to_map | marco_msgs/srv/PixelToMap | Var | Seçili field/önizleme eşleşmesi kontrolü |
| /fields/get_station_approach_configs | marco_msgs/srv/GetStationApproachConfigs | Yok | Model, repository, state, ekran |
| /fields/save_station_approach_config | marco_msgs/srv/SaveStationApproachConfig | Yok | 6 alan, left/right, derece utility, servisle kaydet/yeniden oku |
| /fields/validate | marco_msgs/srv/ValidateField | Var, errors/warnings listesi var | Hash freshness ve regression testleri |
| /fields/activate | marco_msgs/srv/ActivateField | Var, expected_hash doğru | Status/graph tazeliği ve aktif kilidi |
| /fields/get_active | marco_msgs/srv/GetActiveField | Var | Reconnect sorgusunu koru |
| /fields/archive | marco_msgs/srv/ArchiveField | Var | Koru |
| /fields/active | marco_msgs/msg/ActiveField | Var | Aktif version/hash gösterimini koru |
| /fields/package_status | marco_msgs/msg/FieldPackageStatus | Var | Dış değişiklikte validation invalidation |
| /mission/submit | marco_msgs/srv/SubmitMission | Var; eski senaryo local demo fallback kullanıyor | Aktif graph dock adlarından production seçim, ortak state |
| /mission/start | marco_msgs/srv/StartMission | Var; ayrı çağrı ama korumasız | Submit'ten ayrı açık komut, pending ve ready kilitleri |
| /mission/cancel | marco_msgs/srv/CancelMission | Var | UI hata/pending koruması |
| /mission/reset_safety | marco_msgs/srv/ResetMissionSafety | Var | UI hata/pending koruması |
| /mission/emergency_stop | std_srvs/srv/Trigger | Var | Yazılımsal etiket, hata görünürlüğü, duplicate koruması |
| /robot_status | marco_msgs/msg/RobotStatus | Kısmi, widget içinde map parse | Tüm alanları ortak typed model, stale görünürlüğü, gate/QR/docking/route |
| /mission/events | std_msgs/msg/String | Var, ham metin/yerel timestamp | JSON stamp/event/state/task_id/source, sınırlı sıralı generic görünüm |
| kamera :8080/stream?topic=/camera/image_raw | HTTP MJPEG | Var; dispose var; IP sabit | Robot adresinden türet; URL değişiminde reconnect |
| /demo/* | Ayrı demo srv/msg | Var | Test / Demo etiketi, production görevden ayır |
| DockToStation / LiftLoad | marco_msgs/action | ROS mission yönetiyor | GUI action göndermeyecek; RobotStatus ile izle |

## Prompt/kaynak farkları

- FieldNode: uint64 node_id, Pose2D pose(x,y,theta); düz x/y/yaw yok.
- gate_q6 graph_model/validator'da desteklenir; FieldNode.msg yorum listesi eski.
- Enum stringleri case-insensitive; GUI mevcut uppercase wire formatını korur.
- Mission route_nodes stringleri field graph düğüm **adlarıdır**; uint64 node_id değildir.
- Mapping save boş request'tir, manager kaydı bitirip SLAM'i kapatır.
- Localization manager kayıtlı initial pose'u yükleyip INITIALIZING üzerinden AMCL'ye aktarır.
- Station config auto parse edilir ama production validator reddeder; GUI yalnız left/right sunar.
- Gate event yalnız gate_q5→gate_q6 / gate_q6→gate_q5 yönlü crossing kenarlarında gereklidir.
- Loaded edge için validator reverse ister; bu ROS kuralı GUI'de korunur.
- Aktivasyon ROS'ta mission IDLE/ERROR, mapping inaktif ve |speed|≤0.02 kontrol eder.
- Competition validator WAIT/A1–A3/B1–B3 gerektirir; GUI listeyi hard-code etmez, ROS hatalarını gösterir.
- Start boş request'tir; hazırlanmış GUI görevi yoksa ROS PLC'den görev ister. GUI production Start yalnız doğrulanmış hazır görev için açılır.
- Donanım switch/PLC wire protokolü için GUI tarafından yeni sözleşme üretilmez.

## Uygulama sonrası

- Tüm 56 RobotStatus alanı ortak `robot_status.dart` modelinde; bilinmeyen alanlar ham görünümde korunur.
- `gate_q6` parse/UI, rol çiftinden crossing metadata kontrolü tamamlandı.
- İstasyon servisleri, typed config, ortak derece dönüşümü ve ROS'a kaydet/yeniden oku akışı eklendi.
- Production görev seçimi aktif graph dock adlarından gelir; eski senaryonun local/demo fallback submit yolu kapatıldı.
- Submit, Start, Cancel, Safety Reset ve yazılımsal E-stop ortak mission state üzerinden yürür.
- Submit kabulü sonrası yeniden submit kilidi, eşleşen ROS hazır görevinden önce Start kilidi ve bağlantı epoch kontrolü eklendi.
- Graph/active/mapping/robot freshness kapıları, harita/saha eşleşmesi ve yeniden bağlantıdaki istasyon sorguları eklendi.
- Manager field adı regex'i `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`; GUI buna uyarlandı.
- Node adında ROS graph_model yalnız boş olmama ister; production node formundaki eski saha-adı kısıtı kaldırıldı.
- Kamera robot adresinden HTTP 8080'e türetilir. Dispose, adres değişimi, route örtülmesi ve uygulama arka planında akış kapanır; kare zaman aşımı gösterilir.
- Validator bütün errors/warnings için kaydırılabilir panel kullanır; güncel hash olmadan aktivasyon açılmaz.
- Eski FieldGraphId güvenli JSON tamsayı sınırı korunmuştur: 0..9007199254740991. Üretilen GUI kimlikleri bu aralıktadır; daha büyük dış kimlikler sessiz yuvarlanmaz, sözleşme hatası verir.

## ROS arayüz kısıtı

`StartMission.srv` boş request taşır. `mission_manager.py::_on_start`, hazır GUI görevi yoksa PLC assign akışına geçer. RobotStatus içinde ayrı `queued/running` alanı yoktur. GUI, submit onayı ve güncel task_id/task_source/mission_state ile Start'ı kilitler; reconnect'te mevcut backend'in `gorev kabul edildi`, elapsed=0, TASK_RECEIVED/GUI durumundan hazır görevi geri tanır. Başka istemcinin aynı anda iptal/değişiklik yapmasıyla oluşan durum yarışını boş Start request ile sunucu tarafında task_id'ye bağlamak mümkün değildir. ROS değiştirilmemiştir.
