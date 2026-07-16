# Tesbihim Geçmiş ve İstatistikler Tasarımı

Tarih: 2026-07-16
Durum: Kullanıcı tarafından onaylandı; uygulama planı öncesi tasarım şartnamesi

## 1. Amaç

Geçmiş sekmesi, genel dönemsel seyir ile zikir bazlı ilerlemeyi dengeli ve
sade sunar. Kullanıcı bugün, hafta, ay ve tüm zamanlardaki tekrarlarını
anlayabilir; önceki dönemlerle tarafsız biçimde karşılaştırabilir; belirli bir
zikrin geçmişine inebilir.

Uygulama kör/VoiceOver kullanan ve gören kullanıcılar için eşdeğer işlev sunar.
Grafik görsel bir özet olabilir, fakat hiçbir veri yalnız grafik, renk veya
ikonla aktarılmaz.

## 2. Ürün İlkeleri

- Sade ana ekran, ayrıntıyı kademeli açma.
- Streak, seri kaybı, rozet, seviye, puan ve liderlik tablosu yok.
- Boş günler başarısızlık olarak işaretlenmez.
- Dil sakin ve yargılamaz.
- Ham tekrar birincil, tamamlanan hedef ikincil ölçüdür.
- Başarı yüzdesi yoktur; hedef bulunmayabilir veya zamanla değişebilir.
- Oturum süresi, başlangıç/bitiş saati ve tam olay günlüğü kapsam dışıdır.

## 3. Ana Ekran Bilgi Mimarisi

### 3.1 Bugün

Tekrar ve tamamlanan hedef özeti gösterilir. Örnek: "Bugün 247 tekrar, 3 hedef
tamamlandı." Kayıt yoksa: "Bugün henüz zikir kaydı yok."

### 3.2 Genel Bakış

- Bu Hafta: toplam tekrar ve zikir yapılan gün sayısı.
- Bu Ay: toplam tekrar ve zikir yapılan gün sayısı.
- Tüm Zamanlar: toplam tekrar.

Görsel kartlar kompakt boyutta yan yana olabilir. Dynamic Type büyüdüğünde
dikey akışa geçer. VoiceOver her kartı tek anlamlı blok olarak okur.

### 3.3 Bu Haftanın Seyri

Pazartesi-pazar sade çubuk grafik gösterilir. Çubuk yüksekliği yalnız günlük
net tekrar sayısını kodlar; hedef sayısı ikinci bir seri veya görsel kod
değildir. `accessibilityChartDescriptor` da aynı yedi günlük tekrar veri
noktalarını sunar; zikir çekilmeyen günler `0` değeriyle dahildir. Grafik
yanında doğal dil özeti
bulunur: "Bu hafta 4 gün zikir yapıldı. Toplam 1.240 tekrar. En yoğun gün
çarşamba, 420 tekrar."

"Gün Gün İncele" grafiğin yedi tarih + tekrar noktasının eksiksiz metinsel
eşdeğeridir ve her satırda ayrıca tamamlanan hedef sayısını verir. Bu liste
gören ve VoiceOver kullanan herkes için görünür/erişilebilirdir; hedef bilgisi
yalnız yardımcı teknolojiye özgü değildir.

### 3.4 Zikirler

Seçili dönemdeki zikirler tekrar sayısına göre sıralanır. Her satır ad, tekrar
ve tamamlanan hedef sayısını verir. Satır zikir geçmişi ayrıntısına gider.
Kaldırılmış veya kalıcı silinmiş özel zikirler kayıt anındaki ad snapshot'ıyla
gösterilir.

### 3.5 Dönemleri İncele

Dönem seçimi: Bugün, Hafta, Ay, Tümü.

- Gün: cihazın yerel saatinde gece yarısı sınırı.
- Hafta: pazartesi-pazar.
- Ay: takvim ayı.
- Tümü: ilk geçmiş kaydından bugüne.

Hafta ve Ay görünümünde önceki/sonraki dönem düğmeleri vardır. Gelecekteki
döneme geçiş devre dışıdır. Düğme etiketi hedef dönemi söyler.

