# Tesbihim planı — iOS, erişilebilirlik ve ürün incelemesi

İncelenen belge: `PLAN.md` (15 Temmuz 2026). Bu görüş, yalnızca planı değerlendirir; henüz çalışan uygulama olmadığı için uygulama içi davranış doğrulanmış değildir.

## Öncelikli kararlar

1. Hızlı Sayım'ı koruyun; fakat doğrudan dokunuş alanını `.requiresActivation` ile etkinleştirin, alanın dışında erişilebilir bir çıkış/alternatif sayma yolu bırakın ve gerçek VoiceOver kullanıcılarıyla yanlış-sayım testi yapmadan yayınlamayın.
2. Faz 1 başlamadan önce veri saklama kararını verin. Sayaç, oturum geçmişi, özel zikir ve ayarları ayrı domain modelleri; onları kullanan UI'dan bağımsız bir repository/protokol sınırı olarak tasarlayın. Sonradan CloudKit ekleme kararı bu seçimi etkiler.
3. iOS 18, Xcode 27, iOS 27 ve Nisan 2027 gönderim zorunluluğunu kesin gerçek gibi proje gereksinimi yapmayın. Bunları "yayın zamanında doğrulanacak platform politikası" maddesine çevirin; yalnızca Apple'ın o günkü sürüm/SDK kurallarıyla karar verin.
4. Destekçi paketinin açtığı öğeleri lansmanda kesinleştirin; "ek temalar/sesler" şeklinde geleceğe dönük belirsiz bir vaat bırakmayın. Gönüllü ödemeyi hayır bağışı değil, geliştiriciye isteğe bağlı destek olarak adlandırın.

## 1. Mimari ve teknik yığın

### Yerinde olanlar

- SwiftUI + MVVM, bu boyuttaki yerel-öncelikli uygulama için yeterli ve uygun bir başlangıçtır.
- İş kurallarını ViewModel testleriyle ayırma, StoreKit Configuration ile yerel ödeme testi ve proje üretimini tekrarlanabilir kılma niyeti doğru.
- Çevrimdışı ve anında kayıt, zikir uygulamasının güven duygusu için doğru varsayımdır.

### Somut öneriler

- **Persistansı Faz 1 içinde belirsiz bırakmayın.** SwiftData ile `Codable+dosya` arasında seçim, proje iskeletinden önce yapılmalı. Geçmiş, silme, iCloud ve widget aynı veriyi tüketecek. `CounterRepository`/`ZikirRepository` gibi küçük protokoller arkasında bir saklama katmanı kurun; ViewModel'ler `ModelContext`, `UserDefaults` veya dosya yolunu doğrudan bilmesin.

- **Modeli “anlık sayaç”tan daha açık tanımlayın.** En az `DhikrDefinition` (hazır/özel, metin, dil, kaynak), `CounterState` (seçili zikir, hedef, güncel sayı, güncellenme zamanı), `Session` (başlangıç/bitiş, tamamlanma, sayım deltasının geçmişi) ve `UserSettings` (geri bildirim ve erişilebilirlik tercihleri) ayrılmalı. `Undo` yalnızca ekranda son sayıyı azaltmak değil, uygulama kapanıp açıldıktan sonra da son eylem için güvenilir olmalı; bu nedenle sayım eylemi ya da en azından geri alınabilir son delta kalıcı olmalı.

- **Geçmiş metriklerini şimdi tanımlayın.** “Bugün / bu hafta / toplam”ın neyi saydığı belirsiz: tamamlanan hedef mi, ham tekrar sayısı mı, oturum mu? Zaman dilimi, gece yarısı ve uygulama tekrar açıldığında yarım kalan oturum davranışı için tek bir kural yazın. İstatistikte doğru olmayan dinî/kişisel çıkarımlar üretmeyin.

- **CloudKit'e hazırlık ile CloudKit entegrasyonunu ayırın.** Faz 2 senkronizasyonunda silinen özel zikirler, iki cihazın aynı sayaçta yaptığı değişiklik, oturum çakışması ve ilk indirme davranışı tasarlanmalı. “Son yazan kazanır” sayaç için sayım kaybettirebilir. Faz 1'de tek-cihaz garantisi açıkça belirtilsin; Faz 2'de oturum/olay tabanlı birleştirme ya da çakışma kuralı seçilsin.

