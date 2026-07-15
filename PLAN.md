# Tesbihim — Uçtan Uca Proje Planı

Son güncelleme: 2026-07-15 (1. checkpoint'e 2. bağımsız uzman görüşü de
alındı — uzman-gorusleri/2026-07-15-ekran-akisi-son-kontrol-2.md sonrası
Bölüm 7.1, 7.2, 7.5 revize edildi: anons güvenilirliği, buton
disabled-state kuralı, Arapça tipografi, Karşılama'da native PageControl +
görünür metin sentezi; ekran akışları kodlamaya hazır)

## 1. Vizyon

Yaşlı kullanıcıların ve VoiceOver kullanan görme engelli kullanıcıların hiç
yardım almadan kullanabileceği, sade, modern ve reklamsız bir iOS zikirmatik
(tesbih) uygulaması. Ana fark: VoiceOver açıkken standart çift-dokunma yerine,
sayma yüzeyinde tek dokunuşla art arda sayabilme ("Hızlı Sayım" modu).

Hedef kitle önceliği: (1) yaşlı kullanıcılar, (2) VoiceOver kullanıcıları,
(3) genel kullanıcılar. Tasarım kararlarında ihtilaf olursa bu sıra belirleyici.

## 2. İsim ve Marka

- Uygulama adı: **Tesbihim**
- Mağaza alt başlığı: "Herkes için kolay zikirmatik"
- Kısa vaat: "Zikrinize sakin, sade ve erişilebilir eşlik eder."
- Not: Yayına yaklaşınca Türk Patent ve Marka Kurumu + App Store ülke bazlı
  isim çakışması taraması resmi olarak yapılmalı (bu plan bunu doğrulamaz).

## 3. Teknik Yığın

- Dil/UI: Swift + SwiftUI, MVVM mimari (video recorder projesindeki
  desenle tutarlı)