Karşılaştırma Bugün için önceki takvim günüyle, Hafta için bir önceki
pazartesi-pazar aralığıyla, Ay için bir önceki takvim ayıyla yapılır. Geçmişte
seçilmiş hafta veya ay da kendisinden hemen önceki eşdeğer dönemle
karşılaştırılır. Tümü görünümünde önceki eşdeğer dönem ve karşılaştırma yoktur.

### 3.6 Veri Yönetimi

Ana içeriğin en altında ayrı bölüm:

- Geçmişi Sil: bütün geçmiş agregalarını siler, güncel sayacı korur.
- Tüm Verilerimi Sil: geçmiş, sayaç durumu, özel zikirler, hazır zikir
  override'ları, hatırlatıcılar, kullanıcı ayarları ve onboarding durumunu
  siler; bekleyen yerel bildirimleri iptal eder. StoreKit satın alma hakkı
  Apple hesabına ait olduğu için silinmez; varsa yalnız yerel entitlement
  önbelleği temizlenir ve sonraki açılışta StoreKit'ten yeniden okunur.

İkisi farklı açıklamalı, geri alınamaz işlem onayı ister.

Geçmiş ve Ayarlar ekranları aynı kanonik tüm-veri-silme servisini çağırır.
Silme tamamlanmadan başarı duyurulmaz. Her alt depo silme sonucu döndürür;
herhangi biri başarısız olursa servis başarısız bileşenleri bildirir, UI
"Bazı veriler silinemedi" hatası gösterir ve uygulama belleğindeki durumu
başarılıymış gibi sıfırlamaz. UserDefaults tabanlı ilk uygulamada işlem öncesi
ilgili anahtarların anlık yedeği alınır; tüm silmeler tamamlanamazsa silinen
anahtarlar bu yedekten geri konur. Böylece kullanıcıya ya tam başarı ya da
eski durum sunulur.

Bekleyen bildirim kimlikleri hazırlık aşamasında kaydedilir. Önce geri
alınabilir yerel veri silmeleri tamamlanır; biri başarısızsa yerel yedek geri
konur ve bildirimlere dokunulmaz. Tümü başarılıysa kalıcı bir "silme
tamamlanıyor" işareti yazılır, ardından bekleyen bildirimler iptal edilir ve
işaret kaldırılır. Uygulama bu iki son adım arasında kapanırsa sonraki açılış
işareti görüp bildirim iptalini tamamlar. Böylece eski veriler geri yüklenmişken
hatırlatıcıların kaybolduğu bir kısmi başarısızlık oluşmaz.

## 4. Zikir Geçmişi Ayrıntısı

Seçilen zikir için:

- Seçili dönem toplamı.
- Tamamlanan hedef sayısı.
- Zikir yapılan gün sayısı.
- Günlük dağılım ve metinsel gün listesi.
- Tüm zamanlar toplamı.
- "Bu Zikrin Geçmişini Sil" eylemi.

Zikir özelinde geçmiş silme yalnız eşleşen `dhikrID` kayıtlarını kaldırır.
Diğer zikirler ve güncel sayaç etkilenmez.

"Sayacı Sıfırla" farklı bir işlemdir. Geçmişi etkilemez ve Geçmiş ekranına
konmaz; Sayaç veya Zikir Detayı akışında yer alır. Bir özel zikri kaldırmak ya
da kalıcı silmek geçmişini otomatik silmez.

## 5. Ölçüler ve Hesaplama Kuralları

Bugün, Hafta ve Ay için:

- Toplam tekrar.
- Tamamlanan hedef sayısı.
- Zikir yapılan gün sayısı.
- Günlük ortalama.
- En çok yapılan zikir.
- En yoğun gün.
- Önceki eşdeğer dönemle sayısal fark.

Tümü görünümünde ilk altı ölçü bulunur; önceki eşdeğer dönem karşılaştırması
bulunmaz.

Günlük ortalama `toplam tekrar / kapsanan takvim günü` olarak hesaplanır ve
ondalık gerekiyorsa yerel sayı biçimiyle en fazla bir basamak gösterilir.
Boş dönemin ortalaması `0`dır. Bugün paydası 1'dir. Devam eden haftada
pazartesiden bugüne, devam eden ayda ayın birinden bugüne kadar geçen günler
paydaya girer; gelecek günler girmez. Tamamlanmış tarihsel hafta/ayda dönemin
bütün günleri paydaya girer. Tümü görünümünde ilk geçmiş kaydı ile bugün
arasındaki iki uç dahil takvim günü sayısı kullanılır; hiç kayıt yoksa 0dır.