- **Widget için App Group notu ekleyin.** Faz 2 widget'ı aynı veriyi okuyacaksa saklama seçimi ve erişim sınırı şimdiden App Group'la uyumlu olmalı. Widget'ın doğrudan sayımı artırıp artırmayacağını da baştan karara bağlayın; kilit ekranı/uygulama yaşam döngüsünde güvenilirlik maliyeti yüksektir.

- **MVVM'i katman adıyla sınırlamayın.** `Views/ViewModels/Models` klasörleri yeterli mimari değildir. Sayma kuralı, geri bildirim kararı ve StoreKit entitlement'ı UI'dan bağımsız servislerde olmalı. Özellikle ses/titreşim kararını ViewModel'den çıkarıp test edilebilir bir `FeedbackProviding` arayüzüne koyun.

- **XcodeGen için doğrulama kuralı yazın.** `project.yml` tek doğruluk kaynağı olabilir; ancak CI'da `xcodegen generate` sonrası fark olmadığını ve scheme/test planlarının çalıştığını denetleyin. Üretilen `.xcodeproj`'un repoda tutulup tutulmayacağı ayrıca netleşsin; aksi halde geliştirici makinesi ile CI'ın farklı proje üretmesi kolaydır.

- **Minimum iOS sürümünü kullanıcı verisiyle seçin.** iOS 18, özellikle yaşlı kullanıcı kitlesinde gereksiz cihaz dışlaması yaratabilir. iOS 18'e özgü bir zorunluluk yoksa daha düşük, desteklenebilir bir sürüm değerlendirin; yeni görsel API'leri `#available` ile isteğe bağlı kullanın. “Liquid Glass” çekirdek deneyimin teknik bağımlılığı olmamalı.

- **Bölüm 9'daki gelecek sürüm adlarını doğrulanmamış varsayım olarak işaretleyin.** Bu tarih/sürüm iddiaları planın mimari kararını belirlememeli. Yayın kontrol listesine “geçerli App Store minimum Xcode gereksinimini ve hedef SDK'yı Apple Developer News'ten doğrula” maddesi eklemek daha dayanıklıdır.

## 2. Erişilebilirlik ve Hızlı Sayım / DirectTouch

### Teknik doğruluk ve değer

