# Hızlı Sayım — Ekran Geneli Tek Dokunuş Tasarımı

Tarih: 2026-07-15  
Durum: Kullanıcı tasarımı onayladı; gerçek cihazdaki çıkış-jesti prototip
doğrulamasını bekliyor. Bu doğrulama geçmeden uygulama planına hazır değildir.

## Amaç

VoiceOver kullanan kişi Hızlı Sayım modundayken, ekran üzerinde bir hedef
aramadan tek parmakla yaptığı her tek dokunuşta sayımı bir artırabilmelidir.
Modun açılması ve kapanması ekran konumundan bağımsız olmalı; geçiş jestleri
asla fazladan sayım üretmemelidir.

## Kapsam

- Yalnızca `SayacView` içindeki Hızlı Sayım davranışı.
- Ayarlar'daki mevcut Hızlı Sayım ana anahtarı ve Hızlı Sayım geri bildirim
  tercihleri korunur.
- Normal sayaç ekranındaki standart VoiceOver çift dokunma davranışı değişmez.

## Kullanıcı Akışı

1. Kullanıcı Ayarlar'dan Hızlı Sayım'ı etkinleştirir.
2. Sayaç ekranının herhangi bir yerindeyken iki parmakla çift dokunur
   (VoiceOver Sihirli Dokunuş). Bu, modu açar.
3. Hızlı moddayken ekranın herhangi bir noktasında yapılan her tek parmak,
   tek dokunuş sayımı tam olarak bir artırır.
4. Kullanıcı yine ekranın herhangi bir yerinde iki parmakla çift dokunur.
   Bu, modu kapatır ve normal VoiceOver davranışını hemen geri getirir.

Hızlı modda öğe keşfi bilinçli olarak devre dışıdır: kullanıcının bu moda
geçme amacı, doğrudan ve ritmik sayımdır. İki parmak çift dokunuş her zaman
çıkış yoludur.

## Tasarım Kararları

### Tek giriş ve tek çıkış jesti

`SayacView` kökünde mevcut `.magicTap` erişilebilirlik eylemi korunur.
Hızlı Sayım yalnızca ayar açıkken bu eylemle açılır; kapatma ise ayar sonradan
kapatılsa bile her zaman çalışır. Görünür `Kapat` düğmesi kaldırılır: ekranda
işlevsiz bir alan veya aranacak bir hedef kalmaz.

### Doğrudan dokunma yüzeyi

Hızlı mod aktif olduğunda tam ekran bir UIKit köprüsü kullanılır. Köprü,
`UIAccessibilityTraits.allowsDirectInteraction` ile VoiceOver'ın tek parmak
keşif jestini uygulamaya yönlendirir. Yüzeyin sorumluluğu yalnızca şudur:

- Tek parmakla başlayan her ayrı dokunuş için `CounterViewModel.incrementFast()`
  çağırmak.
- Birden çok parmakla başlayan dokunuşu saymamak.
- Herhangi bir görsel kontrol, erişilebilirlik odağı veya ikinci çıkış yolu
  tanımlamamak.

`CounterViewModel` sayım, kalıcılık, hedef tamamlanması ve seçili Hızlı Sayım
geri bildirimlerini mevcut tek noktadan yönetmeye devam eder.

### Ölçülebilir dokunma sözleşmesi

Bir sayım yalnızca şu koşulların tümü sağlanırsa üretilir: temas yüzeyde
başladığında tek parmak vardır, o temasa ikinci parmak eklenmemiştir, parmak
aynı temas dizisi içinde kalkmıştır ve temas iOS tarafından iptal edilmemiştir.
Sayaç `touchesBegan` anında değil, bu başarılı tamamlanma anında artar.
Birden çok parmakla başlayan, sonradan ikinci parmak eklenen, hareketle iptal
edilen veya `touchesCancelled` alan temaslar sıfır artış üretir.

Sayım/geri bildirim kuyruğu oluşturulmaz. Yüzey yalnızca hâlen etkin olan
temas dizisini işleyebilir; mod kapatıldığında veya yüzey kaldırıldığında tüm
takip edilen temas durumu sıfırlanır. `incrementFast()` içindeki mevcut
de-bounce edilmiş duyuru da iptal edilebilir kalır; kullanıcı parmağını
kaldırdıktan sonra yeni sayım ya da eski bir temasın geri bildirimi çalışmaz.

### Geçişte fazladan sayımı engelleme