Karşılaştırma örnekleri:

- "Geçen haftadan 320 tekrar fazla."
- "Geçen haftadan 80 tekrar az."
- "Geçen haftayla aynı."
- Önceki dönem boşsa: "Geçen hafta kayıt yoktu."

Önceki değer sıfırken yüzde değişim hesaplanmaz. Ana karşılaştırma sayısal
farktır.

En çok yapılan zikir ve zikir listesi önce tekrar sayısı azalan, eşitlikte
yerelleştirilmiş görünen ad artan, hâlâ eşitse `dhikrID` artan sıralanır. En
yoğun gün önce tekrar sayısı azalan, eşitlikte en yeni gün önce sıralanır.

## 6. Veri ve Mimari

`HistoryEntry` günlük agrega modeli korunur ve kanonik alanlar şöyle kilitlenir:
`localDayKey` (`yyyy-MM-dd`, kaydın oluşturulduğu yerel Gregoryen takvim günü),
`dhikrID`, ad snapshot'ı, eklenen net tekrar ve `completedTargetCount: Int`.
Aynı gün-zikir çifti tek kayıtta toplanır; bir günde birden fazla hedef
tamamlanabildiği için boolean kullanılmaz.

Mevcut yalnız `date: Date` taşıyan kayıtlar ilk başarılı yüklemede, o anda
saklı `Date` değerini cihazın yerel saatinde takvim gününe çevirerek
`localDayKey` alanına sahip sürümlü formata taşınır. Migrasyon öncesi ham veri
yedeklenir ve yeni veri doğrulanmadan eski anahtar silinmez. Sonraki saat
dilimi, DST veya sistem takvimi değişiklikleri `localDayKey` değerini yeniden
yorumlamaz; geçmiş, kaydedildiği yerel günün altında kalır. Dönem hesabı
ürün kararı gereği Gregoryen takvim ve pazartesi hafta başlangıcı kullanır.

Sorumluluklar:

- Takvim/dönem birimi: gün, hafta, ay sınırları ve önceki/sonraki dönem.
- Saf istatistik hesaplayıcısı: özet, ortalama, karşılaştırma, en yoğun gün ve
  zikir sıralaması.
- Geçmiş deposu: yükleme, kaydetme, bütün geçmişi silme ve `dhikrID` bazlı
  silme. İşlemler açık başarı/hata sonucu döndürür.
- `HistoryViewModel`: seçili kapsam/dönem, ekran durumları ve kullanıcı
  eylemleri.
- SwiftUI görünümleri: ana geçmiş, dönem ayrıntısı, zikir ayrıntısı ve günlük
  liste/grafik bileşenleri.

Hesaplayıcı SwiftUI veya `Date()` çağrısına doğrudan bağımlı olmaz. Takvim ve
referans tarih dışarıdan verilir; testler deterministik kalır.

### 6.1 Sayaçtan Geçmişe Yazma Sözleşmesi

Sayaç geçmiş deposuna tek bir `HistoryDelta` değeri gönderir:
`localDayKey`, `dhikrID`, `dhikrNameSnapshot`, `repetitionDelta` ve
`completedTargetDelta`. Gün anahtarı işlemin gerçekleştiği anda üretilir.

- Normal/Hızlı Sayma: tekrar `+1`; hedef o dokunuşla tamamlandıysa hedef
  `+1`, aksi halde `0`.
- Geri Al: son artışın tekrarını `-1`; o artış hedef tamamladıysa hedef `-1`,
  aksi halde `0`.
- Manuel Sayıyı Ayarla: yeni geçerli tur sayısı ile eski tur sayısı arasındaki
  fark tekrar deltasıdır; hedef deltası her zaman `0`dır. Manuel ayarlama hedef
  tamamlaması üretmez ve değer hedef varsa `0...(hedef-1)` aralığındadır.
  İşlemden sonra `LastIncrement` temizlenir; eski artış geri alınamaz.
