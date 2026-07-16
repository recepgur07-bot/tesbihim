# Sayaç Ekranı — Sayma Alanı Revizyonu (Karar Taslağı)

Tarih: 2026-07-15
Durum: **Uygulandı (kod tarafı) — Hızlı Sayım baştan tasarlandı, artık
ham dokunuş/`allowsDirectInteraction` YOK, VoiceOver'ın standart odak+
çift-dokunuş modeli kullanıyor (Bölüm 10).** Bölüm 5'teki
değişiklikler koda işlendi ve testler geçti. Ek olarak, cihazda ilk
denemeden sonra gelen geri bildirimle **Bölüm 6** eklendi: "Sayıyı Sesli
Söyle" ayarı — çift dokunuşta VoiceOver'ın sayıyı sesli okumasını isteğe
bağlı olarak titreşim+ses efektiyle değiştiriyor. **Bölüm 6.4**:
DirectTouch temizliğinin yarım kaldığı (Magic Tap ile açılan eski
`HizliSayimYuzeyi` hâlâ canlıydı) bulundu ve tamamen silindi. **Bölüm
7**: kullanıcı tek dokunuşlu Hızlı Sayım'ı özellikle istediğini
belirtti; eski tasarımın güvenilmezlik kaynağı olan "ekran içi belirsiz
çıkış jesti" kaldırılıp sabit bir "Kapat" düğmesi eklendi, sonra Bölüm
7.4'te açma/kapama tekrar Sihirli Dokunuş'a (ekranın her yerinde)
taşındı, Kapat düğmesi yedek kaldı. **Bölüm 8-9**: kaydırmanın "Sayıyı
Sesli Söyle" kapalıyken bile geriden gelmeye devam ettiği kanıtlandı
(kullanıcının kontrollü deneyiyle); kök neden VoiceOver'ın kendi jest
dağıtımı olduğu için uygulama koduyla düzeltilemeyeceğine karar verildi,
**kaydırma özelliği tamamen kaldırıldı** — gerçek hızlı sayım için
VoiceOver'ı tamamen atlayan Hızlı Sayım (Bölüm 7) tek yöntem olarak
kaldı. Kapsam: Sadece Ana Sayaç ekranındaki sayma
alanı ve alt aksiyon
düğmeleri (PLAN.md Bölüm 7.1'i günceller). Diğer ekranlar etkilenmiyor.

Bu belge, gerçek cihazda VoiceOver ile yapılan denemeler sonrası ortaya
çıkan sorunları ve üzerinde konuşarak vardığımız kararları tek yerde
topluyor. Aile ile konuşulduktan sonra son hali PLAN.md'ye işlenecek ve
kodlama buna göre yapılacak.

## 1. Neden değişiyor

- Mevcut "Hızlı Sayım" (DirectTouch: çift dokun → etkinleştir → tek tek
  dokunarak ilerle) gerçek cihazda VoiceOver ile güvenilir çalışmadı.
  (Not: kesin teknik nedeni Apple belgeleriyle kanıtlanmış değil — 2.
  görüş bu konuda haklı, bkz. Bölüm 4.2 madde 1. "Aynı alanda üç farklı
  a11y modifier'ın çakışması" sadece makul bir şüphe, kesin teşhis değil.
  Karar zaten tek başına "gerçek cihazda güvenilir çalışmadı" gerekçesiyle
  yeterince destekleniyor.)
- Aynı sayma alanının VoiceOver kapalı / VoiceOver açık+Hızlı Sayım kapalı /
  VoiceOver açık+Hızlı Sayım açık olmak üzere üç farklı davranışı olması
  kafa karıştırıcı bulundu ("neyi açıp kapatıyorum" sorusu).
- "Sayıyı Okut" düğmesi VoiceOver açıkken bile çalışmadı, test edildi.
- Kaydırırken VoiceOver'ın okuduğu değer serbest sayaç modunda hep aynı
  sabit cümleyi ("Serbest Sayaç seçili, hedef yok") söylüyor, sayı hiç
  yansımıyor — hem yanıltıcı hem gereksiz uzun/rahatsız edici.

## 2. Üzerinde anlaşılan kararlar

1. **DirectTouch / Hızlı Sayım modu tamamen kaldırılıyor.** Arma-etkinleştirme
   gerektiren hiçbir mekanizma kalmıyor.
2. **"Hızlı Sayımı Aç/Kapat" düğmesi kaldırılıyor** (madde 1'in sonucu —
   açılıp kapatılacak bir şey kalmıyor).
3. Sayma alanında **her zaman aktif, moda bağlı olmayan üç sabit yöntem**:
   - **Kaydırma:** yukarı = artır, aşağı = geri al (VoiceOver açıkken).
   - **Tek parmak çift dokunuş = +1** (aynı alanda, standart VoiceOver
     "varsayılan eylem"; VoiceOver kapalıyken zaten tek dokunuş artırıyor).
   - **Magic Tap (iki parmakla çift dokunuş) = +1** — arma gerektirmeyen,
     VoiceOver'ın standart "en sık eylem" jesti.
4. **"Sayıyı Okut" düğmesi kaldırılıyor.** Gerekçe: VoiceOver kullanıcısı
   zaten sayma alanındayken değeri duyuyor / flick ile ilerleme metnine
   ulaşabiliyor; gören kullanıcı için dev boyuttaki sayı zaten ekranda
   sürekli görünür; ayrıca düğme test edilirken çalışmadığı görüldü.
5. **"Say" düğmesi kalıyor** — herkes için garanti çalışan, çift dokunuşla
   artıran evrensel yöntem (kaydırma/Magic Tap bilmeyen biri için).
6. Alt aksiyon ızgarası 4 düğmeden **3 düğmeye** iniyor: Say / Geri Al /
   Sıfırla.
7. **Kaydırmada okunan değer kısa formata çekiliyor** — iki görüş sonrası
   son hali netleşti (bkz. Bölüm 4): `accessibilityValue` sadece güncel
   sayı ("5"), hedef bilgisi `accessibilityLabel`'e taşınıyor ("Sayım,
   hedef 111" / hedefsizse "Sayım, hedefsiz"). `accessibilityHint` bu
   amaçla kullanılmıyor. **Not:** 1. görüş hedefi hint'e koymayı önermişti,
   2. görüş buna itiraz etti ve haklı bulundu — bkz. Bölüm 4.2 madde 4 için
   gerekçe (hint, kullanıcı tarafından kapatılabilen ve "eylem sonucu"
   anlatan bir alan; hedef gibi kalıcı durum bilgisi label'a ait). Her
   kaydırmada sadece "5... 6... 7..." okunuyor, hedef bilgisi elemana ilk
   odaklanıldığında bir kez okunuyor. "5 / 111" gibi "bölü" okunan bir
   format tercih edilmiyor (Türkçe'de "/" işaretini VoiceOver'ın nasıl
   okuyacağı belirsiz ve kafa karıştırıcı olabilir).
8. **Ayarlar'a yeni bir "Kaydırırken Titreşim" aç/kapa seçeneği ekleniyor**
   (uygulanabilir, tam kontrolümüzde).
9. **VoiceOver'ın kendi "tık" sesi uygulamadan kapatılamıyor** — bu sistem
   sesi, sadece kullanıcının kendi cihaz ayarından (Ayarlar > Erişilebilirlik
   > VoiceOver > Ses) kapatılabilir. Uygulama içine bu konuda çalışmayan
   bir sahte toggle konmayacak.
10. Kaydırmada okunan kısa değerin **tamamen susturulması API ile garanti
    edilemiyor** (VoiceOver, ayarlanabilir elemanlarda değeri otomatik okur —
    kaydırıcı/slider'larda da aynı davranış). Kısa format (madde 7) zaten
    rahatsızlığı büyük ölçüde azaltıyor; tam "sessiz" bir toggle eklenirse
    de bu garanti verilmeden, "en aza indirir ama tam susturmayı garanti
    etmez" notuyla eklenmeli.

## 3. Aile ile konuşulacak / karara bağlanacak açık noktalar

- [ ] **Magic Tap: global mi, sadece Sayaç ekranında mı, yoksa hiç
      eklenmesin mi?** Hâlâ açık — üç görüş üç farklı yerde:
      | Görüş | Öneri |
      |---|---|
      | 1. görüş (dış) | Global (uygulama geneli) |
      | Benim itirazım | Sadece Sayaç ekranına scope'lu |
      | 2. görüş (dış) | Hiç eklenmesin — zaten 2 yol (kaydırma + çift dokun) + Say düğmesi yeterli |
      Benim şu anki eğilimim 2. görüşe kayıyor: zaten kaydırma + çift
      dokunuş + Say düğmesi olmak üzere 3 güvenilir yol var, Magic Tap
      dördüncü bir yol olarak marjinal fayda katarken yanlışlıkla tetiklenme
      riski (özellikle global yapılırsa) ve ek test yükü getiriyor — tüm bu
      revizyonun "az mod, az risk" ilkesine de daha uygun. Ama bu tamamen
      bir ürün tercihi, kesin teknik bir doğru/yanlış yok; son kararı aile
      versin.
- [x] "Kaydırırken Titreşim" varsayılan açık mı kapalı mı olsun? →
      **Açık.** (Her iki dış görüş de aynı yönde, gerekçe: hızlı kaydırmada
      ses gecikirse/üst üste binerse dokunsal geri bildirim güven veriyor.
      2. görüş ek not: titreşim yalnızca sayım gerçekten değiştiğinde
      üretilmeli — geri alınacak bir şey yokken/undo başarısızken
      titreşim verilmemeli. Mevcut kodda zaten `undo()` bu durumda erken
      çıkıyor ve haptic tetiklemiyor, bu davranış korunacak.)
- [x] Kısa format kesin metni → **`accessibilityLabel`: "Sayım, hedef 111"
      (hedefsizse "Sayım, hedefsiz"), `accessibilityValue`: sadece "5".**
      2. görüş sonrası netleşti, bkz. Bölüm 4.2 ve güncellenmiş madde 7.
      "/" karakterli format ve hedefi hint'e koyma fikri terk edildi.
- [x] Madde 10'daki "sesli değeri en aza indir" toggle'ı → **Eklenmeyecek.**
      İki dış görüş de aynı gerekçeyle (resmi susturma API'si yok, hack
      riskli) bunu önerdi, kısa format (madde 7) yeterli kabul edildi.
- [x] `.accessibilityAddTraits(.isAdjustable)` elle eklensin mi? →
      **Hayır — eklenemez, ve gerek de yok.** 1. görüş "muhtemelen
      gereksiz" diye şüpheyle bıraktığım, 2. görüşün ise "kesin gerekli"
      dediği bu iddia, kodlama sırasında **gerçek derleme hatasıyla**
      kesin olarak çürütüldü: SwiftUI'nin `AccessibilityTraits` tipinde
      elle eklenebilecek bir `.isAdjustable` sabiti yok (2. görüşün verdiği
      kod örneği derlenmiyor). `accessibilityAdjustableAction` modifier'ı
      bu davranışı zaten kendi başına sağlıyor — orijinal şüphem (1.
      görüş sonrası) doğru çıktı. Bu, iki dış görüşün de tam doğru
      olmadığının somut bir örneği; gerçek derleyici en güvenilir hakem.
- [ ] Başka eklenmesi/çıkarılması istenen bir kolaylık var mı (aile
      görüşü sonrası bu bölüm güncellenecek)?

## 4. Dış görüş değerlendirmeleri

### 4.1 1. görüş (2026-07-15) — `uzman-gorusleri/2026-07-15-sayac-sayma-alani-1-gorus.md`

Genel olarak kararları onayladı, ek olarak üç somut öneri getirdi. Bunları
inceledim, ikisini kabul ettim, birine itiraz ettim, birini teyide açık
işaretledim:

- **Kabul edildi — Value/Hint ayrımı (Soru 3):** `accessibilityValue`'yu
  sadece "5" yapıp hedef bilgisini `accessibilityHint`'e taşıma önerisi
  isabetli; hem "5 / 111" gibi belirsiz okunan bir formattan kaçınıyor
  hem de her kaydırmada sadece kısa sayıyı okutuyor. Bölüm 2 madde 7 ve
  Bölüm 4 buna göre güncellendi. **Doğrulama notu:** görüşteki "hızlı
  kaydırmada hint okunmaz, sadece value okunur" iddiası mantıklı ve genel
  VoiceOver davranışıyla tutarlı görünüyor, ama gerçek cihazda (farklı
  VoiceOver ayrıntı/verbosity ayarlarıyla) doğrulanmalı — kodlama sonrası
  test adımına eklenecek.
- **Kabul edildi — Titreşim varsayılanı (Soru 2) ve mute toggle'ının
  eklenmemesi (Soru 4):** Gerekçeler sağlam, bizim kendi değerlendirmemizle
  de örtüşüyor.
- **İtiraz — Magic Tap'in global (uygulama geneli) yapılması (Soru 1):**
  Görüş bunu "kesinlikle" önerdi ama katılmıyorum. Kullanıcı Ayarlar veya
  Geçmiş ekranında gezinirken yanlışlıkla iki parmakla çift dokunursa,
  sayaç kullanıcının haberi olmadan artabilir ve sayım verisi sessizce
  bozulabilir — bu, tüm bu revizyonun amacı olan "yanlışlıkla
  tetiklenme riskini azaltma" ilkesiyle çelişiyor. Önerim: Magic Tap'i
  önce sadece Sayaç ekranına scope'lu tutmak, global yapmak istenirse
  bunu ayrı ve bilinçli bir karar olarak aileyle netleştirmek. Açık nokta
  olarak bırakıldı (Bölüm 3).
- **Teyide açık — `.accessibilityAddTraits(.isAdjustable)` gerekliliği:**
  Görüş, `accessibilityAdjustableAction` kullanılan elemana ayrıca elle
  `.isAdjustable` trait'i eklenmesi gerektiğini iddia etti. Benim bilgime
  göre SwiftUI'nin `accessibilityAdjustableAction` modifier'ı bu trait'i
  zaten otomatik ekliyor; elle eklemek muhtemelen gereksiz (zararsız
  olsa da). Kodlama sırasında bu iddia doğrulanacak, gereksizse
  eklenmeyecek — talimatta "gerekirse ekle" notuyla bırakıldı.
- **Kabul edildi (küçük not) — VoiceOver okuma sırası:** Say → Geri Al
  → Sıfırla mantıksal sırasının korunması notu, ızgara yeniden
  düzenlenirken dikkate alınacak.

### 4.2 2. görüş (2026-07-15) — `uzman-gorusleri/2026-07-15-sayac-sayma-alani-2-gorus.md`

Genel yönü onayladı, birkaç yerde 1. görüşle çelişti veya onu düzeltti.
Değerlendirmem:

- **Kabul edildi — Bölüm 1'deki "kesin neden" iddiasının yumuşatılması:**
  Haklı: DirectTouch'ın neden başarısız olduğuna dair "üç modifier
  çakışıyor" açıklamamız makul bir şüphe ama Apple belgeleriyle
  kanıtlanmış bir teşhis değil. Karar zaten "gerçek cihazda güvenilir
  çalışmadı" gerekçesiyle tek başına yeterli. Bölüm 1 buna göre güncellendi.
- **Kabul edildi — Label/Value ayrımı, Hint'e itiraz (madde 4):** Bu,
  1. görüşün Value/Hint önerisini gerçek bir teknik gerekçeyle
  düzeltiyor: `accessibilityHint` semantik olarak "bu elemanla etkileşime
  girersen ne olur" bilgisini taşımalı (ör. "kaydırarak değeri
  değiştirin"), "hedef 111" gibi kalıcı durum bilgisini taşımak için
  doğru yer değil — üstelik kullanıcı VoiceOver ayarlarından ipuçlarını
  tamamen kapatmış olabilir, bu durumda hedef bilgisi hiç duyulmaz. Hedefi
  `accessibilityLabel`'e koymak (her odaklanmada okunur, kaydırmada
  tekrar okunmaz) daha doğru. **Bu, 1. görüşün önerisini geçersiz kılıp
  yerine geçiyor** — Bölüm 2 madde 7 ve Bölüm 3 buna göre güncellendi.
- **Reddedildi — `.isAdjustable` trait'i açıkça eklensin (madde 5):**
  Kodlama sırasında derleme hatasıyla çürütüldü — SwiftUI'de böyle bir
  trait sabiti yok. Bkz. Bölüm 3, güncellenmiş sonuç.
- **Kabul edildi — çift dokunuşun `Button`/`accessibilityAction(.default)`
  semantiğiyle tanımlanması (madde 2, "kodlama talimatına eklenmesi
  gereken düzeltmeler"):** 1. görüşün "isButton trait'i ekleyin" notuyla
  aynı yöne işaret ediyor, ikisi birlikte kodlama talimatına işlendi.
- **Kabul edildi — her artışta ayrı `.announcement` göndermeyin, sadece
  hedef tamamlanınca (madde 8):** Bu zaten mevcut kod ve planla tutarlı
  (periyodik anons yalnızca kaldırılan Hızlı Sayım moduna özeldi, hedef
  tamamlama anonsu ayrı ve kalıyor) — ek bir değişiklik gerekmiyor, sadece
  doğrulandı.
- **Açık bırakıldı, aileye taşındı — Magic Tap (madde 2 ve tablo):** 2.
  görüş, 1. görüşün aksine Magic Tap'in **hiç eklenmemesini** öneriyor.
  Bu üç görüşün (1. görüş / benim itirazım / 2. görüş) üçe ayrıldığı tek
  nokta — kesin bir Apple kısıtı değil, ürün tercihi. Bölüm 3'e üç
  seçenekli tablo olarak eklendi, benim eğilimim şu an 2. görüşe (hiç
  eklememe) yakın ama son karar aileye bırakıldı.

## 5. Kodlama talimatı (netleşince kullanılacak)

> Bu bölüm, yukarıdaki açık noktalar kapanınca AI'a (veya kodlayan kişiye)
> doğrudan verilebilecek şekilde yazıldı. Şu an için **uygulamaya
> geçilmeyecek**, sadece taslak.

**Değişecek dosyalar:**

- `Sources/TesbihimApp/Views/Sayac/SayacView.swift`
  - `countingSurface`: `.accessibilityDirectTouch(...)` ve buna bağlı
    `guard !viewModel.quickCountEnabled` mantığı kaldırılacak.
  - Sayma yüzeyi ham `.onTapGesture` yerine gerçek bir SwiftUI `Button`
    olarak yeniden yazıldı (`.buttonStyle(.plain)` + `.accessibilityAddTraits(.isButton)`),
    böylece hem VoiceOver kapalıyken normal dokunma hem VoiceOver açıkken
    çift dokunma güvenilir şekilde `+1` tetikliyor.
  - `.accessibilityAddTraits(.isAdjustable)` **eklenmedi** — derleme
    hatasıyla doğrulandığı gibi SwiftUI'de böyle bir trait sabiti yok,
    `accessibilityAdjustableAction` bunu zaten kendisi sağlıyor (bkz.
    Bölüm 3, düzeltilmiş sonuç).
  - `.accessibilityLabel`, hedef bilgisini içerecek şekilde
    ayarlanacak: hedefliyse "Sayım, hedef \(target)", hedefsizse
    "Sayım, hedefsiz". `.accessibilityValue` sadece güncel sayı
    (`"\(viewModel.currentCount)"`) olacak. `.accessibilityHint` hedef
    bilgisini taşımayacak, sadece mevcut kaydırma yönergesini
    (VoiceOver zaten "ayarlanabilir" dediği için bu metin kısaltılabilir
    ya da tamamen sistem varsayılanına bırakılabilir) içerecek.
  - Magic Tap (`.accessibilityAction(.magicTap) { viewModel.increment() }`)
    **koşullu** — Bölüm 3'teki üç seçenekli açık nokta (global / sadece
    Sayaç / hiç ekleme) aile tarafından netleşmeden eklenmeyecek.
  - `quickCountToggle` view'ı ve çağrıldığı yer tamamen silinecek.
  - `actionGrid`'den "Sayıyı Okut" `GridRow` girişi kaldırılacak, ızgara
    3 düğmeye göre yeniden düzenlenecek (ör. üstte Say/Geri Al, altta
    Sıfırla tek başına ya da tek satır 3 sütun — tasarım tercihi), VoiceOver
    okuma sırası Say → Geri Al → Sıfırla olacak şekilde.
- `Sources/TesbihimApp/ViewModels/CounterViewModel.swift`
  - `quickCountEnabled`, `setQuickCountEnabled`, `announcePeriodicallyIfNeeded`
    kaldırılacak (artık mod yok).
  - `announceCurrentState()` UI'dan çağrılmayacağı için kaldırılabilir
    (başka bir yerden kullanılmıyorsa).
  - Hedef tamamlanınca gönderilen tek seferlik `announceQueued("...
    tamamlandı; yeni tur 0")` çağrısı **korunuyor** — iki dış görüş de
    bunun (sadece bu durumda) doğru kullanım olduğunu onayladı, her
    artışta ayrı anons gönderilmiyor zaten.
  - Yeni computed property'ler: `accessibilityContextLabel` (hedefliyse
    "Sayım, hedef \(target)", hedefsizse "Sayım, hedefsiz") ve
    `currentCount` zaten var (değer için doğrudan kullanılacak,
    `progressAnnouncement` sayma yüzeyinin a11y alanları için
    kullanılmayacak — o, ilerleme özeti metni için kalmaya devam eder).
- `Sources/TesbihimApp/Models/UserSettings.swift`
  - `quickCountEnabled`, `quickCountAnnouncementInterval` alanları
    kaldırılacak.
  - Yeni `swipeHapticEnabled: Bool` eklenecek (varsayılan: açık noktalar
    kapanınca karar verilecek).
  - Not: `Codable` decode sırasında eski kayıtlı JSON'da olmayan yeni bir
    zorunlu alan varsa `init(from:)` özelleştirilip varsayılan değer
    sağlanmalı (mevcut kullanıcıların ayarları bozulmasın).
- `Sources/TesbihimApp/Views/Ayarlar/AyarlarView.swift`
  - Hızlı Sayım ile ilgili satır(lar) kaldırılacak.
  - "Kaydırırken Titreşim" toggle'ı eklenecek.
- `Tests/TesbihimAppTests/CounterViewModelTests.swift`,
  `CounterStateTests.swift`: kaldırılan API'lere ait testler silinecek/
  güncellenecek, `shortProgressValue` için yeni testler eklenecek.

**Kapsam dışı:** Zikir Seç, Geçmiş, Ayarlar'ın diğer bölümleri, Karşılama
ekranı — bu belge sadece Sayaç ekranının sayma alanını kapsıyor.

## 6. Ek: "Sayıyı Sesli Söyle" ayarı (cihaz denemesi sonrası, uygulandı)

**Bildirilen sorun:** Cihazda denerken kaydırırken ("41, 42, 43...") ve
sayma yüzeyine çift dokunurken de sayının sesli söylenmesi rahatsız
edici bulundu — dhikr sırasında maneviyatı bozuyor.

**Kök neden:** Sayma yüzeyinin `accessibilityValue`'sü güncel sayıya
bağlıydı; VoiceOver hem kaydırma (adjustable action) hem çift dokunuşla
etkinleştirme sonrası güncel değeri otomatik okuyor — bu, Bölüm 2 madde
10'da zaten "API ile garanti edilemez" diye not edilen davranışın aynısı,
ama iki tetikleyicide de (sadece kaydırmada değil) ortaya çıktığı cihazda
netleşti.

**Çözüm:** Yeni `UserSettings.spokenCountEnabled` (varsayılan: açık,
mevcut davranış korunuyor). Kapatılınca:
- Sayma yüzeyinin `accessibilityValue`'sü boş string döner
  (`CounterViewModel.accessibilitySpokenValue`) — VoiceOver'ın okuyacağı
  içerik kalmıyor, "mute" API'si kullanılmıyor, sadece okunacak metin
  boş bırakılıyor (tam susturma garantisi olmayan bir hack değil, standart
  bir kullanım).
- Titreşim (mevcut haptic, `swipeHapticEnabled`'a tabi kaydırmada / çift
  dokunuşta her zaman) korunuyor, ayrıca kısa, konuşma içermeyen bir
  sistem sesi (`FeedbackProviding.countTick()`, `AudioServicesPlaySystemSound(1104)`)
  hem artışta hem geri almada çalıyor.
- Bu davranış hem kaydırma hem çift dokunuş için aynı anda geçerli çünkü
  ikisi de aynı elemanın aynı `accessibilityValue`'sünü paylaşıyor —
  kullanıcının bildirdiği iki sorun (kaydırma + çift dokunuş) tek
  noktadan çözüldü.

Ayarlar ekranına "Sayıyı Sesli Söyle" toggle'ı ve açıklayıcı bir alt metin
eklendi (`AyarlarView.swift`).

### 6.1 İkinci tur geri bildirim: "her yerde" tutarlılık ve gecikme

Kullanıcı cihazda denedikten sonra iki ek istek bildirdi:

1. **Tick sesi/titreşim sadece sayma yüzeyinde değil, Say/Geri Al
   düğmelerinde de tutarlı olsun.** Çözüm: `countTick()` çağrısı, ayrı bir
   `incrementFromCountingSurface`/`undoFromCountingSurface` sarmalayıcısından
   `CounterViewModel.increment(isSwipeTriggered:)` ve `undo()`'nun **kendi
   içine** taşındı — artık `spokenCountEnabled` kapalıyken tetikleyici ne
   olursa olsun (kaydırma, çift dokunuş, Say düğmesi, Geri Al düğmesi) aynı
   tick sesi çalıyor. Bu aynı zamanda kodu sadeleştirdi (iki paralel
   sarmalayıcı metot kaldırıldı).
2. **Hızlı art arda sayımda titreşim/ses geriden geliyordu.**
   Kök neden: `SystemFeedbackProvider` her çağrıda yeni bir
   `UIImpactFeedbackGenerator`/`UINotificationFeedbackGenerator` örneği
   oluşturuyordu — Taptic Engine her yeni örnekte ısınma gecikmesi
   yaşıyor. Çözüm: tek örnek saklanıp `init()`'te ve her ateşlemeden
   sonra `prepare()` çağrılıyor (Apple'ın `UIFeedbackGenerator.prepare()`
   önerisi). `SystemFeedbackProvider` bu yüzden `struct`'tan `final class`'a
   çevrildi.
3. **Yan etki (Swift 6 katı eşzamanlılık):** Kalıcı örnek tutmak,
   `UIImpactFeedbackGenerator`/`UINotificationFeedbackGenerator`'ın stored
   property varsayılan değeri olarak main-actor izolasyonu gerektirmesine
   yol açtı; bunu çözmek için `FeedbackProviding` protokolü,
   `SystemFeedbackProvider` ve `CounterViewModel` `@MainActor` olarak
   işaretlendi (zaten sadece SwiftUI view'larından, yani main thread'den
   kullanılıyorlardı — davranış değişmedi, sadece derleyiciye açıkça
   belirtildi). Test dosyasındaki `RecordingFeedbackProvider`,
   `makeViewModel` ve `CounterViewModelTests` de aynı sebeple `@MainActor`
   işaretlendi.

Testler: `CounterViewModelTests.swift` →
`tickPlaysInsteadOfSpeechEverywhereWhenSpokenCountDisabled`,
`countingSurfaceSpokenValueReflectsCurrentCountWhenEnabled`. 26/26 test
geçti, `xcodebuild test` ile doğrulandı.

### 6.2 Üçüncü tur geri bildirim: kaydırmada yine takılma (ses efekti şüphesi)

Kullanıcı 6.1'deki gecikme düzeltmesinden sonra bile kaydırırken takılma
hissetti ve bunun ses efekti (spesifik olarak süresi/sıklığı) kaynaklı
olabileceğini düşündü. Değerlendirme: titreşim her sayımda hâlâ ateşleniyor
(6.1'de düzeltildi, bundan bağımsız); tek fark eden değişken
`spokenCountEnabled` kapalıyken devreye giren `AudioServicesPlaySystemSound`
çağrısı — bu, `mediaserverd`'e IPC ile gidiyor ve hızlı art arda
tetiklenince çağrılar üst üste binip gecikme olarak hissedilebiliyor.

**Uygulanan düzeltme (cihazda doğrulanamadı, kod incelemesiyle en olası
neden):** `SystemFeedbackProvider.countTick()`'e ~60ms'lik bir alt sınır
eklendi — art arda çok hızlı tetiklenirse fazlalık ses çağrıları
atlanıyor, titreşim yine de her sayımda ateşleniyor (asıl anlık dönüt
zaten o). Bu, gerçek cihazda test edilmeden kesin doğrulanamaz; kullanıcı
tekrar deneyip onaylayacak.

### 6.3 Özel "tesbih-tik" sesi eklendi ve kısaltıldı

Kullanıcı hem mevcut sistem sesinin ("Tock", ID 1104) hem
`~/Downloads/tesbih-tik.wav` dosyasının süresini sordu. `afinfo` ile
ölçüldü:
- Sistem "Tock" (1104): **~21.5ms**
- `tesbih-tik.wav` (orijinal): **160ms** — sistem sesinden ~7-8 kat uzun,
  hızlı kaydırmada üst üste binme riski sistem sesinden daha yüksek.

Dosyanın genlik zarfı incelendi (`python3 wave` modülüyle 1ms'lik
pencerelerle RMS ölçümü) — sesin net bir "kesilme noktası" yok, yumuşak
bir sönümlenme eğrisi var (25ms'de hâlâ tepe genliğin %23'ü). Bu yüzden
sert bir kesim yerine **28ms'ye kırpılıp son 8ms'de doğrusal fade-out**
uygulandı (ffmpeg araç zincirinde eksik bir dylib nedeniyle çalışmadığı
için saf Python/`wave` modülüyle yapıldı) — ani "pop" sesi olmasın diye.

Sonuç `Sources/TesbihimApp/Resources/Sounds/tesbih-tik.wav` olarak
projeye eklendi (28ms, `afinfo` ile doğrulandı). `SystemFeedbackProvider`
artık `AudioServicesCreateSystemSoundID` ile bu dosyayı özel bir
`SystemSoundID` olarak yüklüyor (`init()`'te, `deinit`'te
`AudioServicesDisposeSystemSoundID` ile temizleniyor); dosya bulunamazsa
sistem "Tock" sesine (1104) düşülüyor. 60ms'lik throttle eşiği korundu —
28ms'lik yeni ses bu eşiğin altında kalıyor, üst üste binme riski yok.
`xcodegen generate` + `xcodebuild test` ile 26/26 test geçti, `.app`
bundle'ında dosyanın varlığı doğrulandı. Cihazda dinlenip onaylanması
gerekiyor.

### 6.4 Dördüncü tur: gerçek kök neden — yarım kalan DirectTouch temizliği

Kullanıcı cihazda "parmağımı bıraktım ama tesbih benden sonra saymaya/
titremeye devam ediyor" sorununu yeniden bildirdi; bu kez kaynak koda
tekrar bakıldı (6.2'deki önceki tur sadece ses throttle'ını
düzeltmişti, `SayacView.swift`'in kendisi tekrar incelenmemişti).

**Bulgu:** Bölüm 5'teki "DirectTouch/Hızlı Sayım tamamen kaldırılıyor"
kararı `CounterViewModel` ve `UserSettings` katmanlarında tam
uygulanmıştı (`quickCountEnabled` gibi alanlar orada yoktu), **ama
`SayacView.swift`'te temizlik yarım kalmıştı**: yeni bir yerel
`@State private var fastCountingEnabled`, eski `HizliSayimYuzeyi.swift`
dosyasını (`UIViewRepresentable` + `UIAccessibilityTraits
.allowsDirectInteraction`) hâlâ çağırıyordu ve bu, eski "Hızlı Sayımı
Aç/Kapat" düğmesinin yerini alan Magic Tap (iki parmak çift dokunuş) ile
açılıp kapanıyordu. Yani karar dosyasında "kaldırıldı" yazan DirectTouch
mekanizması farklı bir aktivasyon yoluyla fiilen hayatta kalmıştı ve
raporlanan gecikme/kuyruklanma tam olarak bu mod içinde oluşuyordu.
`countingSurface` (Bölüm 5'in Button + `accessibilityAdjustableAction`
yüzeyi) ise doğru uygulanmıştı ve sorunsuzdu — sorun onun yanında hâlâ
canlı duran eski mekanizmaydaydı.

**Kök neden netleşti:** `allowsDirectInteraction` trait'i VoiceOver'a
"bu elemandaki ham dokunuşları kendi işleme, doğrudan view'a ilet" der.
Ancak VoiceOver açıkken parmak hareketleri yine de VoiceOver'ın jest
tanıma/keşif katmanından geçer (tek parmak mı çoklu mu, kayma mı arama
mı olduğu ayrıştırılır) — bu ayrıştırma senkron değildir; kullanıcı
parmağını kaldırdıktan sonra bile VoiceOver'ın kendi iç zamanlayıcıları/
gecikmiş jest kararları view'a ulaşmaya devam edebilir. Bu, standart
`accessibilityAdjustableAction`/`Button` + `accessibilityAction`
yolunun (VoiceOver'ın tek-seferlik, kuyruklamayan eylem dispatch'i)
aksine DirectTouch'a özgü bir davranıştır — Bölüm 1'deki "üç modifier
çakışması" şüphesinden bağımsız, daha somut bir açıklama.

**Düzeltme:** `SayacView.swift`'ten `fastCountingEnabled` state'i,
`HizliSayimYuzeyi` çağrısı, onu sarmalayan `ZStack` ve Magic Tap ile mod
açma/kapama eylemi tamamen silindi. `Sources/TesbihimApp/Views/Sayac/
HizliSayimYuzeyi.swift` dosyası projeden silindi. Geriye tek, her zaman
aktif sayma yüzeyi kaldı; DirectTouch'a ait hiçbir kod kalmadı.
`xcodegen generate` + `xcodebuild test` (iPhone 17 simülatörü) ile
29/29 test geçti.

**Magic Tap açık noktası (Bölüm 3) kapatıldı:** Bu bulgu ışığında Magic
Tap'i başka bir amaçla (ör. +1) yeniden eklemek yerine hiç eklenmemesi
tercih edildi — 2. görüşün önerisiyle örtüşüyor: kaydırma + çift
dokunuş + Say düğmesi olmak üzere zaten 3 güvenilir yol var, dördüncü
bir jest marjinal fayda katarken yanlış tetiklenme riski getiriyor. Aile
ileride +1 için Magic Tap isterse bu, DirectTouch'tan tamamen bağımsız,
ayrı ve küçük bir ekleme olarak yapılabilir.

**Cihazda test senaryosu:** VoiceOver açıkken sayma alanına odaklan,
hızlıca art arda yukarı kaydır (5-10 kez), son kaydırmadan hemen sonra
parmağı ekrandan tamamen çek. Beklenen: sayı, ses ve titreşim parmak
çekildiği anda durur, sonrasında ek artış/ses/titreşim gelmez. Aynı
senaryo çift dokunuşla art arda dokunarak da tekrarlanmalı.

## 7. Beşinci tur: Hızlı Sayım eleştirel yeniden tasarımla geri getirildi

Kullanıcı, kaldırılan tek-dokunuşlu Hızlı Sayım'ı özellikle beğendiğini
ve geri istediğini bildirdi. Ayrıca kaydırma yönteminin de hızlı
kullanımda benzer "geriden gelme"/kısa donma hissi verdiğini belirtti —
bu ayrı olarak incelendi (bkz. altta), ama kullanıcının asıl talebi
Hızlı Sayım'ın geri getirilmesiydi, eleştirel bir yeniden tasarımla.

### 7.1 Kaydırmadaki gecikme şüphesi — ayrı bulgu, ayrı konu

Kaydırmanın da yavaş/donuk hissettirmesi üzerine `CounterViewModel`/
persistence katmanı incelendi: `history.recordDelta` günlük+zikir bazında
grupluyor (kayıt sayısı aylar sonra bile küçük kalıyor), `UserDefaults.set`
disk I/O'yu senkron beklemiyor — bu yol hızlı değil diye şüphelenilecek
kadar yavaş değil. Asıl şüphelenilen kaynak: `accessibilityValue`
sayıya bağlı olduğu için (varsayılan `spokenCountEnabled = true`)
VoiceOver her kaydırmada sayıyı sesli okumaya çalışıyor ve hızlı art
arda kaydırmada bu konuşmalar VoiceOver'ın kendi kuyruğunda birikip
geriden gelebiliyor — DirectTouch'ın sorunuyla aynı aile ama farklı
mekanizma (konuşma kuyruğu, dokunuş kuyruğu değil). Bu, kullanıcı
tarafından cihazda "Sayıyı Sesli Söyle" kapalıyken doğrulanmadı, açık
nokta olarak kalıyor — ayrı bir konu, bu bölümün asıl kapsamı değil.

### 7.2 Eski tasarımın somut dezavantajları (kullanıcıya aktarıldı)

Kullanıcı "geri getir ama eleştirel ol" dedi; aşağıdaki noktalar
kullanıcıyla paylaşıldı ve tasarım bunlara göre değiştirildi:

1. **Aynı mekanizma, aynı bug.** Eski tasarım tam olarak Bölüm 6.4'te
   silinen koddu (Magic Tap → `fastCountingEnabled` → `HizliSayimYuzeyi`).
   Aynen geri getirmek bug'ı da geri getirirdi.
2. **Mod karışıklığı riski.** Ekranda iki farklı dokunuş rejimi.
3. **Yanlışlıkla mod açılması.** Sihirli Dokunuş yanlışlıkla tetiklenirse
   mod sessizce açılabilir, ekrandaki her dokunuş sayabilir.
4. **Çıkış güvenilirliği.** Eski tasarımda çıkış, aynı yüzey içinde ikinci
   parmağı algılamaya çalışan bir dokunuş sayacıyla yapılıyordu — bu,
   gerçek cihazda "bazen tek dokunuşla karışma" riski taşıyordu (bkz.
   Bölüm 1).
5. **Kalıcı bakım riski.** `allowsDirectInteraction` VoiceOver'ın özel/az
   kullanılan bir API yolu, iOS güncellemeleriyle davranışı değişebilir.

### 7.3 Yeni tasarım — değişenler

- **Kapsam korunuyor:** Sadece Sayaç ekranı (global değil).
- **Açma korunuyor:** Sihirli Dokunuş (iki parmakla çift dokunuş).
- **Ana güvenlik anahtarı eklendi:** `UserSettings.fastCountModeEnabled`,
  varsayılan **kapalı**. Kapalıyken Sayaç ekranında Sihirli Dokunuş hiçbir
  şey yapmıyor — yanlışlıkla moda düşme riski, özelliği varsayılan kapalı
  tutarak azaltıldı.
- **Çıkış tamamen değişti:** Eski "yüzey içinde ikinci parmağı algıla"
  mantığı tamamen kaldırıldı. Yerine, `HizliSayimYuzeyi`'nin (direkt
  dokunma alanı) **dışında**, sabit bir üst şerit (`fastCountHeader`)
  kondu — bu şerit normal bir SwiftUI `Button`, dolayısıyla normal
  VoiceOver tek-dokunuş-odakla + çift-dokunuş-aç semantiğiyle her zaman
  güvenilir şekilde ulaşılabilir; jest belirsizliği ortadan kalktı.
- **Görünürlük iyileştirmesi:** Üst şeritte artık canlı, büyük bir sayı da
  gösteriliyor (`accessibilityValue` ile VoiceOver'a da açık) — eski
  tasarımda Hızlı Sayım'dayken ekranda hiçbir sayı görünmüyordu, az gören
  kullanıcı için bu bir eksiklikti.
- **Ekrandan ayrılınca otomatik kapanma:** `onDisappear` ve
  `NavigationPath` değişince (`onChange(of: path)`) `fastCountingEnabled`
  sıfırlanıyor — kullanıcı başka bir ekrana geçip geri dönünce Hızlı
  Sayım'da takılı kalmıyor.
- **Çoklu dokunuş = sayılmaz (sayaç bozulmasın diye):** `HizliSayimYuzeyi`
  içinde bir dokunuş dizisi sırasında birden fazla parmak değdiyse o
  dizi hiç sayılmıyor (önceki tasarımdaki gibi bir "çıkış" eylemine
  bağlanmıyor, sadece iptal ediliyor) — telefonu tutarken kazara ikinci
  parmak temasının yanlış sayım üretmesi engelleniyor.
- **Geri bildirim ayarları Hızlı Sayım'a özel, birbirinden bağımsız:**
  `fastCountHapticEnabled` (vars. açık), `fastCountSoundEnabled` (vars.
  açık), `fastCountAnnounceEnabled` (vars. **kapalı**). Bunun için
  `FeedbackProviding` protokolüne `countFeedback(hapticEnabled:soundEnabled:)`
  eklendi — eski `countFeedback(playsSound:)` her zaman titreşim
  veriyordu, bağımsız kontrol için yetersizdi.
- **Sayıyı duyurma riski göz önünde bulunduruldu:** Açıksa her dokunuşta
  değil, dokunuşlar durduktan ~500ms sonra SADECE o anki değer için, tek
  seferlik, **kuyruklamayan** (`announceInterrupting`, mevcut konuşmayı
  keser) bir anons gönderiliyor (`CounterViewModel.
  scheduleDebouncedFastCountAnnouncement`) — Bölüm 7.1'de tarif edilen
  konuşma-kuyruğu birikmesi riskini en aza indiriyor. Varsayılan kapalı,
  Ayarlar'da açıklayıcı not var.
- **Ayarlar'a "Hızlı Sayım (Tek Dokunuş)" bölümü eklendi:** ana anahtar +
  3 bağımsız geri bildirim anahtarı + açıklayıcı metinler
  (`AyarlarView.swift`).

**Değişen/eklenen dosyalar:**
- `Sources/TesbihimApp/Accessibility/AccessibilityAnnouncing.swift` —
  `announceInterrupting(_:)` eklendi.
- `Sources/TesbihimApp/Accessibility/FeedbackProviding.swift` —
  `countFeedback(hapticEnabled:soundEnabled:)` eklendi.
- `Sources/TesbihimApp/Models/UserSettings.swift` — 4 yeni alan
  (`fastCountModeEnabled`, `fastCountHapticEnabled`,
  `fastCountSoundEnabled`, `fastCountAnnounceEnabled`), eski JSON için
  `decodeIfPresent` ile varsayılan değerler.
- `Sources/TesbihimApp/ViewModels/CounterViewModel.swift` —
  `incrementFast()`, `scheduleDebouncedFastCountAnnouncement()`.
- `Sources/TesbihimApp/Views/Sayac/HizliSayimYuzeyi.swift` — yeniden
  yazıldı: sadece sayma, çıkış mantığı yok.
- `Sources/TesbihimApp/Views/Sayac/SayacView.swift` — `fastCountingEnabled`
  state, `fastCountScreen`/`fastCountHeader`, Magic Tap artık
  `fastCountModeEnabled` ayarına tabi.
- `Sources/TesbihimApp/Views/Ayarlar/AyarlarView.swift` — yeni bölüm.
- `Tests/TesbihimAppTests/CounterViewModelTests.swift` — yeni testler:
  `incrementFastRespectsIndependentHapticAndSoundSettings`,
  `incrementFastAnnouncesOnlyWhenSettingEnabledAndDebounced`,
  `incrementFastDoesNotAnnounceWhenSettingDisabled`, legacy decode testi
  4 yeni alanı da kontrol edecek şekilde genişletildi.

`xcodegen generate` + `xcodebuild test` (iPhone 17 simülatörü) ile
**32/32 test geçti**.

**Açık nokta / cihazda doğrulanması gereken:**
- Sihirli Dokunuş, `allowsDirectInteraction` alanının DIŞINDaki
  `fastCountHeader`'a gerçekten VoiceOver'ın normal yoluyla ulaşılabilir
  mi (beklenti: evet, çünkü direkt-dokunma sadece `HizliSayimYuzeyi`'nin
  sınırlarıyla kısıtlı) — kod incelemesiyle makul ama cihazda
  doğrulanmadı.
- Hızlı Sayım'da tek dokunuşun gerçekten anında sayıp parmak
  kalktığında durduğu (Bölüm 6.4'ün kök neden teşhisinin, çıkış
  mantığı kaldırıldıktan sonra da geçerli olup olmadığı) cihazda
  doğrulanmalı.
- Kaydırmadaki "Sayıyı Sesli Söyle" kapalıyken bile devam eden gecikme
  şüphesi (Bölüm 7.1) hâlâ açık, ayrı bir cihaz testi gerektiriyor.

### 7.4 Altıncı tur: çıkış jesti Sihirli Dokunuş'a geri döndü

Kullanıcı, "Kapat" düğmesini bulup ona ulaşmanın Hızlı Sayım modundayken
zor olduğunu, eski "ekranın herhangi bir yerinde Sihirli Dokunuş yap, aç/
kapa" davranışının pratik olduğunu bildirdi; sadece eski kapamanın "bazen
tek dokunuşla karışması" düzeltilsin istedi.

**Analiz:** Bölüm 3'teki (silinen) orijinal koda tekrar bakıldığında,
açma zaten gerçek VoiceOver Sihirli Dokunuş jestiyle (SwiftUI
`.accessibilityAction(.magicTap)`, VoiceOver'ın sistem düzeyinde tanıdığı
bir jest) yapılıyordu; ama **kapama tamamen farklı, elle yazılmış bir
mekanizmaydı** — `HizliSayimYuzeyi`'nin `touchesBegan`'ı içinde "aynı anda
1'den fazla parmak değdiyse çık" diye ham dokunuş sayan bir heuristic
(gerçek Sihirli Dokunuş jest tanımayı hiç kullanmıyordu). Güvenilmezliğin
kaynağı buydu: "2 parmak dokunuşu" ile gerçek "2 parmak ÇİFT dokunuşu"
(Sihirli Dokunuş) aynı şey değil, ilki çok daha kaba/yanlış tetiklenmeye
açık bir tahmin.

`allowsDirectInteraction`, Apple'ın tasarım amacına göre yalnızca **tek
parmak** dokunuşlarını uygulamaya yönlendirir (çizim/kaydırma gibi
doğrudan manipülasyon senaryoları için); çoklu parmak sistem jestleri
(Sihirli Dokunuş dahil) bu alanın içinde bile VoiceOver tarafından işlenmeye
devam etmesi beklenir. Buna dayanarak: **hem açma hem kapama artık gerçek
Sihirli Dokunuş jestiyle yapılıyor, ekranın her yerinde** (`SayacView.
toggleFastCounting()`, `.accessibilityAction(.magicTap)` üst container'a
bağlı, eskiden olduğu gibi `HizliSayimYuzeyi` içinde ham dokunuş sayma
mantığı YOK). Kapama, Ayarlar'daki `fastCountModeEnabled` kapatılmış olsa
bile her zaman çalışır (moddan çıkışın asla kilitlenmemesi için). Görünür
"Kapat" düğmesi **yedek olarak** kalıyor — Sihirli Dokunuş bir sebeple
tutmazsa (cihazda doğrulanmadı) görünür bir çıkış yolu olsun diye.

**Değişen dosya:** `Sources/TesbihimApp/Views/Sayac/SayacView.swift` —
`toggleFastCounting()` eklendi, Sihirli Dokunuş handler'ı ve "Kapat"
düğmesi bu ortak metodu çağırıyor. `xcodegen generate` + `xcodebuild
test` ile 32/32 test geçti.

**Açık nokta (cihazda doğrulanmalı):** Sihirli Dokunuş'un
`allowsDirectInteraction` alanının İÇİNDE de (yani Hızlı Sayım aktifken,
sayma yüzeyinin üzerindeyken) gerçekten VoiceOver tarafından yakalanıp
`toggleFastCounting()`'i tetiklediği — bu bölümün temel varsayımı, kod
incelemesiyle makul ama Apple dokümantasyonunda "direkt dokunma alanında
Sihirli Dokunuş garanti çalışır" diye açık bir garanti yok. Cihazda
denenmeli; çalışmazsa "Kapat" düğmesi zaten yedek olarak duruyor.

## 8. Kaydırmadaki (swipe) gecikme — kanıtlanmadan tahmin yapılmadı, tanılama eklendi

Kullanıcı somut, önemli bir deney sonucu bildirdi: hızlı art arda
kaydırma yapıp (ör. dhikr sırasında "Allah" deyip aynı anda yukarı
fiske, 18 kez arka arkaya) parmağını bıraktıktan sonra **titreşim ve
ses de** birkaç saniye geriden gelmeye devam ediyor — "Sayıyı Sesli
Söyle" **kapalıyken bile**. Bu, önceki turda (Bölüm 7.1) öne sürülen
"VoiceOver'ın konuşma kuyruğu birikiyor" tahminini tek başına geçersiz
kılıyor: konuşma yoksa da gecikme sürüyor.

**Elenen olasılıklar (kod incelemesiyle):**
- Persistence (`UserDefaults` + küçük, gün/zikir bazlı gruplanan geçmiş
  dizisi) hızlı, senkron disk I/O beklemiyor (Bölüm 7.1'de zaten
  doğrulandı).
- Titreşim/ses üreteçleri kalıcı, `prepare()` ile ısıtılmış (Bölüm 6.1),
  kendi başlarına yavaş değil.
- `countFeedback(hapticEnabled:soundEnabled:)` senkron, birkaç satırlık
  bir fonksiyon — çağrıldığı an neredeyse anında tamamlanır.

Bu üçü de hızlı olduğuna göre, `accessibilityAdjustableAction`
closure'ının kendisinin **VoiceOver tarafından geç çağrılıyor olması**
en olası açıklama — yani titreşim/ses "geriden geliyormuş gibi
görünüyor" çünkü VoiceOver bize "artık artır" demeyi geciktiriyor,
bizim kodumuz o çağrıldığı anda zaten hızlı çalışıyor. Ama bu, talimatta
istendiği gibi **kanıtlanmadan** kabul edilmeyecek bir tahmin;
rastgele yeni bir throttle/jest eklemek yerine önce ölçüldü.

**Eklenen geçici tanılama:** `Sources/TesbihimApp/Accessibility/
FeedbackProviding.swift`'e `diagnosticsLog` (`os.Logger`, subsystem
`com.tesbihim.diagnostics`) eklendi, iki noktada zaman damgası basıyor:
1. `SayacView.countingSurface`'in `accessibilityAdjustableAction`
   closure'ı — VoiceOver'ın bize "artır/azalt" dediği an
   ("VoiceOver'DAN GELDİ").
2. `SystemFeedbackProvider.countFeedback(hapticEnabled:soundEnabled:)`
   — hem çağrıldığı an hem fiilen ateşlendiği an (throttle'a takılırsa
   ayrıca işaretleniyor).

Gizli/kişisel veri içermiyor, sadece `CFAbsoluteTimeGetCurrent()`
değerleri. Kök neden netleşince kaldırılacak.

**Kullanıcıdan istenen cihaz testi:** Bu build'i cihaza kurup aynı
"hızlı art arda kaydır, sonra bırak" senaryosunu tekrarlayıp Mac'te
Console.app'i (Cihazlar bölümünden telefonu seçip) "Tesbihim" veya
"com.tesbihim.diagnostics" ile filtrelemek, ya da bir aile üyesinden bu
filtrelenmiş log satırlarını (sadece zaman damgaları, başka veri yok)
paylaşmasını istemek. Bu satırlar bana iletilirse: "VoiceOver'DAN
GELDİ" zaman damgaları arasındaki fark küçükse (VoiceOver kendi
kaydırmaları hızlı işliyor) ama "artık artır" çağrıları arasındaki fark
gerçek fiziksel kaydırma hızından yavaşsa, sorun kesinleşmiş olarak
VoiceOver'ın kendi jest dağıtımında demektir — bu durumda uygulama
kodunda yapılabilecek bir şey yoktur, gerçek hızlı sayım için Hızlı
Sayım (Bölüm 7, tek dokunuş) kullanılmalıdır çünkü o, VoiceOver'ın jest
tanıma hattını `allowsDirectInteraction` ile tamamen atlıyor.

`xcodegen generate` + `xcodebuild test` ile 32/32 test geçti (tanılama
log'ları test ortamını etkilemiyor, sadece ek konsol çıktısı).

## 9. Yedinci tur: kaydırma tamamen kaldırıldı

Kullanıcı, kaydırmanın hızlı kullanımda hâlâ sorunlu olduğunu somut bir
deneyle netleştirdi ("18 kere hızlı fiske + aynı anda 18 kere 'Allah'
deme, bıraktığım an durmuyor, titreşim/ses geriden geliyor, 'Sayıyı
Sesli Söyle' kapalıyken bile") ve sordu: bu özellik ya kaldırılsın ya da
VoiceOver'a bağımlı olmayan farklı bir yöntemle değiştirilsin.

**Değerlendirme (kullanıcıyla paylaşıldı):** Kaydırma
(`accessibilityAdjustableAction`) tamamen VoiceOver'ın kendi jest tanıma/
dağıtım hattına bağlı; Bölüm 8'in tanılamasıyla (konuşma kapalıyken de
gecikme sürmesi) uygulama kodunun (persistence, haptic/ses üreteçleri,
`countFeedback`) hızlı olduğu zaten gösterilmişti — geriye kalan tek
açıklama VoiceOver'ın kendisinin jestleri geç işlemesi/dağıtması, ki bu
uygulama koduyla düzeltilemez.

VoiceOver'a bağımlı olmayan bir alternatif teorik olarak mümkündü:
Hızlı Sayım'ın `allowsDirectInteraction` yüzeyine tek dokunuşun yanına
ham (VoiceOver'a hiç uğramayan) bir sürükleme/kaydırma algılaması da
eklenebilirdi. Ama bunun ana ekrandaki her zaman açık sayma yüzeyine
(değil, sadece Hızlı Sayım'a) uygulanması ciddi bir risk taşırdı: VoiceOver
kullanıcılarının çoğu ekranı parmakla gezerek keşfeder (touch
exploration); o alan sürekli direkt-dokunma olsaydı, kullanıcı sadece
ekranı keşfederken bile yanlışlıkla sayabilirdi. Bu risk zaten Hızlı
Sayım'da kabul edilmişti (kullanıcı bilinçli olarak o moda giriyor),
ana ekranda kabul edilmesi doğru olmazdı.

**Kullanıcının kararı:** Kaydırmayı tamamen kaldır; Hızlı Sayım'a da
ayrıca kaydırma/sürükleme ekleme — Hızlı Sayım zaten her dokunuşta
ilerlediği için ek bir sürükleme desteğinin marjinal faydası yok.

**Uygulanan değişiklik:**
- `SayacView.countingSurface`'ten `.accessibilityAdjustableAction` ve
  buna bağlı `undo()` çağrısı tamamen kaldırıldı; hint metni "Değeri
  artırmak için yukarı, azaltmak için aşağı kaydırın" kısmından
  temizlendi (Geri Al hâlâ ayrı düğmeyle yapılıyor, kayıp yok).
- `CounterViewModel.increment(isSwipeTriggered:)` → `increment()`'e
  sadeleştirildi, `isSwipeTriggered`/`swipeHapticEnabled` ayrımı
  tamamen kaldırıldı (artık tek bir "titreşim+ses her zaman" davranışı
  var, Say düğmesiyle tutarlı).
- `UserSettings.swipeHapticEnabled` alanı silindi; eski kayıtlı JSON'da
  bu anahtar olsa bile `JSONDecoder` bilinmeyen anahtarları sessizce
  yok sayar, decode bozulmaz (regresyon testiyle doğrulandı).
- Ayarlar'daki "Kaydırırken Titreşim" satırı kaldırıldı.
- Bölüm 8'de eklenen geçici tanılama (`diagnosticsLog`,
  `FeedbackProviding.swift` ve `SayacView.swift`) tamamen kaldırıldı —
  soru koda ihtiyaç duymayacak şekilde (özelliği kaldırarak) çözüldü,
  tanılamaya artık gerek yok.
- Testler: `swipeTriggeredIncrementRespectsHapticSetting` silindi
  (konusu kalmadı); `tickPlaysWhenEnabledRegardlessOfSpokenCountSetting`,
  `tickDoesNotPlayWhenSoundEffectIsDisabled`, `incrementFast*` testleri
  `swipeHapticEnabled`/`isSwipeTriggered` kullanmayacak şekilde
  güncellendi; `legacySettingsJSONPreservesFieldsAndDefaultsSoundEffectToEnabled`
  eski JSON'da `swipeHapticEnabled` anahtarını KASITLI OLARAK tutuyor
  (artık kullanılmayan bir alan olsa da decode'un bozulmadığını
  doğrulamak için regresyon testi).

**Ana ekrandaki sayma yöntemleri artık:** çift dokunuş (VoiceOver
açık)/tek dokunuş (VoiceOver kapalı) üzerinde `countingSurface`, Say
düğmesi, Geri Al düğmesi. Gerçek hızlı/ritmik sayım için: Hızlı Sayım
(Ayarlar'dan açılır, Sihirli Dokunuşla aç/kapa, tek dokunuşla ilerler,
VoiceOver'ın jest hattını tamamen atlar).

`xcodegen generate` + `xcodebuild test` ile **31/31 test geçti** (bir
test kaldırıldığı için 32'den düştü), build başarılı.

## 10. Sekizinci tur: Hızlı Sayım baştan tasarlandı — artık ham dokunuş yok

Kullanıcı, Hızlı Sayım'ın "açıldığında nereye dokunursam ilerliyor"
davranışının VoiceOver kullanacak kişiler için karışık olduğunu
belirtti ve özelliği baştan sona, tüm olasılıklar düşünülerek yeniden
ele almamı istedi.

**Kök sorun tespiti:** `allowsDirectInteraction` (Bölüm 7'den beri
kullanılıyordu), VoiceOver kullanıcısının güvendiği temel etkileşim
modelini bozuyor: normalde VoiceOver'da **dokunmak sadece keşfeder/
odaklanır** (ne olduğunu söyler), **çift dokunmak** kararlı eylemi
yapar. Bu iki aşamalı model, kazara etkileşimi engelleyen güvenlik
ağıdır. Ham dokunuş alanında ise TEK dokunuş bile anında sayıyor —
kullanıcı sadece ekranı parmağıyla gezip "burada ne var" diye
keşfederken bile yanlışlıkla sayabilir. Bu, "VoiceOver kullanacak
kişiler için karışık" şikayetinin tam olarak kaynağı.

**Düşünülen alternatifler:**
1. Direkt-dokunma alanını küçültüp sadece büyük sayı kartına
   sınırlamak — sorunu azaltır ama ortadan kaldırmaz, kart içinde
   keşif hâlâ sayar.
2. VoiceOver kapalıyken ham dokunuş, açıkken farklı bir mekanizma
   (duruma göre dallanma) — karmaşıklığı artırır.
3. **Seçilen çözüm:** VoiceOver'ın kendi, iyi bilinen ve belgelenmiş bir
   özelliğini kullanmak: **çift dokunuş jesti, ekrandaki fiziksel
   konumdan bağımsız olarak o an ODAKTAKİ öğeyi etkinleştirir** (Apple
   VoiceOver Kullanıcı Kılavuzu'nda belgelenen, düşük görme/motor
   beceri güçlüğü olan kullanıcılar için tasarlanmış bir kolaylık).
   Buna göre: Hızlı Sayım açılınca VoiceOver odağı sayma düğmesine
   programatik olarak kilitlenir (`@AccessibilityFocusState`); kullanıcı
   artık ekranın HERHANGİ BİR YERİNDE çift dokunarak sayabilir — "nerede
   olursan ol dokun, ilerlesin" kolaylığı korunuyor, ama VoiceOver'ın
   kendi güvenli iki-aşamalı modeliyle: kazara tek-dokunuşla keşif artık
   hiçbir şeyi saymıyor, sadece deliberate çift dokunuş sayıyor.

**Uygulanan değişiklikler:**
- `HizliSayimYuzeyi.swift` (ham `UIViewRepresentable` + `allowsDirectInteraction`)
  dosyası tamamen silindi — artık hiçbir yerde ham dokunuş yok.
- `SayacView.fastCountButton`: gerçek bir SwiftUI `Button`, tüm Hızlı
  Sayım ekranını kaplıyor (görsel/dokunma kolaylığı için hâlâ büyük),
  ama artık normal VoiceOver çift-dokunuş semantiğiyle çalışıyor.
  `accessibilityLabel` = "Hızlı Sayım Açık", `accessibilityValue` =
  güncel sayı, `accessibilityHint` bu davranışı açıkça anlatıyor
  ("Ekranın herhangi bir yerinde çift dokunarak sayabilirsiniz...").
- `isFastCountButtonFocused` (`@AccessibilityFocusState`) Hızlı Sayım
  açılınca `true` yapılıyor — VoiceOver odağı otomatik oraya taşınıyor,
  kullanıcı manuel gezinmek zorunda kalmıyor. Ekrandan çıkınca
  (`onDisappear`, `path` değişince) `false`'a dönüyor.
- Açılışta ayrı bir "Hızlı sayım açıldı" anonsu KALDIRILDI — odak
  değişince VoiceOver zaten düğmenin etiketini doğal olarak okuyor,
  ayrı anons üst üste binip karışıklık yaratırdı. Kapanışta "Hızlı sayım
  kapatıldı" anonsu korundu (normal ekrana dönüşte otomatik odak
  değişimi aynı netlikte olmayabilir).
- Görsel üst şerit (`fastCountVisualHeader`: "Hızlı Sayım Açık" +
  canlı sayı) VoiceOver'a `accessibilityHidden(true)` — aynı bilgi
  zaten `fastCountButton`'ın `accessibilityValue`'sünde var, ayrı bir
  VoiceOver durağı olarak tekrarlanması gezinmeyi gereksiz uzatırdı; az
  gören/gören kullanıcı için hâlâ görünür.
- "Kapat" düğmesi yedek olarak duruyor (normal VO gezinmesiyle
  ulaşılabilir); Sihirli Dokunuş birincil kapama yöntemi.
- **Yan fayda:** Bölüm 7.4'te açık bırakılan "Magic Tap,
  `allowsDirectInteraction` alanının İÇİNDE de güvenilir çalışıyor mu"
  sorusu artık konu dışı — hiçbir yerde `allowsDirectInteraction`
  kalmadığı için bu belirsizlik tamamen ortadan kalktı.

**Açık nokta (cihazda doğrulanmalı):** Çift dokunuşun, hızlı art arda
(dhikr temposunda) tekrarlandığında VoiceOver tarafından gecikmeden
işlenip işlenmediği — bu, Bölüm 8'de sorunlu bulunan "adjustable swipe"
jestinden farklı, VoiceOver'ın en çok kullanılan/optimize gesture'ı
olduğu için daha iyi performans beklenir, ama kesin garanti verilemez.
Kullanıcının aynı "hızlı art arda + bırak" senaryosunu bu yeni tasarımla
tekrar test etmesi gerekiyor.

`xcodegen generate` + `xcodebuild test` (iPhone 17 simülatörü) ile
**31/31 test geçti**, build başarılı.
