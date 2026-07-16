# Faz 2 Zikir Yönetimi Taslağı — Son Uzman İncelemesi

Tarih: 2026-07-16

## Kısa sonuç

Taslağın yönü doğru, ancak kodlamadan önce dört karar düzeltilmeli:

1. Hazır zikirlerin değişmez kaynak tanımı korunmalı; fakat hatırlatıcı,
   arşiv durumu ve geri bildirim tercihi kaynak `DhikrDefinition` içine
   konmamalı. Bunlar kullanıcı katmanının ayrı verileridir.
2. Geri alınabilir işlem arayüzde “Sil” değil “Kaldır” olarak adlandırılmalı.
   Kullanıcının oluşturduğu zikir için Kaldırılanlar ekranında ayrıca kalıcı
   silme bulunmalı. “Tüm Verilerimi Sil” bunun yerine geçmez.
3. Bildirim izni ilk hatırlatıcı etkinleştirilirken istenmesi doğru; fakat
   izin durumu her form açılışında/uygulama öne geldiğinde sistemden yeniden
   okunmalı ve reddedilmiş durumda hatırlatıcı etkinmiş gibi kaydedilmemeli.
4. Ücretsiz temel ses/titreşim ve zikir başına “globali kullan/açık/kapalı”
   kontrolü korunmalı. Yalnızca ilave ses ve haptic karakterleri Destekçi
   paketine konabilir. Desteklenmeyen cihazda fallback her zaman hissedilir
   değildir; arayüz bunu başarısızlık gibi sunmamalı ama desteklenmeyen ücretli
   haptic seçeneğini de seçilebilir göstermemeli.

Sessiz saatler ve uygulamanın aynı saate düşen bildirimleri tek içerikte
birleştirmesi Faz 2’den çıkarılmalı. Kullanıcının seçtiği saati uygulamanın
sessizce değiştirmesi beklenmedik davranıştır; iOS zaten Focus ve Bildirim
Özeti sunar. Sistem düzeyindeki görsel gruplama gerekirse daha sonra
`threadIdentifier` ile düşük maliyetle eklenebilir, fakat bu “tek bildirim”
üretmek değildir.

## 1. Veri modeli: değişmez kaynak + kullanıcı override

### Eksik/yanlış olan

Değişmez hazır kütüphane ile kullanıcı değişikliklerini ayırmak doğru
karardır. Buna karşılık taslak, hatırlatıcı, tamamlanma davranışı,
ses/titreşim ve `deletedAt` alanlarını `DhikrDefinition`a ekleyerek iki ayrı
kavramı yeniden tek tipe dolduruyor:

- Kaynak tanımı: kimlik, varsayılan ad, Arapça metin, anlam, varsayılan hedef,
  kategori ve içerik sürümü.
- Kullanıcı durumu: alan override’ları, kaldırılma zamanı, hatırlatıcılar,
  tamamlanma tercihi ve geri bildirim profili.

Bir diff modelinde “override yok” ile “kullanıcı kaynakta bulunan opsiyonel
değeri bilerek temizledi” de ayrılmalıdır. Sıradan `String?` bu iki durumu
tek başına temsil edemez.

### Neden önemli

Tek mutable kayıt kısa vadede daha az tip gibi görünür; ancak “Varsayılana
Sıfırla” için orijinal kopya veya alan başına varsayılan tutmayı, kütüphane
güncellenince eski/yeni kaynağı uzlaştırmayı ve dini metnin kaynağını
kanıtlamayı zorlaştırır. Ayrı katman, kaynak metnin yanlışlıkla kalıcı
üzerine yazılmasını önler ve reset davranışını açık tutar.

### Somut öneri

- `BundledDhikrDefinition`: değişmez, kararlı `id`, içerik alanları ve
  `contentVersion`.
- `CustomDhikr`: kullanıcıya ait tam içerik kaydı, kararlı `id`, oluşturma ve
  güncelleme tarihleri.
- `DhikrUserState`: `dhikrID`, alan override’ları, `removedAt`, completion
  policy, feedback override ve reminder kimlikleri.