- Sayacı Sıfırla: yalnız devam eden turu sıfırlar; geçmişe delta yazmaz ve
  `LastIncrement`ı temizler.
- Zikir/hedef değiştirme: devam eden turu sıfırlar; geçmişe delta yazmaz ve
  `LastIncrement`ı temizler.

`CounterState.LastIncrement`, hedef tamamlandı bilgisinin yanında artışta
üretilen `HistoryDelta`nın `localDayKey`, `dhikrID` ve ad snapshot'ını kalıcı
tutar. Geri Al gece yarısından sonra yapılsa bile delta bugüne değil son
artışın özgün gün/zikir kaydına uygulanır. İlgili geçmiş kaydı kullanıcı
tarafından bu arada silinmişse negatif kayıt oluşturulmaz; geçmiş düzeltmesi
no-op olur, fakat güncel sayaçtaki geri alma yine tamamlanır.

Sayaç durumu ve geçmiş deltası iki ayrı yazma olarak başıboş bırakılmaz.
`CounterHistoryTransactionCoordinator` şu küçük, kalıcı işlem günlüğünü
kullanır:

1. Benzersiz işlem kimliği, önceki/yeni sayaç durumu ve opsiyonel
   `HistoryDelta` içeren tek `PendingCounterHistoryTransaction` yazılır.
2. Geçmiş deposu deltayı uygular ve `lastAppliedTransactionID` değerini aynı
   kayıtla saklar.
3. Sayaç deposu yeni durumu ve aynı `lastAppliedTransactionID` değerini saklar.
4. İki depo da işlemi uyguladığını doğrulayınca pending işlem silinir; ancak
   bundan sonra UI belleği başarı durumuna geçirilir ve geri bildirim çalınır.

Uygulama açılışta pending işlem bulursa her deponun son işlem kimliğini kontrol
eder ve yalnız eksik tarafı uygular. Aynı işlem kimliği ikinci kez delta
ekleyemez; böylece yeniden deneme idempotenttir. Herhangi bir yazma hatasında
pending işlem korunur, UI hata gösterir ve yeni sayaç işlemi kabul etmeden önce
yeniden deneme/kurtarma tamamlanır. Bu günlük yalnız tamamlanmamış tek işlemi
tutar; kullanıcı oturumlarının veya bütün dokunuşların olay geçmişi değildir.

## 7. Erişilebilirlik

- Özet kartları tek, anlaşılır VoiceOver öğeleridir.
- Dönem seçici seçili durumunu seslendirir.
- Önceki/sonraki düğmeleri gidilecek dönemi etiketinde belirtir.
- Grafik `accessibilityChartDescriptor` ile değerleri gezilebilir sunar.
- Doğal dil özeti grafiğin eğilimini ve önemli değerlerini açıklar.
- Gün Gün İncele listesi bütün grafik verisinin metinsel eşdeğeridir.
- Artış/azalış, boş gün veya seçili durum yalnız renkle belirtilmez.
- Dynamic Type, Bold Text, Increase Contrast ve Reduce Motion desteklenir.
- Boş durumlar başlık + açıklama + uygun eylemle okunur.
- Silme onayından sonra odak ilgili başlığa taşınır ve sonuç duyurulur.
- Voice Control için görünür eylemlerin kısa ve benzersiz adları bulunur.

## 8. Boş, Hatalı ve Sınır Durumları

- Hiç kayıt yok: grafik çizilmez, boş durum gösterilir.
- Seçili dönemde kayıt yok: dönem korunur; boş olduğu açıkça söylenir.
- Önceki dönem boş: yüzde veya sonsuz artış gösterilmez.
- Gelecek dönem: gezinme engellenir.
- Silinmiş zikir: snapshot adı kullanılır.
- Aynı `dhikrID` zaman içinde farklı ad snapshot'ları taşıyorsa liste ve
  ayrıntı başlığı seçili dönemdeki en yeni kaydın adını kullanır; eşit tarihte
  kalıcı kayıt sırası kullanılır. Gün satırları kendi kayıt snapshot'ını
  korur. Navigasyon yalnız `dhikrID` ve bu başlık snapshot'ını taşır; güncel
  zikir modelinin bulunmasını gerektirmez.