- Platform: iOS, **min deployment target: iOS 17 (kesinleşti, 2026-07-15,
  proje iskeleti başlarken)** — iOS 18 varsayımı yaşlı kullanıcı kitlesinde
  gereksiz cihaz dışlaması yaratabileceği için terk edildi; iOS 17
  (2023 sonu) hem geniş cihaz desteği hem `@Observable` makrosu ve StoreKit 2
  modern API'leri için yeterli, SwiftData'ya zorunlu bağımlılık yaratmıyor
  (Faz 1'de yine de Codable+UserDefaults tercih edilir, aşağıya bakınız).
  Yeni görsel API'ler `#available` ile isteğe bağlı kullanılacak, "Liquid
  Glass" çekirdek deneyimin teknik bağımlılığı olmayacak.
- Proje üretimi: XcodeGen (`project.yml`) — commit edilen tek doğruluk kaynağı
  `.xcodeproj` değil `project.yml` olacak. **`.xcodeproj` repoda
  tutulmayacak (kesinleşti)** — `.gitignore`'a eklenir, hem yerelde hem
  CI'da `xcodegen generate` ile üretilir; tek doğruluk kaynağı her zaman
  `project.yml` kalır, gereksiz merge çatışmalarından kaçınılır. CI'da
  `xcodegen generate` + `xcodebuild test`'in başarıyla tamamlanması
  `project.yml`'in bozuk olmadığının doğrulaması sayılır.
- Dağıtım: fastlane (build numarası, TestFlight, App Store metadata)
- Yerelleştirme: tr (birincil), en (ikincil) — `InfoPlist.xcstrings` deseni
- Ödeme: StoreKit 2 (IAP) — bkz. Bölüm 8
- Persistans: **Codable + basit dosya/UserDefaults tercih edilir**
  (SwiftData iOS 17+ gerektirir; yaşlı kullanıcı kitlesinde eski
  cihaz/sürüm oranı yüksek olabileceğinden min iOS kararı netleşmeden
  SwiftData'ya bağımlı kalınmaz — min iOS sonradan 17+ çıkarsa SwiftData'ya
  geçmek CloudKit senkronizasyonunu kolaylaştırabilir, bu noktada yeniden
  değerlendirilir). Seçilen çözüm bir `CounterRepository`/`ZikirRepository`
  protokolü arkasında soyutlanacak (ViewModel'ler `ModelContext`/
  `UserDefaults`/dosya yolunu doğrudan bilmeyecek). Domain modelleri ayrı
  tanımlanacak: `DhikrDefinition` (hazır/özel, metin, dil, kaynak),
  `CounterState` (seçili zikir, hedef, güncel sayı, güncellenme zamanı,
  **son geri alınabilir delta**), `UserSettings` (geri bildirim ve
  erişilebilirlik tercihleri). Tam bir `Session`/olay geçmişi log'u MVP
  için aşırı mühendislik olur; bunun yerine `CounterState`'e tek bir
  "son delta" alanı eklenir — zaten kalıcı tutulan durumun ucuz bir
  uzantısı olduğu için maliyeti neredeyse sıfırdır ve uygulama arka planda
  sonlandırılsa bile undo'yu kaybettirmez. Ses/titreşim kararı ViewModel
  içinde değil test edilebilir bir `FeedbackProviding` arayüzünde olacak
  (haptic yoğunluğu ayarlanabilir — bkz. Bölüm 5). Min iOS 17 kesinleştiği
  için ViewModel'ler `ObservableObject` yerine `@Observable` makrosunu
  kullanır (performans/bellek avantajı). iCloud senkronizasyonu Faz 2'de
  CloudKit ile — bu aşamada saklama seçimi widget'ın kullanacağı App Group
  ile uyumlu olacak şekilde tasarlanacak.

## 4. Proje Yapısı (taslak)

```
tesbihim/
  project.yml
  Sources/TesbihimApp/
    App/                  # TesbihimApp.swift, giriş noktası
    Models/                # Zikir, Oturum, Kullanıcı Ayarları
    ViewModels/
    Views/
      Sayac/                # ana sayma ekranı
      Kutuphane/             # hazır zikir listesi
      Gecmis/
      Ayarlar/
    Accessibility/          # HızlıSayım (DirectTouch) bileşenleri, ortak a11y yardımcıları
    Store/                  # StoreKit yönetimi
    Resources/
      Assets.xcassets
      Sounds/
      InfoPlist.xcstrings
  Tests/TesbihimAppTests/
  Tests/TesbihimProjectTests/   # Xcode proje konfigürasyon testleri (video recorder'daki gibi)
  fastlane/
  uzman-gorusleri/               # bkz. Bölüm 13
  PLAN.md
```

## 5. Erişilebilirlik Gereksinimleri (asla ödün verilmeyecek liste)

- Sayma yüzeyinde **opt-in "Hızlı Sayım" modu**: `accessibilityDirectTouch(_:options:)`,
  varsayılan kapalı, açıkça VoiceOver ile duyurulan bir düğmeyle açılır/kapanır.
  Mod dışında standart VoiceOver çift-dokunma her zaman çalışır — DirectTouch
  hızlandırıcıdır, tek erişim yolu değildir (normal modda
  `accessibilityAdjustableAction` ile artır/azalt veya açık etiketli
  Say/Geri Al düğmeleri her zaman bulunacak).
- **`.requiresActivation` zorunlu.** Kullanıcı alanı önce çift dokunarak
  etkinleştirmeden dokunuşlar geçmeyecek — VoiceOver kullanıcısı yüzeyi
  keşfederken yanlışlıkla zikri artırmaz. Etkinleştirme anında kısa net
  duyuru: "Hızlı Sayım etkin. Bu alan içindeki her dokunuş bir ekler. Çıkmak
  için Hızlı Sayımı Kapat düğmesine gidin." Bu, opt-in ayarın **yerine
  geçmiyor, onu tamamlıyor** — mod hâlâ varsayılan kapalı bir kullanıcı
  tercihi, `.requiresActivation` ise o mod açıkken alan içindeki ek güvenlik
  katmanı.
- DirectTouch alanı **sadece büyük sayma yüzeyiyle sınırlı** olacak; sayı,
  hedef, geri alma ve gezinme tam ekranı kapsamayacak. Alt aksiyonlar normal
  erişilebilir kontroller olarak alanın dışında kalacak.
- **Konuşma kuyruğu yönetimi**: her tek dokunuşta sayının anons edilmesi
  VoiceOver konuşma kuyruğunu kullanılamaz hale getirir. Varsayılan kısa
  haptic/ses, kullanıcının seçebileceği aralıklı sesli duyuru (ör. her 10
  sayımda bir), hedefte anons.
- **"Mevcut durumu oku" düğmesi, DirectTouch alanının dışında.** Hızlı
  Sayım açıkken kullanıcı ekrana her dokunduğunda sayı artacağı için, anlık
  sayıyı öğrenmek isteyen kullanıcının sayıyı bir kez daha artırmaya
  zorlanmaması gerekir — sayma alanının dışında, her zaman erişilebilir
  ayrı bir "Sayıyı Okut" düğmesi bulunacak.
- **Haptic yoğunluğu ayarlanabilir** (ör. hafif/orta/güçlü) — yaşa bağlı
  parmak hassasiyeti azalması hafif titreşimleri hissetmeyi
  zorlaştırabilir.
- Dynamic Type: en büyük yazı boyutunda hiçbir içerik kesilmemeli/taşmamalı.
- Renk tek başına anlam taşımamalı (tamamlanma durumu metin/ikonla da
  anlatılmalı).
- Her interaktif elemanın kısa, bağlamdan bağımsız anlaşılır
  `accessibilityLabel`'ı olmalı; dekoratif görseller VoiceOver'dan gizlenmeli.
- İlerleme sesli okunabilmeli ("33 üzerinden 18, yüzde 55").
- **Switch Control ve Voice Control için ayrı kabul kriteri**: DirectTouch bu
  teknolojilerde doğal bir çözüm değil. Voice Control ile "Say" adlı düğme
  sesle bulunup çalışmalı; Switch Control ile sırayla odaklanıp standart
  aktivasyonla sayılabilmeli. "VoiceOver ile test edildi" bu ikisini kapsamaz.
- **Odak yönetimi**: Hızlı Sayımı etkinleştirme/bitirme, zikir değiştirme,
  hedef tamamlama ve sıfırlama onayında VoiceOver odağı mantıklı yeni öğeye
  taşınmalı; onay ekranı arkadaki sayma alanını erişilebilir bırakmamalı.
- Reduce Motion, Bold Text, Increase Contrast, Reduce Transparency, koyu/açık
  tema, Bluetooth klavye ve arka plana gidip geri gelme senaryolarıyla test.
- **Büyük sayılarda Dynamic Type taşması**: sayaç 5 haneye (10.000+)
  ulaştığında en büyük yazı boyutunda ekrana sığmama riski var —
  `minimumScaleFactor` veya `ViewThatFits` ile alt alta dizilim gibi
  fallback mekanizmaları tasarlanacak.
- **Ekran uyku moduna geçmemeli (idle timer devre dışı)**: kullanıcı fiziksel
  bir tesbih kullanıp ekrandaki metni okuyor olabilir veya dokunma
  aralıkları uzun olabilir; sayaç ekranındayken `isIdleTimerDisabled = true`
  yapılacak, bu davranış Ayarlar'da "Ekran Uyanık Kalsın" olarak isteğe
  bağlı sunulacak.
- Liquid Glass şeffaflık kaydırıcısı en uçta (ultra şeffaf) iken bile metin
  kontrastı yeterli kalmalı — tasarım incelemesinde ayrı bir kontrol maddesi.
- Gerçek VoiceOver kullanıcısı (kullanıcının kendisi) ve mümkünse yaşlı bir
  kullanıcıyla el testi — otomatik denetim (yalnızca "etiket var mı" kontrolü)
  tek başına yeterli sayılmayacak; her ekran için odak sırası, label/value/hint,
  Dynamic Type taşması ve DirectTouch giriş-çıkış davranışını içeren manuel
  test senaryoları yazılacak.

## 6. Özellik Kapsamı — Fazlar

### Faz 1 — MVP (ilk App Store sürümü)

Yol haritası (Bölüm 12) zaten Faz 1'i iki dilime ayırıyor — önce standart
erişilebilir sayaç, sonra Hızlı Sayım katmanı — bu bilinçli bir risk
azaltma sırası, DirectTouch riskini içerik/ödeme karmaşasından ayrı test
edebilmek için.

- Ana ekran: seçili zikir + hedef + büyük sayı, tek büyük sayma alanı
- Alt aksiyonlar: Geri al (undo), Zikri değiştir. **"Duraklat" belirsiz bir
  aksiyon** — sayma zaten kullanıcı dokunuşuyla ilerliyorsa neyi engellediği
  net değil; net bir semantiği tanımlanmadan MVP'ye alınmayacak (muhtemelen
  kaldırılacak).
- Hızlı Sayım modu (VoiceOver, opt-in, `.requiresActivation` ile) — ikinci
  dilim olarak eklenir
- **Sıfırlama: basılı tutma jesti kullanılmayacak.** El titremesi (tremor)
  veya motor beceri zayıflığı olan yaşlı kullanıcı için sürdürülen bir
  basılı tutma jesti zor/imkansız olabilir. Bunun yerine yeterince büyük
  (min 60x60pt), yanlışlıkla dokunmayı zorlaştıracak şekilde konumlanmış
  standart bir "Sıfırla" butonu + erişilebilir onay diyaloğu (Alert)
  kullanılacak.