- Override alanlarında üç durum kullan: `.inherit`, `.set(value)`, `.clear`.
- Ekranlar yalnızca bir `ResolvedDhikr` okur; kaynak türünü bilmek zorunda
  kalmaz. Hazır ve özel zikir aynı formdan geçebilir, fakat depolama
  semantiğinin aynı olması gerekmez.
- “Varsayılana Sıfırla”, hazır zikirde içerik override’larını temizler.
  Hatırlatıcı gibi kişisel otomasyonları da silecekse onay metni bunu açıkça
  söylemeli; daha güvenli varsayılan, içerik reseti ile hatırlatıcıları ayrı
  tutmaktır.
- Kütüphane güncellemesinde yeni kaynak sürümü yalnız `.inherit` alanlara
  yansır; kullanıcı override’ı korunur.

Tek mutable model ancak her hazır kayıtta değişmez bir `originalSnapshot`
saklanırsa aynı garantileri verebilir. Bu, kaynak veriyi çoğaltır, sürüm
geçişlerini pahalılaştırır ve aslında örtük biçimde yine iki katman yaratır;
bu proje için önerilmez.

Ek veri bütünlüğü düzeltmesi: `HistoryEntry` adı “silinme anında” değil,
**kayıt oluşturulduğu anda** snapshot olarak tutmalıdır. Aksi halde bir zikir
önce yeniden adlandırıldığında eski geçmiş satırlarının hangi adı göstermesi
gerektiği belirsiz kalır. Gerekirse `dhikrID` de ayrıca korunur; kimlik ilişki
için, snapshot geçmişte görünen metin için kullanılır.

## 2. Kaldırma, arşivleme ve kalıcı silme

### Eksik/yanlış olan

İşlem gerçekte geri alınabilir arşivleme iken düğmede “Sil” yazması doğru
değildir. Kullanıcı özellikle kendi yazdığı bir metinde “sildim” ifadesinden
kalıcı kaldırmayı bekleyebilir. Uygulamadaki “Tüm Verilerimi Sil” bütün
geçmişi ve ayarları da yok eden nükleer bir işlemdir; tek bir özel zikri
kalıcı silmenin dengeli alternatifi değildir.

### Somut öneri

- Aktif listede eylem adı **“Kaldır”** olsun.
- Onay: “{ad}, Zikir Kütüphanesi’nden kaldırılacak. Kaldırılanlar bölümünden
  geri getirebilirsiniz.” Düğmeler: “İptal” ve “Kaldır”.
- Kaldırılanlar hem hazır hem özel zikirleri göstermeli.
- Hazır zikirde: “Geri Getir” ve gerekiyorsa “Varsayılana Sıfırla ve Geri
  Getir”. Paket içindeki kaynak fiziksel olarak silinemez; kullanıcıya bunun
  için sahte bir “kalıcı sil” vaadi verilmemeli.
- Özel zikirde: “Geri Getir” ve ikincil, destructive “Kalıcı Olarak Sil”.
  Onay metni, geçmiş kayıtlarının ad snapshot’larının korunup korunmayacağını
  açıkça söylesin. Öneri: tek zikir silme geçmişi otomatik silmesin; geçmiş
  yalnız ayrı “Geçmişi Sil” akışına ait olsun.
- Kalıcı silme gereksiz görünür karmaşıklık yaratmasın diye yalnız
  Kaldırılanlar içindeki özel zikir ayrıntısında bulunsun.

Apple HIG, geri alınamayan destructive işlemlerde onayı; geri alınabilen
işlemlerde ise gereksiz alertlerden kaçınmayı önerir. Kaldırma kolayca geri
alınabildiği için onay zorunlu tutulacaksa kısa ve sonucu açıklayan metin
yeterlidir; kalıcı silme için daha güçlü onay gerekir.

## 3. Bildirim izni ve VoiceOver akışı

### Doğru olan

