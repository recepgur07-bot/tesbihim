# Faz 2 Zikir Yönetimi Taslağı — 2. Bağımsız Uzman Görüşü

Tarih: 2026-07-16

İstenilen uzman kimlikleri (iOS/Swift Geliştiricisi, VoiceOver Mühendisi,
Hassas İçerik Tasarımcısı, Bildirim/İzin UX Danışmanı) kuşanılarak "Tesbihim"
Faz 2 Zikir Yönetimi taslağı (PLAN.md Bölüm 7.7, 1. uzman görüşü sonrası
kilitlenmiş hali) sakinlik/erişilebilirlik/çekirdek-işlev-ücretsiz ilkeleri
doğrultusunda incelendi.

## 1. Veri Modeli: Değişmez Kaynak + Kullanıcı Katmanı (Override)

**Değerlendirme:** Kesinlikle doğru yaklaşım. Dini metinlerde (özellikle
Arapça) yanlış bir düzenleme büyük hassasiyet yaratır; tek mutable model
"Varsayılana Sıfırla" için orijinal veriyi tekrar çekmeyi/hard-code aramayı
gerektirirdi.

**Somut öneri:** `DhikrLibrary` (statik) / `DhikrOverride` (kullanıcı
modifikasyonu) ayrımı ve ikisini birleştiren bir `ResolvedDhikr` görünümü
doğru mimari. "Varsayılana Sıfırla" butonu VoiceOver'da yalnız etiketle değil
`accessibilityHint` ile de açıklanmalı: *"Varsayılana Sıfırla, [Zikir Adı]
orijinal metnine dönecektir."*

## 2. Arşivleme / Soft Delete Yaklaşımı

**Değerlendirme:** Kısmen riskli, kullanıcı beklentisiyle çelişiyor, revize
edilmeli.

**Neden önemli:** Apple HIG eylemlerin kullanıcı beklentisiyle eşleşmesini
şart koşar; kullanıcı "Sil" dediğinde silinmesini bekler. Her şeyi arşivde
tutmak, kullanıcının kendi eklediği hatalı/deneme zikirlerinde "bunlar hâlâ
cihazımda duruyor mu?" güvensizliğine yol açar.

**Somut öneri:**
- Hazır zikirlerde mevcut yaklaşım doğru: silinemez, yalnız "Listeden
  Kaldır"/"Arşivle". VoiceOver duyurusu: *"Sübhanallah listeden kaldırıldı.
  Kütüphaneden geri getirilebilir."*
- Kullanıcının kendi eklediği (özel) zikirlerde gerçek silme (hard delete)
  doğrudan sunulmalı — veya Fotoğraflar/Notlar'daki gibi "Son Silinenler"
  (30 gün) mantığı kurulmalı. "Tüm Verilerimi Sil" tek bir hatalı kaydı
  silmek için gidilecek bir yer değil.

## 3. Bildirim İzin Akışı

**Değerlendirme:** Kusursuz, Apple'ın bağlamsal izin yönergeleriyle tam
uyumlu. Onboarding'de değil "Hatırlatıcı Ekle" anında izin istemek niyet ile
eylemi eşleştiriyor.

**Somut öneri:** `requestAuthorization(options: [.alert, .sound])`.
Reddedilme durumunda ekranda net bir buton: *"Bildirim izni kapalı. Sistem
ayarlarına gitmek için çift dokunun."* — `UIApplication.openSettingsURLString`
ile kullanıcı doğrudan ayarlara yönlendirilmeli; görme engelli kullanıcı için
manuel yol bulmak zahmetlidir, derin bağlantı hayat kurtarır.

## 4. Ses/Haptic Override ve Destekçi Paketi

**Değerlendirme:** İlkelerle çelişmiyor, doğru "premium" konumlandırma;
fallback yaklaşımı doğru.

**Somut öneri/teknik doğrulama:** Yalnızca
`CHHapticEngine.capabilitiesForHardware().supportsHaptics` kontrolü yetmez;
engine donanımsal olarak desteklense bile başlatılırken (ör. arka planda ses
çalarken/sistem kaynağı çakışmasında) "fail" edebilir — `CHHapticEngine`
başlatma `do-catch` bloğuna alınmalı. Hata/desteksizlik durumunda sessizce
`UIImpactFeedbackGenerator(style: .medium).impactOccurred()` fallback'i en
güvenli yol.

## 5. Claude'un Önerileri: Elenmesi/Tutulması Gerekenler

Uygulamanın "sakin, baskı üretmeyen" karakteri merceğinden:

- ❌ **"Bugünün Zikri" önerisi — kesinlikle elenmeli.** Pasif bile olsa bir
  "dürtme" (nudge); suçluluk hissettirmeme ilkesiyle çelişir.
- ❌ **Sessiz saatler (22:00–07:00) — elenmeli.** Faz 2'yi gereksiz şişirir;
  iOS'un Odak/Rahatsız Etme/Zamanlanmış Özet özellikleri bu işi sistem
  düzeyinde zaten yapıyor; kendi mantığımız sistem ayarlarıyla çakışabilir.
- ✅ **Bildirim gruplama — tutulmalı.** Ekstra karmaşıklık değil:
  `UNMutableNotificationContent.threadIdentifier`'a sabit bir string (ör.
  `"tesbihim_hatirlaticilar"`) atamak yeterli, kod maliyeti tek satır; kilit
  ekranını temiz tutarak sakinlik ilkesine katkı sağlar.
- ✅ **İkon/renk rozeti — tutulmalı (revizyonla).** Renk tek başına anlam
  taşımamalı kuralına uyduğu sürece dekoratif olarak değerli. VoiceOver'da
  gereksiz laf kalabalığı yaratmaması için (ör. "Mavi ikon, Sübhanallah")
  dekoratif öğe erişilebilirlik ağacından gizlenmeli
  (`accessibilityElement(children: .ignore)` benzeri).

## Özet Karar Önerisi

Veri modeli ve izin akışı mükemmel, aynen korunmalı. "Silme" mantığı hazır
zikirler (Listeden Kaldır) ve özel zikirler (Gerçek Silme/kısa süreli Son
Silinenler) olarak ikiye ayrılmalı. Premium ses yaklaşımı aynen korunmalı.
"Bugünün Zikri" ve "sessiz saatler" çöpe atılmalı; bildirim gruplama ve
ikon/renk rozeti (revizyonla) geri alınmalı.