- Hazır zikir kütüphanesi: namaz sonrası tesbihat, salavat, istiğfar
  (Arapça + Türkçe okunuş + anlam). **İçerik editoryel süreci tanımlanacak**:
  kaynak, sorumlu kişi, sürüm tarihi, düzeltme prosedürü — hatalı dinî metin
  sıradan bir UI hatasından daha yüksek güven kaybı yaratır.
- **Özel zikir ekleme Faz 1'den çıkarıldı, Faz 1.5/Faz 2'ye ertelendi**
  (kullanıcı kararı). Gerekçe: özel metin girişi klavye + VoiceOver klavye
  yönetimi + validasyon karmaşıklığı getiriyor; Faz 1 sadece hazır zikir
  kütüphanesi + serbest sayaçla çıkıp DirectTouch/erişilebilirlik riskini
  izole test etmek daha güvenli. Faz 1'de kullanıcı yalnızca hazır
  zikirlerden seçim yapabilir.
- Ses/titreşim/sessiz profilleri, **varsayılan sakin/hafif** (titreşim işitme
  cihazı kullanan kişiler için yorucu olabilir), hedefte ayrı geri bildirim,
  sesli geri bildirim VoiceOver konuşmasını bastırmayacak
- Kaldığı yerden otomatik devam, cihazda anında kayıt, tamamen çevrimdışı,
  **Faz 1'de tek cihaz olduğu kullanıcıya açıkça söylenecek** ("iPhone
  değiştirince zikrim kaybolur mu?" sorusuna net cevap)
- Basit geçmiş: bugün / bu hafta / toplam — **neyin sayıldığı net
  tanımlanacak** (tamamlanan hedef mi, ham tekrar mı, oturum mu), zaman
  dilimi/gece yarısı/yarım kalan oturum davranışı için tek kural; geçmişi
  ve tüm yerel veriyi silme Faz 1'de bulunacak
- Koyu tema, Dynamic Type desteği
- Reklamsız, takipsiz (analytics/reklam SDK'sı yok)
- StoreKit: Destekçi paketi (tek seferlik) + gönüllü destek IAP'leri — bkz.
  Bölüm 8
- Onboarding atlanabilir ama Hızlı Sayım/geri alma/sıfırlama mantığı
  sonradan Ayarlar dışında da (ana ekranda erişilebilir "Nasıl kullanılır?"
  bağlantısıyla) keşfedilebilir kalacak

### Faz 2 (öncelik sırası: talep varsa iCloud → widget → Watch)
- Özel zikir ekleme/düzenleme (Faz 1'den ertelendi — bkz. Faz 1 notu)
- iCloud (CloudKit) senkronizasyonu — çakışma kuralı (oturum/olay tabanlı
  birleştirme, "son yazan kazanır" sayaç için sayım kaybettirebilir),
  silinen özel zikir, ilk indirme davranışı Faz 2 başında tasarlanacak
- Ana ekran widget'ı (App Group ile uyumlu saklama; widget'ın sayımı
  doğrudan artırıp artırmayacağı — kilit ekranı/yaşam döngüsü güvenilirlik
  maliyeti yüksek — baştan karara bağlanacak)
- Apple Watch uygulaması (tek büyük sayma düğmesi) — farklı bir
  etkileşim/erişilebilirlik test matrisi gerektirir
- Sınırlı, güvenli **App Intents** ("zikri aç", "sayacı göster" gibi) —
  Voice Control/Siri erişimini güçlendirir, düşük risk
- Gelişmiş istatistik (haftalık/aylık grafik, dışa aktarma)
- Ek temalar/sesler (Destekçi paketiyle açılır)
- Esmaü'l-Hüsna ve genişletilmiş zikir kütüphanesi + sesli okuma kayıtları
- Live Activity: somut bir gerekçe çıkmadıkça ertelenir

### Faz 3 (değerlendirilecek, taahhüt yok — sadece araştırma prototipi)
- Sesle otomatik sayma (mikrofon) — yanlış pozitifler, gizlilik/izin ve
  dinî kullanım güveni riskleri nedeniyle App Intents'ten çok daha
  temkinli ele alınacak

### Bilinçli olarak kapsam dışı (v1 ve muhtemelen sonrasında)
- Liderlik tablosu, sosyal yarış, baskı üreten streak/puan sistemleri
- Ana deneyimi kapatan abonelik/paywall ekranları
- Reklamlar, herhangi bir takip SDK'sı
- Namaz vakti, Kuran, hadis, kıble gibi ayrı bir uygulama boyutuna
  dönüşebilecek modüller

## 7. Ekran Envanteri (Faz 1)

1. Sayaç (ana ekran)
2. Zikir Kütüphanesi / Zikir Seç
3. Geçmiş
4. Ayarlar (Hızlı Sayım aç/kapa, haptic yoğunluğu, "Ekran Uyanık Kalsın",
   tema, ses/titreşim profili, Destekçi paketi, gönüllü destek,
   hakkında/gizlilik, destek/düzeltme bildirimi)
5. İlk Açılış Karşılama (kısa, atlanabilir, VoiceOver ile test edilecek)

Not: "Özel Zikir Ekle-Düzenle" ekranı Faz 2'ye ertelendi.

### 7.1 Ana Sayaç Ekranı — Akış (kesinleşti, 2026-07-15)

VoiceOver odak sırası yukarıdan aşağı bu sırayla:

1. Seçili zikir adı (kısa, ör. "Sübhanallah") — dokunulabilir, Zikir Seç
   ekranına götürür. **Hedef değiştirme ayrı bir kontrol değil**: hedef,
   Zikir Seç ekranında zikirle birlikte seçilir (zikir + hedef bir arada
   tek bir "ön ayar").
2. İlerleme özeti, metin olarak: "33 üzerinden 18, yüzde 55" (renk tek
   başına anlam taşımaz).
3. Büyük sayı (dev font, `minimumScaleFactor`/`ViewThatFits` ile 5 haneli
   sayılarda taşma koruması).
4. Büyük sayma yüzeyi:
   - VoiceOver **kapalıyken**: yüzeyin kendisi de tek dokunuşla artırır
     (fiziksel tesbih hissi korunur, gören kullanıcı için ayrı bir "Say"
     butonuna basmaya zorlanmaz).
   - VoiceOver **açıkken**: yüzey Hızlı Sayım'a ayrılır (opt-in,
     `.requiresActivation`, bkz. Bölüm 5); Hızlı Sayım kapalıyken yüzey
     `accessibilityAdjustableAction` ile artır/azalt sağlar, dokunmayla
     saymaz.
