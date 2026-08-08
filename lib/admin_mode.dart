/// ============================================================
/// GEÇİCİ ADMIN MODU
/// ------------------------------------------------------------
/// Cihaza (AGV'ye) bağlanmadan, normalde bağlantı gerektiren tüm
/// sayfaların açılabilmesi için eklendi. Amaç: rapor için ekran
/// görüntüsü almak.
///
/// TODO(kaldır): Rapor tamamlandıktan sonra:
///   1. Bu dosyayı sil.
///   2. `import 'admin_mode.dart';` satırlarını sil.
///   3. `|| kAdminMode` / `&& !kAdminMode` koşullarını eski hâline döndür.
/// ============================================================
const bool kAdminMode = true;