Planın seçtiği SwiftUI `accessibilityDirectTouch(_:options:)` API'si gerçek bir çözümdür: doğrudan dokunuş bölgesindeki jestleri VoiceOver yerine uygulamaya geçirir. Apple bu alanı piyano klavyesi, oyun oynatıcı yüzeyi ve imza alanı gibi doğrudan etkileşim örnekleri için tarif eder. Dolayısıyla sayma yüzeyi için kullanılabilir; “App Store'a aykırıdır” diye bir sonuç yoktur. Ancak bu API standart VoiceOver gezinmesini o alan içinde devre dışı bırakır; bu nedenle normal bir düğmeye eklenen küçük bir trait gibi ele alınmamalıdır. [Apple: Direct Touch](https://developer.apple.com/documentation/swiftui/view/accessibilitydirecttouch%28_%3Aoptions%3A%29), [Apple: seçenekler](https://developer.apple.com/documentation/uikit/uiaccessibility/directtouchoptions)

### Değişmesi gerekenler

- **`.requiresActivation` zorunlu tasarım tercihi olsun.** Salt “opt-in ayar” yeterli koruma değildir. Bu seçenek, kullanıcı VoiceOver odağındaki alanı önce çift dokunarak etkinleştirene kadar dokunuşların geçmesini engeller. Böylece kullanıcı yüzeyi keşfederken yanlışlıkla zikri artırmaz; etkinleştirdikten sonra ardışık tek dokunuş sayımı yapabilir. Etkinleştirme anında kısa, net bir duyuru verin: “Hızlı Sayım etkin. Bu alan içindeki her dokunuş bir ekler. Çıkmak için Hızlı Sayımı Kapat düğmesine gidin.”

- **DirectTouch alanı tek ve sınırlı olsun.** Sadece büyük sayma yüzeyi doğrudan dokunuş alanı olsun; sayıyı, hedefi, geri almayı ve gezinmeyi kapsayan tam ekran alanı yapmayın. Alt aksiyonlar normal erişilebilir kontroller olarak alanın dışında kalsın. Sayma alanında sesli geri bildirim üretilecekse `.silentOnTouch` ancak uygulamanın kendi net geri bildirimi varsa değerlendirilmelidir; aksi halde VoiceOver sessizliği kullanıcıyı belirsizlikte bırakır.

- **Güvenli çıkış ve hata düzeltme akışı yazın.** DirectTouch açıkken her sayımda büyük bir sayı değiştiği için yanlış dokunma maliyetlidir. Her zaman erişilebilir “Son sayımı geri al” düğmesi, sayım sonrası kısa haptic/ses ve hedefe ulaşınca belirgin ama rahatsız etmeyen geri bildirim gerekir. “Sıfırlama kilidi” yanında “geri alma için zaman penceresi veya son N eylem” kararı da yazılmalı. DirectTouch'ı kapatma, ayarlara gömülü tek yol olmamalı.

- **Konuşma kuyruğunu yönetin.** Her tek dokunuşta “18, 19, 20…” anonsu VoiceOver konuşma kuyruğunu hızla kullanılmaz yapar. Varsayılan olarak kısa haptic/ses, kullanıcının seçebileceği aralıklı sesli duyuru (ör. her 10 sayım), hedefte anons ve isteğe bağlı “mevcut sayı” düğmesi daha iyi olur. `updatesFrequently` trait'i de otomatik anons stratejisinin yerine geçmez.

- **Standart, DirectTouch dışı eşdeğer eylem şart.** Apple'ın değerlendirme ölçütü, standart bir dokunmanın VoiceOver seç+çift dokunma ile aynı davranışı üretmesini bekler. Normal modda sayma düğmesi bu davranışı sağlamalı; ayrıca VoiceOver için `accessibilityAdjustableAction` ile artır/azalt veya açık etiketli Say / Geri Al düğmeleri, eylemler rotorunda da bulunabilir. DirectTouch hızlandırıcıdır, tek erişim yolu değildir. [Apple VoiceOver değerlendirme ölçütleri](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voiceover-evaluation-criteria/)

- **Switch Control ve Voice Control için ayrı kabul kriteri yazın.** DirectTouch bu teknolojilerde doğal bir çözüm değildir. Voice Control ile “Say” adlı düğme sesle bulunup çalışmalı; Switch Control ile sırayla odaklanıp standart aktivasyonla sayılabilmeli. “VoiceOver ile test edildi” sonucu bu ikisini kapsamaz.

- **Odak ve modal davranışlarını test edin.** Hızlı Sayımı etkinleştirme/bitirme, zikir değiştirme, hedef tamamlama ve sıfırlama onayında VoiceOver odağının mantıklı yeni öğeye taşınması gerekir. Onay ekranı arka plandaki sayma alanını erişilebilir bırakmamalıdır. Her görünür durum metni, özellikle “duraklatıldı”, “hedef tamamlandı” ve mevcut hedef, VoiceOver ile okunabilir olmalı.

- **Ayar metnini bir uyarı ile tamamlayın.** İlk açılışta “Hızlı Sayım nedir?” kısa demo/önizleme verin ve her zaman kapalı başlayın. Yaşlı kullanıcı için “tek dokunuş” vaadi, kazara dokunma riskini dürüstçe anlatmadan yanıltıcı olabilir.

## 3. Özellik kapsamı ve fazlar

### Yerinde olanlar

- Reklam, sosyal yarış ve streak mekaniklerini kapsam dışında tutmak ürünün sakin karakterini korur.
- Önce çalışır sayaç, sonra erişilebilirlik katmanı ve kullanıcı testi yaklaşımı doğru yöndedir.

### Faz 1'i küçültme ve tamamlama

- **Faz 1 şu an sınırda fazla geniş.** Sayaç, DirectTouch, hazır kaynaklı kütüphane, özel içerik CRUD'u, kalıcı geçmiş, üç geri bildirim profili, tema, onboarding ve iki IAP türü birlikte hem ürün hem test yüzeyini büyütür. İlk TestFlight diliminde yalnızca sayaç + kalıcı durum + standart erişilebilir sayma + geri al/sıfırla + temel ayarlar olmalı; DirectTouch bunun üzerinde ikinci dilim olarak eklenmeli. Bu, DirectTouch riskini içerik ve ödeme karmaşasından ayrı doğrulatır.

- **İçerik kalitesi bir yayın bağımlılığıdır.** Hazır zikir metni, Arapça, okunuş, anlam ve kaynak için editoryel kaynak, sorumlu kişi, sürüm tarihi ve düzeltme prosedürü ekleyin. Metni/okunuşu kullanıcı değiştirebiliyor mu, hazır içerik güncellenince kullanıcının seçimi ne olur, lisanslı ses kaydı kullanılacak mı: bunlar belirsiz. Hatalı dinî metin, sıradan bir UI hatasından daha yüksek güven kaybı yaratır.

- **“Duraklat”ın anlamını tanımlayın ya da çıkarın.** Sayma zaten kullanıcı dokunuşuyla ilerliyorsa duraklatmanın neyi engellediği belli değil. DirectTouch açıkken dokunuşları mı bloke eder, yeni oturumu mu kapatır? Net bir semantiği yoksa MVP'de gereksiz bilişsel yük olur.

- **Geçmiş için güvenli minimum belirleyin.** Toplam sayı ve gün bazında oturum kaydı yeterliyse haftalık görünümü basit tutun. Grafik, dışa aktarma, hedef serileri ve başarı dili Faz 2'ye ait. Kullanıcının geçmişi silme ve tüm yerel veriyi silme işlemleri Faz 1'de bulunmalı.

- **Faz 2'yi ayrıştırın.** Widget/Live Activity, Watch, CloudKit, grafikler ve sesli kayıtlar beş ayrı büyük iş. Özellikle Watch, farklı bir etkileşim/erişilebilirlik test matrisi getirir. Önce gerçek kullanım verisiyle en değerli olanı seçin; varsayılan sıra olarak iCloud (talep varsa) → widget → Watch daha makul, Live Activity ise ayrı bir gerekçe olmadan ertelenebilir.

- **App Intents'ı Faz 3'ten Faz 2 değerlendirmesine alın.** “Zikri aç”, “sayacı göster” gibi sınırlı, güvenli App Intent'ler sesle otomatik saymadan çok daha düşük risklidir ve Voice Control/Siri erişimini güçlendirebilir. Buna karşılık mikrofonla otomatik sayım hem yanlış pozitifler hem gizlilik/izin hem de dinî kullanım güveni nedeniyle ancak araştırma prototipi olmalıdır.

## 4. Monetizasyon ve App Store uyumu

- **Kural atfını düzeltin.** Plan “3.2.1”i bağış/bahşiş gerekçesi olarak anıyor; uygulama içindeki geliştiriciye bahşiş niteliğindeki dijital ödeme için esas referans 3.1.1'dir. 3.2.1(vi) ise onaylı kâr amacı gütmeyen kuruluşlar için bağış toplama istisnasını kapsar. Bu yüzden ekranda “bağış” veya hayır kurumu çağrışımı yerine “Geliştiriciyi destekle” kullanın. [App Review Guidelines 3.1.1 ve 3.2.1](https://developer.apple.com/app-store/review/guidelines/)

- **Model genel olarak uygundur.** Özellik açan Destekçi paketi non-consumable, karşılıksız isteğe bağlı destek ise consumable IAP olarak kurulabilir. Apple, non-consumable ürünlerin tükenmediğini; consumable ürünlerin yeniden satın alınabildiğini açıkça tanımlar. [Apple StoreKit ürün türleri](https://developer.apple.com/documentation/storekit/getting-started-with-in-app-purchases-using-storekit-views)

- **Destekçi değerini ilk sürümde netleştirin.** “Ek temalar/sesler” yalnızca Faz 2'de, henüz tanımsızsa Faz 1'de paket satmak kullanıcı güvenini zedeler. İki güvenli seçenek var: (a) paketi, bugün açıkça listelenmiş küçük kozmetik öğelerle lansmana koymak veya (b) IAP'yi Faz 2'ye ertelemek. Çekirdek erişilebilirlik özellikleri, geçmiş ve reklamsızlık pakete bağlanmamalı; plan bu konuda doğru.

- **Fiyat artışını kullanıcı sayısına bağlamayın.** “Belirli kullanıcı sayısından sonra” mekanizması yapay kıtlık/acele baskısı gibi görünür. Fiyat ve değer zamanla değişecekse ekranda güncel App Store yerel fiyatını gösterin; mevcut sahiplerin erişimi sürecek şekilde fiyat değişikliği kararını şeffaf ve ürün maliyetine bağlı alın. Türkiye fiyatları için sabit TL vaadini lansman öncesi App Store Connect'te yeniden doğrulayın.

- **Restore Purchases, transaction gözlemi ve iptal durumları planlanmalı.** Ayarlar'da açık “Satın Alımları Geri Yükle” bulunmalı; non-consumable entitlement uygulama açılışında doğrulanmalı ve transaction güncellemeleri dinlenmelidir. Apple, non-consumable satın alımlar için geri yükleme yolunun verilmesini ister. Consumable “destek” için geri yükleme ile yeniden teslim edilecek bir hak vaat etmeyin. [Apple: satın alımları geri yükleme](https://developer.apple.com/documentation/storekit/restoring-purchased-products)

- **Gönüllü destekten sonra teşekkür edin, baskı uygulamayın.** İlk zikir tamamlanınca tek seferlik, kolay kapatılabilir davet makul; tekrar eden tam ekran istek, geri sayım veya suçluluk dili kullanmayın. Üç seçeneğin de aynı metin/değer yapısında, yalnızca tutar farkıyla sunulması güven verir. İade ve Apple satın alma yönetimi için sistem akışına/yardım bağlantısına yer verin.

## 5. Yaşlı ve VoiceOver kullanıcısının günlük deneyimi

- **Ana ekran bir “tek karar” ekranı olmalı.** İlk açılışta tek büyük sayı alanı, seçili zikir adı, hedef ve en fazla üç ikincil eylem görünmeli. Kütüphane, geçmiş ve ayarlar sekme/menü düzeyinde kalsın. Büyük alanın her dokunuşunun saydığı tasarımda, etraftaki dekoratif/yanlışlıkla tıklanabilir öğeler özellikle zararlıdır.

- **Dokunma hedefleri ve hata toleransı kabul kriteri olsun.** Büyük metin tek başına yeterli değil: geri al, zikir değiştir, hedef ayarla ve kapat düğmeleri rahat ayrık hedefler olmalı. Silme/sıfırlama için “basılı tut” jesti VoiceOver, Switch Control ve motor kısıtlı kullanıcılar için tek koruma olmamalı; erişilebilir onay iletişimi de sunun.

- **Dinî içerikte okunabilirlik ayrı test edilmelidir.** Arapça metin büyük yazı boyutunda satır kırmadan/harf kesmeden, Türkçe anlam/okunuşla karışmadan gösterilmeli. VoiceOver'ın Arapça telaffuzu cihaz dili ve yüklü seslere göre değişebilir; dil özniteliği ve gerçek cihaz testleri gerekir. Metni kopyalama veya sadece Türkçe okunuşla sayma tercihi de bazı kullanıcılar için gerekli olabilir.

- **Geri bildirim profillerinde varsayılan sakin olmalı.** Titreşim, işitme cihazı kullanan veya hassasiyet yaşayan kişiler için yorucu olabilir. Varsayılan sessiz/çok hafif geri bildirim, her geri bildirim türünü ayrı açıp kapatma ve hedef tamamlamasını ayrı ayarlama daha kapsayıcıdır. Sesli geri bildirim, VoiceOver konuşmasını bastırmamalı.

- **Onboarding atlanabilir ama keşfedilebilirlik kaybolmamalı.** Yaşlı kullanıcı “atla”yı seçtiğinde Hızlı Sayım, geri alma ve sıfırlama mantığını sonradan Ayarlar dışında bulabilmeli. Ana ekranda erişilebilir bir “Nasıl kullanılır?” bağlantısı ve kısa, dil sadeleştirilmiş yardım ekleyin.

- **Yalnız test cihazı değil senaryo testi yapın.** En büyük Dynamic Type, Bold Text, Increase Contrast, Reduce Transparency, Reduce Motion, koyu/açık tema, VoiceOver, Voice Control, Switch Control, Bluetooth klavye ve uygulama arka plana gidip geri gelme senaryolarını kabul matrisi yapın. Apple'ın App Store Connect erişilebilirlik ölçütleri, destek beyanının ortak görevlerin yalnız VoiceOver ile tamamlanabilmesine dayanmasını önerir. [Apple VoiceOver değerlendirme ölçütleri](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voiceover-evaluation-criteria/)

## 6. Planda eksik olan ek maddeler

- **Gizlilik açıklaması ve veri yaşam döngüsü:** “takipsiz” vaatini teknik olarak yazın: ağ isteği var mı, crash raporlama var mı, iCloud açılınca hangi veriler senkronize olur, yerel veriler nasıl silinir? Gizlilik politikası, destek e-postası ve veri silme açıklaması Faz 1 yayın kontrol listesinde olsun.

- **Yedekleme/cihaz değişimi mesajı:** Faz 1 tek cihazsa bunu açıkça söyleyin. Kullanıcının “iPhone değiştirince zikrim kaybolur mu?” sorusunun cevabı olmalı. iCloud senkronizasyonu gelene kadar iOS yedeğine güvenilip güvenilmediği ve manuel dışa aktarmanın olup olmayacağı belirlenmeli.

- **Hata ve kesinti dayanıklılığı:** Sayma dokunuşundan sonra kalıcı yazma başarısız olursa, uygulama sonlandırılırsa, ses/titreşim izni/kaynağı yoksa veya StoreKit ürünleri yüklenmezse görülecek kullanıcı davranışını tasarlayın. Sayaç hiçbir zaman sessizce geriye gitmemeli; başarısızlık durumunda anlaşılır ve erişilebilir uyarı vermeli.

- **Erişilebilirlik kabul kriterleri:** “Etiket var mı?” otomasyonu yeterli değildir. Her ekran için odak sırası, label/value/hint, eylem, Dynamic Type taşması, modal odağı ve DirectTouch giriş-çıkış davranışını içeren manuel test senaryoları yazın. Bu senaryolar App Review notlarına Hızlı Sayımın neden var olduğunu ve nasıl test edileceğini de açıklamak için kullanılabilir.

- **App Review notu:** İncelemeci için Hızlı Sayım ayarının yeri, varsayılanının kapalı olduğu, `.requiresActivation` koruması ve normal VoiceOver sayma yolunun bulunduğu kısa bir açıklama ekleyin. IAP ürünlerinin uygulamada nereden erişildiğini de not edin; Apple, incelemecinin ürünleri bulabilmesini bekler.

- **Destek ve içerik düzeltme kanalı:** Yanlış metin/çeviri bildirme, erişilebilirlik geri bildirimi ve satın alma sorunları için görünür bir destek e-postası/formu ekleyin. Bu, özellikle görme engelli veya yaşlı kullanıcının yardım istemek için üçüncü kişiye bağımlı kalmasını azaltır.

## Önerilen yayın kapısı

App Store'a göndermeden önce şu üç koşul birlikte sağlanmalı:

1. VoiceOver açıkken normal sayma, Hızlı Sayım etkinleştirme/kapatma, geri al, sıfırla, zikir değiştirme ve satın alma geri yükleme sadece erişilebilir kontrollerle tamamlanabiliyor.
2. En az bir gerçek VoiceOver kullanıcısı ve bir yaşlı kullanıcı, yardım almadan ilk sayaçtan hedef tamamlamaya kadar akışı deniyor; yanlış sayım ve kafa karışıklığı gözlemleri kapatılıyor.
3. StoreKit'te non-consumable entitlement, Restore Purchases, iptal/bekleyen işlem ve ürünlerin yüklenememesi senaryoları cihazda test edilmiş; IAP açıklamaları uygulamadaki gerçek değerle bire bir uyumlu.
