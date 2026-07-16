# Zikirmatik Geri Bildirim Tasarımı

## Amaç

Zikirmatikteki tesbih sesi, Ayarlar'dan ayrı olarak açılıp kapatılabilmeli ve kullanıcı parmağını kaldırdığında ses ya da titreşim sonradan devam etmemelidir.

## Bulgu

Mevcut uygulamada ses efekti `spokenCountEnabled` kapalı olduğunda otomatik çalıyor; ayrı bir ayarı yok. `AudioServicesPlaySystemSound` çağrıları iptal edilemeyen sistem oynatma akışına gittiği için sık erişilebilirlik rotor hareketlerinde gecikmiş geri bildirim hissi oluşturabiliyor. Mevcut 60 ms ses sınırı ses çağrılarını azaltır, fakat önceden kabul edilen bir sesi iptal edemez.

## Seçilen Tasarım

- `UserSettings` içine varsayılanı `true` olan `soundEffectEnabled` eklenir. Özel `Decodable` uygulaması, eski kayıtlardaki eksik alanı `true` kabul ederken mevcut diğer tercihleri korur.
- Ayarlar'da anlaşılır bir `Ses Efekti` anahtarı bulunur. Bu anahtar sayının VoiceOver ile okunmasından bağımsızdır.
- Sistem geri bildirim sağlayıcısı, ses dosyasını tek bir `AVAudioPlayer` ile önceden hazırlar. Yeni bir vuruş geldiğinde önce devam eden ses kesilir, oynatma başa alınır ve yeniden başlatılır; ses kuyruğu oluşmaz.
- Titreşim, her geçerli sayımda mevcut hazırlıklı üreticiyle anlık kalır; ses sınırı titreşime uygulanmaz. Böylece titreşim parmak hareketiyle bire bir eşleşir. Kuyruk önleme yalnızca ses oynatıcısının durdurulup başa sarılmasıyla sağlanır.
- Sayı artışı ve geri alma, ses efekti açıkken ses üretir; `Sayıyı Sesli Söyle` yalnızca VoiceOver değerinin okunup okunmayacağını belirler.

## Hata ve Erişilebilirlik

Ses dosyası yüklenemezse sayaç çalışmaya devam eder; yalnızca ses efekti sessiz kalır. VoiceOver sesli değer ayarı önceki davranışını korur. Hızlı sayımda bazı vuruşların geri bildirimsiz kalması, gecikmiş/kuyruğa alınmış geri bildirimden bilinçli olarak tercih edilir.

## Doğrulama

ViewModel birim testleri, ses anahtarının açık/kapalı durumunu, konuşma ayarından bağımsızlığını, ayarın kalıcılığını ve eski ayar JSON'undan güvenli geçişi doğrular. iOS hedefi derlenir ve tüm test paketi çalıştırılır. Gerçek cihazda rotorla seri artırma ve geri alma, ardından parmağı kaldırma; ayarı kapatıp uygulamayı yeniden açma kontrolleri yapılır.