İzni onboarding’de değil, kullanıcı hatırlatıcıyı ilk kez etkinleştirdiğinde
istemek Apple’ın bağlamsal izin yaklaşımıyla örtüşür. Apple, izin talebini
özelliğe ilgi gösterilene kadar ertelemeyi ve bildirim ayarlarını
`UNUserNotificationCenter.getNotificationSettings` ile kontrol etmeyi
öneriyor.

### Eksik olan durum makinesi

Form yalnız “izin var/yok” boolean’ı kullanmamalı:

- `.notDetermined`: Kullanıcı “Hatırlatıcıyı Aç” dediğinde kısa bağlam
  açıklaması göster, ardından `requestAuthorization(options: [.alert,
  .sound])` çağır. Badge gerekmiyorsa isteme.
- `.authorized` (ve bilinçli destekleniyorsa `.provisional`): haftalık
  `UNCalendarNotificationTrigger` isteklerini oluştur.
- `.denied`: etkin hatırlatıcı kaydetme/schedule etme. Formda kalıcı bir durum
  satırı ve **“Bildirim Ayarlarını Aç”** düğmesi göster.
- İzin verilmiş olsa bile `alertSetting` veya `soundSetting` ayrı ayrı kapalı
  olabilir. “Bildirim açık” ile “ses açık” aynı durum değildir; metin bunu
  doğru yansıtmalı.

Uygulama öne geldiğinde ve hatırlatıcı formu her açıldığında ayar yeniden
okunmalı. Kullanıcı Ayarlar uygulamasında izni değiştirebilir. Reddedilen
izin için tekrar tekrar sistem prompt’u çağırmak işe yaramaz; sistem ayarına
gidiş sunulmalıdır. `UIApplication.openNotificationSettingsURLString`, genel
uygulama ayarları yerine doğrudan uygulamanın Bildirimler sayfasını açar.

### Örnek erişilebilir metin ve odak

İzin ilk kez istenirken:

> Tesbihim, yalnız seçtiğiniz gün ve saatlerde zikir hatırlatıcısı göndermek
> için bildirim izni ister. Devam ettiğinizde iOS izin penceresi açılır.

Tek eylem: **“Devam”**. Sistem alert’ini taklit eden “İzin Ver” düğmesi
kullanılmamalı.

İzin reddedilmişse formda:

> Bildirimler kapalı. Bu hatırlatıcı gönderilemez. iPhone Ayarları’nda
> Tesbihim bildirimlerini açabilirsiniz.

Düğme: **“Bildirim Ayarlarını Aç”**. VoiceOver etiketi aynı, hint ise
“Tesbihim’in iPhone Bildirim ayarlarını açar.” olabilir. Ayarlardan dönüşte
durum satırı güncellenmeli ve odak, değişen “Bildirimler açık/kapalı”
başlığına kontrollü biçimde taşınmalı; aynı metni ayrıca konuşma kuyruğuna
ekleyip çift anons üretilmemeli.

Hatırlatıcı kimlikleri kararlı olmalı (`dhikrID + weekday + time`). Zikir
düzenlendiğinde eski bekleyen istekler kaldırılıp yenileri eklenmeli;
kaldırma/kalıcı silme sırasında ilgili bekleyen istekler iptal edilmeli.
Haftalık tekrar için `UNCalendarNotificationTrigger` tarih bileşenlerinde
takvim, saat ve hafta günü açıkça kurulmalı; saat dilimi/DST değişimi gerçek
cihaz test matrisine girmeli. Bildirim `userInfo` içinde yalnız kararlı
`dhikrID` taşımalı. Arşivlenmiş veya artık bulunamayan kimliğe dokunulursa
boş sayaç açmak yerine Kütüphane’ye güvenli fallback yapılmalı.

Bu hatırlatıcılar acil değildir; `timeSensitive` veya `critical` olarak
işaretlenmemeli. Bildirim gövdesi emir vermek yerine nötr bilgi vermeli:
“Sübhanallah için ayarladığınız hatırlatıcı.”

## 4. Ses/haptic override ve Destekçi paketi

### Monetizasyon sınırı