Doğrudan dokunma yüzeyi mod açma eylemi tamamlandıktan sonra eklenir; açılışı
tetikleyen iki parmaklı jest hiçbir zaman yüzeye iletilmez. Mod kapatma
eyleminde yüzey önce kaldırılır, normal erişilebilirlik davranışı sonra geri
verilir. Bu iki durum değişimi ana aktörde, tek bir `fastCountingEnabled`
kaynağından yönetilir; kaldırılmış yüzey hiçbir kapanış sonrası teması işleyemez.
Yüzey çoklu parmaklı başlangıçları ayrıca yok sayar. Böylece açma ve kapatma
jestleri +1 üretemez.

İki parmak çift dokunuşun `allowsDirectInteraction` etkinken de kök
`.magicTap` eylemine ulaştığı, **uygulama kodundan önce**, VoiceOver açık gerçek
cihaz prototipinde doğrulanmalıdır. Bu çalışmazsa tasarım uygulanmaz: kullanıcıyı
hedef aramaya zorlamayan, ekran genelinde çalışan eşdeğer bir çıkış jesti için
ayrı bir tasarım kararı alınır. Çalıştığı kanıtlanmadan görünür düğme ya da
konuma bağlı alternatif varsayılmaz.

## Bileşen Sınırları

| Bileşen | Sorumluluk | Bağımlılık |
|---|---|---|
| `SayacView` | Mod durumu, Sihirli Dokunuşla aç/kapa, Hızlı Sayım yüzeyini koşullu gösterme | `CounterViewModel`, SwiftUI erişilebilirlik eylemi |
| Yeni doğrudan dokunma yüzeyi | Tam ekran tek parmak dokunuşunu güvenli biçimde iletme | UIKit, tek `onCount` kapanışı |
| `CounterViewModel.incrementFast()` | Sayımı kalıcılaştırma ve hızlı moda özel geri bildirim | Mevcut repository/feedback/announcer |

## Hata ve Kenar Durumları

- Hızlı Sayım ayarı kapalıyken Sihirli Dokunuş hiçbir durum değişikliği yapmaz.
- Mod açıkken ayar kapansa bile Sihirli Dokunuş çıkış olarak çalışır.
- Sayaç ekranından ayrılma, zikir seçimine gitme, uygulamanın arka plana
  alınması veya erişilebilirlik açısından modal bir arayüzün görünmesi modu
  kapatır ve yüzeyi kaldırır. Uygulamaya dönüşte normal sayaç ekranı açılır.
- İki ya da daha fazla parmakla başlayan bir dokunuş sayılmaz; sistemin
  Sihirli Dokunuş jesti korunur.
- Hedef tamamlandığında mevcut `incrementFast()` davranışı (tur sıfırlama ve
  duyuru) aynen devam eder.

## Doğrulama

Otomatik testler:

- Hızlı Sayım ayarı varsayılanları ve `incrementFast()` geri bildirim ayrımı
  korunur.
- Doğrudan dokunma yüzeyinin tek parmak girişini ilettiği, çoklu parmak
  girişini iletmediği; ikinci parmak eklenen ve iptal edilen temasları saymadığı
  UIKit birim testiyle doğrulanır.
- Yüzey kaldırıldıktan sonra önceki temasın artık sayım veya geri bildirim
  üretemediği test edilir.
- Mevcut sayaç ve proje yapılandırma testlerinin tamamı çalışır.

Gerçek cihazda VoiceOver ile kabul testi:

1. Ekranın farklı köşelerinde iki parmak çift dokunma ile mod açılır.
2. Mod açılırken sayı değişmez.
3. Ekranın farklı köşelerinde tek parmak tek dokunma tam birer artış yapar.
4. Mod açıkken, ekranın farklı köşelerinde iki parmak çift dokunma kök
   Sihirli Dokunuş eylemini gerçekten tetikler ve modu kapatır; kapanırken sayı
   değişmez.
5. Kapatıldıktan sonra tek dokunma tekrar yalnızca VoiceOver keşfi yapar.
6. Hızlı art arda dokunmalar bırakıldıktan sonra sayı, ses veya titreşim geriden
   devam etmez.

## Kapsam Dışı

- Normal sayma yüzeyinin çift dokunma davranışını değiştirmek.
- Yeni ayar, ses veya titreşim tercihi eklemek.
- Kaydırma ile saymayı geri getirmek.
