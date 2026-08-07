# MarCO Kontrol Uygulamasi

MarCO forklift AGV'nin harita, gorev, telemetri ve manuel kontrol arayuzudur.
Uygulama Orange Pi uzerindeki ROS 2 sistemine `rosbridge` WebSocket ile baglanir.

## Hazirlik

- Flutter stable
- Windows masaustu derlemesi icin Visual Studio ve Desktop development with C++
- Orange Pi ve bilgisayar ayni Wi-Fi aginda
- Orange Pi'de ROS 2 sistemi ve rosbridge calisiyor

## Kurulum ve kontrol

```powershell
flutter pub get
flutter analyze
flutter run -d windows
```

Windows'ta eklentilerin sembolik baglantilari icin Gelistirici Modu gerekebilir.
Bu ayar kullanilmayacaksa Windows calistirma testi baska bir bilgisayarda yapilabilir.

## ROS baglantisi

Uygulamadaki baglanti alanina Orange Pi adresini girin:

```text
ws://ORANGE_PI_IP:9090
```

Son kullanilan adres uygulamada saklanir. Baglanti koparsa uygulama yeniden
baglanmayi dener ve hata nedenini olay gunlugune yazar.

Orange Pi'de once rosbridge baslatilir:

```bash
ros2 launch marco_bringup gui_bridge.launch.py
```

Uygulamadan alma-birakma test gorevi gonderilecek kontrollu testte mission
katmani su sekilde baslatilir:

```bash
ros2 launch marco_mission mission.launch.py manual_task_enabled:=true
```

`manual_task_enabled` uretim varsayilaninda guvenlik icin `false` degerindedir.
Gercek arac hareket ettirilecekse PLC, Nav2, docking, lift ve safety katmanlari
hazir olmadan sadece bu iki komuta guvenilmemelidir.

Kullanilan temel ROS arayuzleri:

- `/robot_status`: robot konumu ve durum bilgileri
- `/mission/events`: gorev olaylari
- `/mission/submit_manual_task`: haritadan gorev gonderme
- `/mission/cancel`: aktif gorevi iptal etme
- `/mission/reset_safety`: guvenlik kilidini sifirlama
- `/cmd_vel_manual`: fiziksel manuel moddaki hareket komutlari

## Harita ve gorev

Harita duzenleyicide yuk alma ve yuk birakma noktalari eklenebilir. Noktalar
`alma_1`, `alma_2`, `birak_1`, `birak_2` biciminde ROS dugumleriyle eslesir.
ROS bagliyken Senaryo butonu bu noktalardan manuel test gorevi olusturur.

## Test durumu

- `flutter analyze`: basarili
- Windows gorsel/acilis testi: bekliyor
- Orange Pi baglanti testi: bekliyor
- PLC, STM32, lift ve gercek arac testi: bekliyor

Manuel hareket testi yalnizca bos ve guvenli alanda, fiziksel E-stop hazirken ve
arac fiziksel manuel moddayken yapilmalidir.