Kürate ek sesler ve ek haptic karakterleri dijital özellik olduğundan,
kilit açma App Review Guideline 3.1.1 uyarınca In-App Purchase kullanmalıdır.
Bu seçenekleri ücretli yapmak tek başına “çekirdek işlev” ilkesini bozmaz;
ancak aşağıdakiler ücretsiz kalmalıdır:

- Global ses açık/kapalı ve titreşim açık/kapalı.
- En az bir güvenilir sistem sesi ve bir temel sistem haptic geri bildirimi.
- Zikir başına `Global ayarı kullan / Kapalı / Açık` seçimi. Özellikle belirli
  bir zikirde sesi veya titreşimi kapatmak erişilebilirlik/konfor kontrolüdür,
  kozmetik değildir.
- VoiceOver veya sistem erişilebilirlik davranışının gerektirdiği bütün
  geri bildirimler.

Destekçi paketi yalnız “Ahşap”, “Cam”, “Yumuşak”, “Çift vuruş” gibi ek
karakterleri açmalıdır. Kilitli satırın etiketi fiyatı veya “Destekçi
paketi gerekir” durumunu açıkça söylemeli; sadece soluk renk/kilit simgesiyle
anlatılmamalı. Satın alma yoksa mevcut seçimi sessizce başka profile çevirmek
yerine kullanıcıya açık seçim sunulmalıdır.

### Donanım ve çalışma zamanı kırılmaları

`CHHapticEngine.capabilitiesForHardware().supportsHaptics` kontrolü doğru,
fakat “UIImpactFeedbackGenerator’a düşerse haptic kesin çalışır” garantisi
yoktur. Apple, iPad dahil bazı cihazların haptic desteklemediğini belirtiyor.
Bu nedenle:

- `supportsHaptics == false` ise özel haptic profillerini seçilebilir ücretli
  seçenek olarak gösterme; “Bu aygıtta özel titreşim desteklenmiyor” durumunu
  kısa ve erişilebilir biçimde göster.
- Uygunsa `UIImpactFeedbackGenerator` ile temel fallback dene; hiçbir haptic
  üretemeyen aygıtta sayım yine eksiksiz çalışsın ve hata alert’i çıkmasın.
- `CHHapticEngine` telefon araması, uygulamanın askıya alınması veya idle
  timeout nedeniyle durabilir. `stoppedHandler` ve `resetHandler` ile yeniden
  hazırlama/oynatıcıları yeniden oluşturma akışı tasarlanmalı.
- Kullanıcı girdisi hızlıyken ses ve haptic olayları kuyruklanmamalı. “En son
  geri bildirim kazanır” veya kısa throttle/coalescing uygulanmalı; parmak
  hareketi bittikten sonra saniyelerce geriden geri bildirim gelmemeli.
- Uygulama arka plana giderken oyuncular/engine temizlenmeli; ses oturumu
  kesintileri ve sessiz mod politikası gerçek cihazda sınanmalı.

## 5. Sessiz saatler ve bildirim gruplama

### Sessiz saatler: Faz 2’den çıkar

Kullanıcı haftalık hatırlatıcıda günü ve saati kendisi seçiyor. Sonra global
22:00–07:00 kuralıyla o bildirimi bastırmak veya başka saate taşımak iki ayrı
zamanlama modelinin çakışmasıdır. Yaşlı kullanıcı açısından “23:00 seçtim,
gelmedi” teşhisi zordur. iOS’un Focus ve Bildirim Özeti zaten kesinti
yönetimi sağlar. Tesbihim hatırlatıcıları Time Sensitive olmadığı için bu
sistem tercihlerini delmez.

Somut karar: Faz 2’de sessiz saat yok. Daha sonra kullanıcı talebi oluşursa
toggle değil, açık sonuç metni olan bir zaman aralığı ve “Bu aralıktaki
hatırlatıcılar ne zaman gönderilecek?” kuralı ayrıca tasarlanmalıdır.

### Aynı saatte tek bildirim: Faz 2’den çıkar