- Geri alma/manual düzeltme: günlük net tekrar sıfırın altına düşmez.
- Yeni kayıt gün anahtarı kayıt anındaki yerel saatten üretilir; eski anahtarlar
  saat dilimi veya sistem takvimi değişince kaydırılmaz.
- Depo sürümlü zarfı decode edemezse ham veriyi zaman damgalı karantina
  anahtarına kopyalar, bozuk anahtarın üzerine yazmaz ve `.corruptedData`
  sonucu döndürür. Ekran kayıt yokmuş gibi davranmaz; "Geçmiş verileri
  okunamadı" açıklaması ile "Tekrar Dene" ve onaylı "Bozuk Geçmişi Sil"
  eylemlerini sunar. İlk sürüm kısmi JSON kurtarma yapmaz; yanlış toplam
  göstermemek, sessiz veri kaybından daha güvenlidir.
- Tek geçmiş kaydetme/silme başarısız olursa bellekteki `entries` başarılı
  görünümüne geçirilmez ve başarı anonsu yapılmaz. UI kısa hata metni ve tekrar
  deneme yolu sunar.

## 9. Doğrulama Kapsamı

- Gün/hafta/ay/tümü dönem sınırı birim testleri.
- Pazartesi hafta başlangıcı ve ay/yıl geçişi.
- Devam eden dönem ortalama paydası.
- Önceki dönem karşılaştırmaları ve sıfır veri.
- Zikir bazlı gruplama, snapshot adı ve sıralama.
- Aynı sayıda tekrar/hedef olduğunda deterministik eşitlik sırası.
- Saat dilimi/DST/sistem takvimi değişiminde eski `localDayKey` değerlerinin
  değişmemesi ve eski `Date` kayıtlarının migrasyonu.
- Zikir özelinde silmenin diğer kayıtları ve güncel sayacı koruması.
- Bütün geçmişi silme ile tüm veriyi silme ayrımı.
- Depo decode/yazma/silme hatası ve tüm-veri silmede geri alma.
- VoiceOver odak sırası, grafik özeti ve gün listesi eşdeğerliği.
- En büyük Dynamic Type, koyu/açık tema ve yüksek kontrast manuel kontrolleri.

## 10. Kapsam Dışı

- Oturum süresi ve saatleri.
- Seri/streak ve seri koruma.
- Rozet, puan, seviye, liderlik tablosu veya sosyal karşılaştırma.
- Hedef başarı yüzdesi.
- Dışa aktarma ve paylaşılabilir istatistik kartı.
- iCloud kaynaklı cihazlar arası geçmiş birleştirme; bu özellik CloudKit
  tasarımında ayrıca ele alınır.
- App Store değerlendirme istemi. PLAN.md 7.3'teki düşük öncelikli fikir bu
  geçmiş ekranı revizyonunun parçası değildir; ayrı uygulama yaşam döngüsü
  işi olarak kalır.

## 11. Araştırma Dayanağı

Benzer zikirmatikler günlük/haftalık/aylık takip, grafik ve zikir bazlı
ayrıntıyı sık kullanıyor; bazıları bunu streak, rozet ve liderlikle
birleştiriyor. Tesbihim aynı yararlı dönemsel görünürlüğü korurken rekabet ve
baskı unsurlarını bilinçli olarak dışarıda bırakır.

Apple'ın grafik rehberi, yaygın grafik türlerini, ayrıntının kademeli açılmasını
ve grafiklerde erişilebilir açıklama/etkileşim sağlamayı önerir. SwiftUI
`accessibilityChartDescriptor` ile grafiğin VoiceOver tarafından algılanıp
incelenmesini destekler.

Kaynaklar:

- https://developer.apple.com/design/human-interface-guidelines/charting-data
- https://developer.apple.com/documentation/swiftui/view/accessibilitychartdescriptor(_:)
- https://apps.apple.com/tr/app/zikirmatik-tesbih-zikir/id6743034052
- https://apps.apple.com/us/app/dhikr-matic-dhikr-counter/id6758314965
- https://apps.apple.com/tr/app/zikirmatik-tesbihmatik/id1441547985