5. Alt aksiyonlar (toplam 4 buton, **2×2 büyük düğme düzeni** — tek satırda
   dört sütun değil): **Say** (VoiceOver için asıl garanti sayma yolu,
   en belirgin düğme) · **Geri Al** · **Sayıyı Okut** · **Sıfırla**. Her
   düğme en az 44×44 pt (Apple HIG minimumu), tercihen Sıfırla ile tutarlı
   60 pt dokunma alanı ve düğmeler arası yeterli boşluk; en büyük Dynamic
   Type boyutunda gerçek cihazda doğrulanacak.
6. Hızlı Sayım aç/kapa kısayolu ana ekranda ayrıca yer alır (asıl ayarı
   Ayarlar ekranındadır, ama sık kullanıldığı için buradan da erişilebilir).

**Varsayılan başlangıç durumu (ilk açılış, uzman görüşü sonrası eklendi):**
uygulama daha önce hiç zikir seçilmemişse Sayaç ekranı **"Serbest Sayaç,
hedefsiz"** ile açılır — belirli bir zikri varsayılan seçmek kullanıcının
dinî tercihine varsayım yüklemek olur, bu yüzden nötr başlangıç tercih
edildi. Bu durum VoiceOver'da ilk odakta açıkça okunur ("Serbest Sayaç
seçili, hedef yok"). Sonraki açılışlarda her zaman son bırakılan durumdan
devam edilir (Bölüm 6'daki "kaldığı yerden otomatik devam" ilkesi).

**Hedef tamamlama davranışı (uzman görüşü sonrası eklendi, kesin kural):**
hedefe ulaşıldığında bir "hedef tamamlandı" kaydı oluşur ve sayaç 0'dan
yeni bir tura başlar (33/33 → "33 tamamlandı; yeni tur 0" kısa duyurusu,
ardından sayaç 0'da bekler). Her artış tek adım olduğundan bir dokunuş en
fazla bir hedefi tamamlayabilir. **Geri Al**, son artışı geri alır; bu
artış bir hedefi tamamlamışsa ilgili tamamlanmış-hedef kaydı da geri
alınır (sayaç 0'dan hedefin bir eksiğine döner, tamamlanma sayısı bir
azalır). Bu kural Sayaç, Geri Al ve Geçmiş (Bölüm 7.3) ekranlarının aynı
veriyi tutarlı yorumlamasını sağlar.

**Anons güvenilirliği ve buton durumları (2. uzman görüşü sonrası
eklendi):**
- Hedef tamamlama anonsu düz `String` yerine `NSAttributedString` +
  `UIAccessibilitySpeechAttributeQueueAnnouncement` özniteliğiyle
  gönderilir — bu, anonsun **mevcut konuşmayı kesmeden kuyruğa girmesini**
  sağlar (VoiceOver'da bir anonsun *sonradan* kesilmeyeceğine dair mutlak
  bir garanti yok, ama bu öznitelik riski azaltan doğru pratik).
- Büyük sayaç elementine `accessibilityTraits.insert(.updatesFrequently)`
  eklenir — Hızlı Sayım'da sık değişen değeri Switch Control gibi
  teknolojilere doğru bildirmek için.
- **Geri Al**, geri alınacak bir delta yokken; **Sıfırla**, sayaç zaten
  0 iken `.disabled(true)` olur (Apple HIG "aksiyon geçersizse butonu
  devre dışı bırak" ilkesi) — VoiceOver bunu otomatik olarak "soluk/pasif
  düğme" (`NotEnabled` trait) şeklinde okur, ayrı bir etiket işi gerekmez.

### 7.2 Zikir Kütüphanesi / Zikir Seç Ekranı — Akış (kesinleşti, 2026-07-15)

- Liste, `List`/`Form` ile bölümlenmiş: "Namaz Sonrası Tesbihat", "Salavat",
  "İstiğfar" kategori başlıkları + en üstte ayrı bir **"Serbest Sayaç"**
  satırı (hedefsiz, sadece sayar — özel zikir metni girişi olmadan da
  esneklik sağlar, Faz 1'den ertelenen "özel zikir ekleme" ihtiyacının bir
  kısmını karşılar). Kategori başlıkları native section header olduğu için
  VoiceOver "Başlıklar" rotor'uyla doğrudan atlanabilir.
- Her satır **tek bir erişilebilir eleman** olarak birleştirilir
  (`accessibilityElement(children: .combine)`): zikir adı + kısa anlam
  önizlemesi + varsayılan hedef ("Sübhanallah, 33 hedef"). İpucu (hint):
  "Seçmek için çift dokunun." Seçili olan zikir hem görsel işaretle
  (onay simgesi) hem `accessibilityValue` = "Seçili" ile belirtilir —
  renk tek başına taşıyıcı olmayacak kuralı burada da geçerli.
- Satıra dokunmak **"Zikir Detayı"** alt ekranına götürür (tam Arapça +
  Türkçe okunuş + anlam + kaynak/sürüm bilgisi + hedef ayarlayıcı).
  Push sonrası VoiceOver odağı otomatik başlığa taşınır
  (`UIAccessibility.post(.screenChanged, ...)`).
- **Hedef ayarlayıcı**: `Stepper` benzeri, `accessibilityAdjustableAction`
  ile yukarı/aşağı kaydırarak değiştirilir (uzun basma yok), her değişiklikte
  yeni değer VoiceOver'a `accessibilityValue` olarak anons edilir (ör.
  "Hedef: 41"). Min/maks sınır (1–9999) dışına çıkılamaz, sınırda anons:
  "En düşük değer" / "En yüksek değer".
- Ekranın altında tek, açık etiketli bir **"Bu Zikri Seç"** butonu — hedef
  değişikliği anlık uygulanmaz, kullanıcı bu butonla onaylayınca Sayaç
  ekranına döner ve odak yeni seçili zikir başlığına taşınır. Bu, yanlışlıkla
  swipe sırasında bir zikri seçip geri dönememe riskini engeller.
- **Dil etiketleme**: her satırdaki Arapça metin parçasına ayrı
  `accessibilityLanguage("ar")`, Türkçe okunuş/anlam kısmına `"tr"` atanır
  — VoiceOver'ın Arapça harfleri yanlış dilde (İngilizce/Türkçe fonetik)
  okumasını önlemek için zorunlu, sık atlanan bir detay.
- **Arapça metin görsel okunaklılığı (2. uzman görüşü sonrası eklendi)**:
  standart satır aralığı Arapça harekelerin (diakritik işaretler) net
  görünmesi için yetersiz kalabilir — Arapça `Text` bileşenlerinde
  `lineSpacing` Türkçe/İngilizce metne göre biraz daha açık tutulur ve
  Arapça kısmın varsayılan Dynamic Type başlangıç boyutu (ör. `.title2`)
  Türkçe okunuşa göre bir kademe büyük seçilir.
- Editoryel künye: Zikir Detayı ekranında küçük, gizlenebilir bir "Kaynak"
  satırı (kaynak metin, sorumlu kişi, sürüm tarihi) — bkz. Bölüm 6 Faz 1
  "içerik editoryel süreci" maddesi; içerik yanlışsa Ayarlar'daki "Hata
  Bildir" akışına doğrudan bağlanır (o zikrin adı otomatik ön dolu gelir).

### 7.3 Geçmiş Ekranı — Akış (kesinleşti, 2026-07-15)

Neyin sayıldığı kararı: **hem ham tekrar toplamı hem tamamlanan hedef
sayısı**, ikisi birlikte gösterilir (biri diğerini gizlemez).

- Üç kart, dikey sırayla: **Bugün / Bu Hafta / Toplam**. Her kart tek
  erişilebilir blok (`combine`): "Bugün: 3 hedef tamamlandı, toplam 247
  tekrar." Gün sınırı cihazın yerel saat dilimine göre gece yarısında
  döner (basit kural, ileri saat dilimi/DST karmaşasına girilmez).
- Veri modeli: mevcut `CounterState`'e ek olarak günlük agregasyon tutan
  hafif bir `HistoryEntry` (tarih, zikirId, eklenen miktar, hedef
  tamamlandı mı) — tam olay/oturum log'u değil, sadece gün bazlı toplama
  yetecek minimum kayıt (Bölüm 3'teki "aşırı mühendislik olmasın" ilkesiyle
  tutarlı).
- Kartların altında, kapalı başlayan bir **"Zikire Göre Dökümü Gör"**
  açılır bölüm (disclosure) — Faz 1'de basit tutulur, varsayılan kapalı,
  VoiceOver'a "Daraltılmış/Genişletilmiş" durumu `accessibilityValue` ile
  bildirilir.
- İki ayrı, açık etiketli, birbirine karıştırılmayacak buton: **"Geçmişi
  Sil"** (sadece geçmiş kayıtları) ve **"Tüm Verilerimi Sil"** (geçmiş +
  tüm zikir sayaç durumları — geri dönüşü olmayan tam sıfırlama). İkisi de
  Alert ile onay ister; Alert açıklaması net farkı söyler ("Bu işlem geri
  alınamaz"); onay sonrası odak ekranın başlığına döner.
- **Değerlendirme istemi (App Store review prompt) — düzeltildi (uzman
  görüşü sonrası)**: hedef tamamlanmasının **doğrudan sonucu olarak**
  tetiklenmeyecek — Apple bunu kullanıcı eylemini kesmeme ve istemi bir
  eylemin doğrudan sonucu gibi göstermeme konusunda açıkça uyarıyor
  (WWDC22 "Increase engagement with review requests"), ayrıca "Say"
  dokunuşunun hemen ardından gelecek bir sistem modalı VoiceOver
  duyurusunu ("33 tamamlandı; yeni tur 0") kesip sakin deneyimi bozar.
  Bunun yerine: yalnızca **sonraki bir uygulama açılışında**, kullanıcı
  sayaçla henüz etkileşime girmeden önce, seyrek bir uygunluk kuralıyla
  (ör. en az bir hedef daha önce tamamlanmışsa ve son istekten belirli bir
  süre geçmişse) SwiftUI'nin güncel `requestReview` ortam eylemi
  çağrılabilir. Kesin uygunluk kuralı kodlama aşamasında netleştirilecek;
  bu madde Faz 1'de zorunlu değil, düşük öncelikli bir iyileştirme.

### 7.4 Ayarlar Ekranı — Akış (kesinleşti, 2026-07-15)

`Form` ile bölümlenmiş, iOS Ayarlar uygulamasının tanıdık desenine uygun
(VoiceOver kullanıcıları için zaten öğrenilmiş bir gezinme modeli):

1. **Sayma ve Erişilebilirlik**: Hızlı Sayım aç/kapa (toggle) + yanında
   "Nasıl çalışır?" bağlantısı (kısa açıklama sayfası, onboarding'deki
   metnin aynısı); Haptic Yoğunluğu (Hafif/Orta/Güçlü, segmented — VoiceOver
   `accessibilityAdjustableAction` ile de değiştirilebilir); Ekran Uyanık
   Kalsın (toggle).
2. **Görünüm**: Tema (Sistem/Açık/Koyu). Dynamic Type için ayrı kontrol
   **yok** — sadece bilgi metni (uzman görüşü sonrası düzeltildi, doğru
   yol erişilebilirlik boyutlarını da kapsıyor): "Yazı boyutunu değiştirmek
   için iPhone Ayarları → Erişilebilirlik → Ekran ve Metin Boyutu → Daha
   Büyük Metin." Ekranın en büyük erişilebilir boyutta test edildiği
   uygulama içi kısa yardım metninde de belirtilir.
3. **Ses**: Ses/Titreşim Profili (Sessiz/Hafif/Normal).
4. **Destek**: Destekçi Paketi, Gönüllü Destek — ayrı bir "Destek" alt
   ekranına götürür (bkz. Bölüm 8: güven metni, üç fiyat basamağı,
   Restore Purchases burada).
5. **Veri**: Geçmişi Sil / Tüm Verilerimi Sil (Bölüm 7.3'teki aynı
   aksiyonlara kısayol, tekrar ayrı ayrı onay ister).
6. **Hakkında**: Sürüm numarası, Gizlilik Politikası (harici link),
   Destek/Düzeltme Bildirimi (mail formu, zikir içeriği hatası burada da
   bildirilebilir), "Nasıl Kullanılır?" (onboarding'i yeniden oynat).

Her bölüm başlığı native section header (Rotor "Başlıklar" ile atlanır).
Hiçbir ayar uzun basmayla açılmaz/değişmez.

### 7.5 İlk Açılış Karşılama — Akış (kesinleşti, 2026-07-15)

- En fazla 3 sayfa: (1) kısa vizyon cümlesi + uygulama adı, (2) Hızlı
  Sayım'ın ne olduğu ve **varsayılan kapalı, opt-in** olduğu bilgisi
  (burada açılmaz, sadece bilgilendirir), (3) "Başla" → doğrudan Sayaç
  ekranı.
- **İlerleme yolu, açık birincil düğmeyle**: yatay kaydırmaya/adjustable
  jestine tek başına güvenilmez — Switch Control ve klavye kullanıcıları
  için yeterli değil. Her sayfanın altında sabit, büyük bir birincil
  düğme: 1. ve 2. sayfada **"Devam"**, 3. sayfada **"Başla"**.
- Üstte her sayfada sabit, her zaman erişilebilir **"Atla"** butonu.
- **Sayfa göstergesi — sentezlendi (2. uzman görüşü sonrası)**: native
  `TabView(selection:) { ... }.tabViewStyle(.page)` (standart PageControl)
  geri getirildi — VoiceOver bunu native olarak "Sayfa 1/3, ayarlanabilir"
  şeklinde okur ve kullanıcının zaten aşina olduğu bir kalıptır (Apple
  HIG Page Controls); önceki "1/3 metin, PageControl yok" kararının
  gerekçesi ("nokta gösterge belirsiz kalıyor") yeterince temellendirilmemişti,
  düzeltildi. Ama bununla birlikte **büyük, görünür bir "1 / 3" metin
  etiketi de ekranda kalır** — az gören, VoiceOver kullanmayan yaşlı
  kullanıcı için küçük noktalar tek başına yetersiz kalabilir. Üç mekanizma
  (native PageControl + görünür metin + Devam/Başla düğmesi) birbirini
  dışlamaz, farklı kullanıcı gruplarına hizmet eder.
- Sayfa geçişinde VoiceOver odağı yeni sayfanın başlığına taşınır. Reduce
  Motion açıkken sayfa geçiş animasyonu (crossfade/kaydırma) basit bir
  anlık geçişe indirilir.
- Hiçbir izin isteği yok (kamera/mikrofon/konum/bildirim kullanılmıyor) —
  Apple açısından ek bir izin ekranına gerek yok, teyit edildi.

### 7.6 Tüm Ekranlara Uygulanan Ortak Erişilebilirlik Kuralları

- **Uzun basma (long press) hiçbir yerde birincil aksiyon olarak
  kullanılmaz** — Bölüm 6'daki sıfırlama kararının genellemesi; el titremesi/
  motor beceri zayıflığı olan kullanıcı için sürdürülen bir jest her zaman
  riskli kabul edilir. Liste satırı silme gibi standart `swipeActions`
  kullanılan yerlerde (ör. Faz 2 özel zikir listesi), VoiceOver'da swipe
  jesti gizli kalabileceğinden her swipe action'ın **görünür, açık
  etiketli bir buton karşılığı** olacak.
- **Odak yönetimi — daraltıldı (uzman görüşü sonrası)**: sistemin
  varsayılan VoiceOver odağı yanlış/belirsiz kaldığında manuel taşınır,
  her geçişte kör kör bildirim gönderilmez (aşırısı odağı beklenmedik
  sıçratıp konuşmayı kesebilir). Doğru bildirim türü duruma göre seçilir:
  yeni tam ekran/push için `.screenChanged`, aynı ekranda içerik
  değişimi (disclosure açma, satır silme) için `.layoutChanged`, Karşılama
  sayfa geçişinde `.pageScrolled`. Alert kapanınca odak mümkünse eylemi
  başlatan düğmeye döner; **istisna**: tüm veriler silindiğinde (Bölüm 7.3
  "Tüm Verilerimi Sil") ekran başlığına dönülür, çünkü tetikleyen düğmenin
  bağlamı artık geçerli değildir.
- **Destructive aksiyonlar** (sil, sıfırla) her zaman Alert ile onay ister;
  Alert'te "İptal" ayrı, net biçimde ayırt edilir.
- **Rotor**: Faz 1'de özel rotor gerekmiyor — sistem rotor'larının
  (Başlıklar, Ayarlanabilir Öğeler, Bağlantılar) her ekranda doğru
  çalışması yeterli kabul kriteri. Özel rotor (ör. Geçmiş'te zikre göre
  filtre) Faz 2'de değerlendirilir.
- **Bold Text / Increase Contrast / Reduce Transparency**: özellikle
  Liquid Glass şeffaflık ve kart arkaplanlarında (Bölüm 5, Bölüm 9) her
  ekranda ayrı test edilir.
- **Bluetooth klavye / Full Keyboard Access**: Tab/ok tuşlarıyla gezinme
  ve Enter ile aktivasyon her ekranda çalışmalı, VoiceOver kapalıyken de.
- **Dil etiketleme**: Arapça içerik geçen her yerde (Zikir Seç, Zikir
  Detayı, Sayaç'ta zikir adı) metin parçalarına doğru `accessibilityLanguage`
  atanır (Bölüm 7.2).

## 8. Monetizasyon Uygulama Detayı

Apple App Review Guidelines'ı doğrudan kontrol ettim. **Düzeltme**: bahşiş/
destek niteliğindeki ödeme için asıl referans **3.1.1** ("Apps may use
in-app purchase currencies to enable customers to tip"); **3.2.1(vi)**
yalnızca Apple onaylı, kâr amacı gütmeyen kuruluşların bağış toplama
istisnasını kapsar — bizim durumumuz bu değil. Bu yüzden arayüzde "bağış"
veya hayır kurumu çağrışımı değil **"Geliştiriciyi destekle"** dili
kullanılacak. Her iki ödeme türü de Apple'ın kendi In-App Purchase sistemi
üzerinden olmak zorunda, harici bir ödeme linkiyle olamaz.

- **Destekçi paketi**: tek seferlik, tüketilmeyen (non-consumable) IAP.
  Lansmanda içeriği **açıkça ve somut olarak listelenmiş** olacak (belirsiz
  "ileride ek temalar/sesler" vaadiyle satılmayacak — ya lansmanda listelenen
  küçük kozmetik öğelerle çıkar ya da IAP tamamen Faz 2'ye ertelenir).
  Fiyat artışını **kullanıcı sayısına bağlamayacağız** (yapay kıtlık/acele
  baskısı izlenimi verir, ürünün sakin karakteriyle çelişir); fiyat
  güncellenirse mevcut sahiplerin erişimi etkilenmeyecek şekilde şeffaf
  yapılır. Türkiye fiyatları lansman öncesi App Store Connect'te doğrulanır.
- **Gönüllü destek**: tüketilebilir (consumable) IAP, üç fiyat basamağı
  (₺49,99 / ₺99,99 / ₺249,99), hiçbir özellik kilidi açmaz. Consumable
  olduğu için Restore Purchases ile yeniden teslim edilecek bir hak vaat
  edilmeyecek (bu sadece non-consumable Destekçi paketi için geçerli).
- **Restore Purchases zorunlu**: Ayarlar'da açık "Satın Alımları Geri Yükle"
  bulunacak; non-consumable entitlement uygulama açılışında doğrulanacak,
  transaction güncellemeleri dinlenecek (StoreKit transaction observer).
- **Güven metni**: IAP ekranındaki düğmelerin `accessibilityLabel`'larına
  "Bu isteğe bağlı bir destektir, uygulamayı değiştirmez" gibi net bir
  açıklama eklenecek — yaşlı/görme engelli kullanıcıların IAP ekranında
  yanlışlıkla para harcama korkusunu azaltmak için.
- Apple Small Business Program'a başvurulacak (yıllık ciro $1M altındaysa
  komisyon %30 yerine %15).
- Paywall/destek ekranı ilk açılışta gösterilmez; ilk zikir tamamlandıktan
  sonra veya Ayarlar'dan erişilir. Dil: "reklamsız kalmasına destek olun" —
  "Premium'a geç" değil. Tekrar eden tam ekran istek, geri sayım veya
  suçluluk dili kullanılmayacak; destek sonrası kısa bir teşekkür yeterli.
- Çekirdek işlevler (sayaç, Hızlı Sayım, temel kütüphane, geçmiş, reklamsızlık)
  hiçbir zaman ücret duvarının arkasında olmayacak.

## 9. iOS 27 / Liquid Glass Hazırlığı

**Not**: Aşağıdaki SDK/sürüm/tarih iddiaları (iOS 27, Xcode 27, Nisan 2027
zorunlu gönderim tarihi) kesin gerçek olarak projeye kilitlenmeyecek —
Apple'ın o günkü SDK/sürüm kuralları yayın zamanında Apple Developer News'ten
doğrulanacak "platform politikası" maddesi olarak ele alınacak. Mimari
kararlar bu tarihe bağımlı yapılmayacak.

- Xcode 27 SDK ile geliştirme, `.glassEffect()` / `GlassEffectContainer`
  kullanımı, özel nav/tab bar stillendirmesinden kaçınıp mümkün olduğunca
  standart sistem bileşenleri
- **Düzeltildi (proje iskeletinde doğrulandı, 2026-07-15)**: saf SwiftUI
  `@main App` yaşam döngüsü kullanan Tesbihim için `UIApplicationSceneManifest`
  Info.plist anahtarı **gerekli değil** — bu uyarı UIKit
  `AppDelegate`/`SceneDelegate` tabanlı projeler için geçerliydi, yanlışlıkla
  genellenmişti. Proje iskeleti build+test edildi, anahtar olmadan normal
  çalışıyor. Widget/App Intents gibi Faz 2 uzantıları eklenirken bu konu
  o uzantının kendi hedefi için ayrıca değerlendirilecek.
- VoiceOver Image Explorer / Voice Control doğal dil gibi Apple Intelligence
  destekli yenilikler dikkate alınacak ama bunlar **doğru accessibilityLabel
  vermenin yerine geçmez** — açık etiketleme zorunluluğu devam ediyor

## 10. Test Stratejisi

- Birim testleri: ViewModel mantığı (sayaç, hedef, undo, geri bildirim
  tetikleyicileri)
- Proje konfigürasyon testleri: video recorder'daki
  `XcodeProjectConfigurationTests.swift` deseni — Info.plist, entitlements,
  scheme doğrulamaları
- Erişilebilirlik testleri: mümkün olduğunca otomatik (accessibilityLabel
  varlığı, Dynamic Type snapshot) + zorunlu manuel VoiceOver testi
- StoreKit testleri: StoreKit Configuration dosyasıyla yerel test

## 11. Yayın Süreci

- fastlane ile build numarası artırma, TestFlight dahili test
- App Store Connect gizlilik bildirimleri (PrivacyInfo.xcprivacy — reklam/takip
  yok olduğu için minimal veri toplama beyanı). "Takipsiz" vaadi teknik
  olarak yazılacak: ağ isteği var mı, crash raporlama var mı, iCloud
  açılınca hangi veriler senkronize olur, yerel veriler nasıl silinir.
  Gizlilik politikası ve destek e-postası Faz 1 yayın kontrol listesinde.
- Türkçe öncelikli mağaza metni, İngilizce ikincil
- **App Review notu**: incelemeciye Hızlı Sayım ayarının yeri, varsayılanının
  kapalı olduğu, `.requiresActivation` koruması ve normal VoiceOver sayma
  yolunun bulunduğu kısa bir açıklama; IAP ürünlerine uygulamada nereden
  erişildiği de not edilecek. Apple'ın bu spesifik erişilebilirlik
  kullanımını ilk bakışta "standart dışı" bulup reddetme riskine karşı,
  App Review Information notlarına Hızlı Sayım'ın VoiceOver deneyimini
  nasıl iyileştirdiğini gösteren kısa (30-40 saniyelik) bir video linki
  eklenmesi değerlendirilecek.
- **Destek/düzeltme kanalı**: yanlış metin/çeviri bildirme, erişilebilirlik
  geri bildirimi ve satın alma sorunları için görünür bir destek
  e-postası/formu.
- **Hata dayanıklılığı**: sayma dokunuşundan sonra kalıcı yazma başarısız
  olursa, uygulama sonlandırılırsa, ses/titreşim kaynağı yoksa veya StoreKit
  ürünleri yüklenemezse görülecek davranış tasarlanacak — sayaç hiçbir zaman
  sessizce geriye gitmeyecek, başarısızlıkta anlaşılır erişilebilir uyarı
  verilecek.

### Yayın kapısı (App Store'a göndermeden önce üçü birden sağlanmalı)

1. VoiceOver açıkken normal sayma, Hızlı Sayım etkinleştirme/kapatma, geri
   al, sıfırla, zikir değiştirme ve satın alma geri yükleme sadece
   erişilebilir kontrollerle tamamlanabiliyor.
2. En az bir gerçek VoiceOver kullanıcısı ve bir yaşlı kullanıcı, yardım
   almadan ilk sayaçtan hedef tamamlamaya kadar akışı deniyor; yanlış sayım
   ve kafa karışıklığı gözlemleri kapatılıyor.
3. StoreKit'te non-consumable entitlement, Restore Purchases, iptal/bekleyen
   işlem ve ürünlerin yüklenememesi senaryoları cihazda test edilmiş; IAP
   açıklamaları uygulamadaki gerçek değerle bire bir uyumlu.

## 12. Yol Haritası — Aşama Sırası

Bu belge (PLAN.md) **tek seferde, uçtan uca** yazıldı — çünkü dış
uzmanlardan görüş alınacak (bkz. Bölüm 13) ve onların bütünü görüp tutarlı,
mimariyi de kapsayan geri bildirim verebilmesi için parça parça değil tam
resim gerekiyor.

**Ama uygulamanın kendisi (kodlama) faz faz ilerleyecek**, tek seferde her şeyi
inşa etmeyeceğiz:

1. Proje iskeleti (XcodeGen, boş hedefler, CI/test altyapısı)
2. Sayaç ekranı + veri modeli (zikir çekmenin çekirdek deneyimi)
3. Hızlı Sayım / erişilebilirlik katmanı
4. Zikir kütüphanesi (hazır zikirler; özel zikir ekleme Faz 2'de)
5. Geçmiş + ayarlar
6. StoreKit entegrasyonu
7. Cilalama: tema, ses, Liquid Glass detayları
8. TestFlight'a çıkış, gerçek kullanıcı (yaşlı + VoiceOver) testi
9. App Store gönderimi

Her aşama sonunda kısa bir durak noktası olacak: çalışan bir şey gösterip
onay alıp bir sonrakine geçeceğiz — büyük patlama entegrasyonundan kaçınmak
ve erken hata yakalamak için.

## 13. Dış Uzman Görüşleri Süreci

`uzman-gorusleri/` klasörü altında her görüş kendi dosyasında tutulacak
(örn. `2026-07-15-gorus-1.md`). Ben (Claude) bu klasördeki her yeni dosyayı
okuyup mevcut plana karşı değerlendireceğim: hangi noktalar doğrulanabilir
kaynakla teyit ediliyor, hangileri çelişiyor, hangisi benimsenmeli. Plan
güncellemeleri bu değerlendirmeden sonra PLAN.md'ye işlenecek.

### 13.1 Uzman Görüşü Alma Aşamaları

Her adımda dış görüş almak gürültü yaratır (aynı ilkeleri tekrar tekrar
onaylatmak); bunun yerine **büyük, geri dönüşü pahalı kararların kilitlendiği**
noktalarda alınacak:

1. **[TAMAMLANDI — 2026-07-15] 5 ekranın tamamının somut akışı kilitlendi ve
   iki bağımsız uzman görüşüyle son kontrolden geçti**
   (Bölüm 7.1–7.6: Sayaç, Zikir Seç, Geçmiş, Ayarlar, Karşılama + ortak
   erişilebilirlik kuralları).
   - Görüş 1: `uzman-gorusleri/2026-07-15-ekran-akisi-son-kontrol.md` — 7
     maddenin 7'si kabul (Karşılama'da açık "Devam"/"Başla" düğmesi, ilk
     açılışta varsayılan "Serbest Sayaç" durumu, hedef tamamlama/geri alma
     kesin kuralı, alt aksiyonlarda 2×2 düzen + 44pt minimum,
     `screenChanged`/`layoutChanged`/`pageScrolled` ayrımı, review
     prompt'un hedef tamamlamayla doğrudan tetiklenmemesi, Dynamic Type
     yönlendirme metninin düzeltilmesi).
   - Görüş 2: `uzman-gorusleri/2026-07-15-ekran-akisi-son-kontrol-2.md` —
     4 maddenin 3'ü doğrudan, 1'i (Karşılama sayfa göstergesi) sentezle
     kabul (anons güvenilirliği için `SpeechAttributeQueueAnnouncement` +
     `updatesFrequently` trait, Geri Al/Sıfırla için disabled-state
     kuralı, Arapça metinde geniş satır aralığı + bir kademe büyük
     Dynamic Type, native PageControl'ün görünür "1/3" metni ve
     Devam/Başla düğmesiyle birlikte geri getirilmesi).
   Artık kodlamaya (Bölüm 12 adım 1) geçilebilir.
2. **Faz 1 MVP kod tamamlanınca, TestFlight'a çıkmadan önce** (Bölüm 12
   adım 6→7 arası). Girdi: çalışan build'den ekran görüntüleri/kısa ekran
   kaydı + kod değil, davranış odaklı özet. Odak: tasarlanan akışla
   gerçek uygulanan davranış örtüşüyor mu, VoiceOver testinde kaçan bir
   şey var mı.
3. **App Store gönderiminden hemen önce** (Bölüm 12 adım 9, Bölüm 11
   yayın kapısı ile birlikte). Odak: Apple guideline uyumu (IAP dili,
   gizlilik beyanı, App Review notu), önceki iki turun kapsamadığı
   "compliance" riski.
4. **Faz 2 başlarken**, iCloud senkron çakışma kuralı ve widget'ın sayımı
   doğrudan artırıp artırmayacağı kararları netleşmeden önce — bunlar
   Faz 1'de bilerek ertelenmiş, geri dönüşü nispeten pahalı mimari
   kararlar.

Her turdan sonra görüş dosyası her zamanki gibi değerlendirilip kabul/red
gerekçesiyle ilgili bölüme işlenecek; bu alt bölüm (13.1) yeni bir tur
tamamlandıkça hangi aşamaların yapıldığı işaretlenerek güncellenecek.

### 13.2 Uzman Görüşü Talimat Şablonu

Aşağıdaki şablon, checkpoint'lerden birine gelindiğinde başka bir yapay
zeka aracına (farklı bir model/araç kullanmak, aynı körlüğü tekrarlamamak
için tercih edilir) kopyala-yapıştır olarak verilecek. `{{...}}` alanları
o anki aşamaya göre doldurulacak.

```
Sen deneyimli bir iOS/Swift geliştiricisi, VoiceOver erişilebilirlik
mühendisi ve ürün tasarımcısı gibi davran. Ekli PLAN.md dosyası, görme
engelli (VoiceOver kullanan) bir geliştiricinin yaptığı "Tesbihim" adlı
iOS zikirmatik uygulamasının uçtan uca planı. Hedef kitle önceliği:
(1) yaşlı kullanıcılar, (2) VoiceOver kullanıcıları, (3) genel
kullanıcılar — ihtilaflarda bu sıra belirleyici.

Şu an odaklanılan aşama: {{örn. "5 ekranın somut akışı/etkileşimi
kilitlendi, kodlamaya geçmeden önce son kontrol" / "MVP kod tamamlandı,
TestFlight öncesi" / "App Store gönderim öncesi compliance" / "Faz 2
iCloud/widget mimari kararları"}}

Lütfen şuna göre eleştir:
- Körü körüne onaylama; somut, gerekçeli, mümkünse doğrulanabilir bir
  kaynağa (Apple dokümantasyonu, HIG, App Review Guidelines, WWDC) dayanan
  geri bildirim ver.
- Sadece bu aşamayla ilgili konulara odaklan, daha önce kilitlenmiş
  kararları (bkz. PLAN.md'de "kesinleşti" işaretli maddeler) yeniden
  tartışmaya açma — geçerli bir çelişki/hata bulmadıkça.
- Her madde için: ne eksik/yanlış, neden önemli, somut öneri.
- Kapsam dışına taşma: bu bir sağlık/finans/hukuk uygulaması değil, basit
  bir zikirmatik; öneriler ürünün sade/sakin karakteriyle orantılı olsun.

Çıktını normal düz metin veya markdown olarak ver, ben bunu
`uzman-gorusleri/YYYY-MM-DD-kisa-baslik.md` olarak kaydedip
değerlendireceğim.

{{buraya PLAN.md içeriği ya da ilgili bölümler + varsa ekran görüntüsü/
akış özeti eklenecek}}
```