`threadIdentifier` aynı konudaki bildirimleri Notification Center’da görsel
olarak gruplar; aynı anda planlanan birden fazla yerel bildirimi tek bir
içerik ve tek dokunma hedefinde birleştirmez. Gerçek birleştirme için
uygulamanın bütün zaman çizelgesini yeniden hesaplaması, birleşik içeriği
güncellemesi ve dokunulduğunda hangi zikri açacağını çözmesi gerekir. Bu,
Faz 2 için değerinden pahalıdır.

Somut karar: Her hatırlatıcı ayrı ve kararlı bir istek olsun. Aynı zikrin
aynı gün/saat kaydı iki kez eklenemesin. Gerçek kullanımda bildirim
yorgunluğu görülürse önce sistemin `threadIdentifier` ile görsel gruplaması
değerlendirilsin; uygulama içi tek bildirim birleştirmesi ancak kullanıcı
araştırmasıyla gerekçelendirilirse tasarlansın.

## Kapsam temizliği: diğer yaratıcı öneriler

İkon/renk rozeti ve “Bugünün Zikri” bu veri modeli/bildirim işinin başarı
kriteri değildir. Faz 2 Zikir Yönetimi kilidine dahil edilmemeli. Rozet daha
sonra salt görsel tarama iyileştirmesi olarak değerlendirilebilir. “Bugünün
Zikri” ise içerik seçimi, dinî editoryal sorumluluk ve kapatma tercihi getirir;
ayrı ürün kararı olmadan eklenmemelidir.

## Kodlamadan önce kabul kriterleri

- Hazır kaynak, özel içerik ve kullanıcı durumu ayrı şemalara sahip.
- Override modeli `.inherit/.set/.clear` ayrımını test ediyor.
- Kaynak kütüphane sürüm yükseltmesi + kullanıcı override birleşimi testli.
- History adı giriş oluşturulurken snapshot alıyor.
- “Kaldır” her iki türde geri alınabilir; kalıcı silme yalnız özel zikirde ve
  Kaldırılanlar içinde.
- `.notDetermined/.authorized/.denied` ile alert/sound alt ayarları testli;
  ayarlardan dönüşte durum yenileniyor.
- Hatırlatıcı düzenleme/kaldırma eski `UNNotificationRequest`leri temizliyor.
- Bildirim deep link’i aktif, kaldırılmış ve bulunamayan kimliklerde güvenli.
- Ücretsiz temel feedback ve zikir başına kapatma seçeneği korunuyor.
- Core Haptics destek yok, engine stop/reset ve hızlı girdi backlog senaryoları
  gerçek cihazda test ediliyor.
- Sessiz saat, tek-bildirim birleştirmesi, rozet ve Bugünün Zikri bu kapsamda
  yok.

## Kaynaklar

- Apple Human Interface Guidelines — [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)
- Apple Human Interface Guidelines — [Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications/)
- Apple Human Interface Guidelines — [Managing notifications](https://developer.apple.com/design/human-interface-guidelines/managing-notifications)
- Apple Human Interface Guidelines — [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts)
- Apple Developer Documentation — [Asking permission to use notifications](https://developer.apple.com/documentation/UserNotifications/asking-permission-to-use-notifications)
- Apple Developer Documentation — [`UNNotificationSettings.authorizationStatus`](https://developer.apple.com/documentation/usernotifications/unnotificationsettings/authorizationstatus)
- Apple Developer Documentation — [`UIApplication.openNotificationSettingsURLString`](https://developer.apple.com/documentation/uikit/uiapplication/opennotificationsettingsurlstring)
- Apple Developer Documentation — [`UNCalendarNotificationTrigger`](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger)
- Apple Developer Documentation — [`threadIdentifier`](https://developer.apple.com/documentation/usernotifications/unmutablenotificationcontent/threadidentifier)
- Apple Developer Documentation — [`supportsHaptics`](https://developer.apple.com/documentation/corehaptics/chhapticdevicecapability/supportshaptics)
- Apple Developer Documentation — [Preparing your app to play haptics](https://developer.apple.com/documentation/corehaptics/preparing-your-app-to-play-haptics)
- Apple — [App Review Guidelines, 3.1.1](https://developer.apple.com/app-store/review/guidelines/)
