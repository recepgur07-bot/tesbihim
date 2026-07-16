Taslağın ana yönü doğru: Direct Touch/Hızlı Sayım modunu kaldırıp, saymayı standart VoiceOver eylemleriyle erişilebilir kılmak daha güvenilir ve daha az öğretim gerektiren çözüm. Ancak birkaç teknik düzeltme öneriyorum.

## Kararların değerlendirmesi

1. **Direct Touch / Hızlı Sayım kaldırılması — onay.**
   Apple, Direct Touch'ı standart VoiceOver etkileşimlerinin yetmediği özel jest yüzeyleri için konumluyor; `.requiresActivation` da alanın çift dokunuşla ayrıca etkinleştirilmesini gerektirir. Apple'ın güncel örneği, herkesin bu jestleri kullanamayacağını ve mümkün olduğunda alternatif erişilebilir eylemler sunulması gerektiğini özellikle söylüyor. Sayaç için kaydırma ve normal etkinleştirme zaten yeterli; mod eklemek gereksiz karmaşıklık. Gerçek cihazda güvenilmez bulunmuş olması da kararı güçlendiriyor. [Apple: `accessibilityDirectTouch`](https://developer.apple.com/documentation/swiftui/view/accessibilitydirecttouch%28_%3Aoptions%3A%29), [WWDC26: custom controls](https://developer.apple.com/videos/play/wwdc2026/220/)

   Taslaktaki "`onTapGesture` + adjustable + Direct Touch birlikte olduğu için kesin kararsızlık" cümlesini kesin neden gibi yazmayın. Bu makul bir şüphe ama Apple'ın belgelerinden kanıtlanmış bir teşhis değil. "Gerçek cihaz testinde güvenilir olmadığı için kaldırıldı" demek yeterli ve daha doğru.

2. **Üç sabit yöntem — kısmen onay, Magic Tap'i çıkarma önerisi.**
   - VoiceOver açıkken yukarı/aşağı kaydırma ile artırma/geri alma: doğru ana yöntem.
   - VoiceOver açıkken çift dokunma ile `+1`: doğru; fakat ham `.onTapGesture`'a güvenmek yerine erişilebilir varsayılan eylemi açıkça tanımlayın veya yüzeyi gerçek bir `Button` yapın. En sağlam model: büyük sayma yüzeyi görsel olarak özel tasarımlı olsa bile anlamsal olarak bir `Button` olsun; ardından `accessibilityAdjustableAction` eklensin.
   - Magic Tap: gerekli değil. Apple bunu uygulamanın "en önemli/salient" eylemi için tanımlar; telefon görüşmesini cevaplama, müziği oynat/durdurma veya kronometreyi başlat/durdurma gibi. Sayaçta `Say` düğmesi, büyük sayma yüzeyi ve ayarlanabilir kaydırma zaten aynı işi güvenilir biçimde yapıyor. [Apple: Magic Tap](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/accessibilityperformmagictap%28%29)

   Somut öneri: İlk sürümde Magic Tap eklemeyin. Bu, üç değil iki standart ve açık yol bırakır:
   - Büyük sayma yüzeyini etkinleştir → `+1`
   - Sayma yüzeyindeyken yukarı/aşağı kaydır → `+1` / geri al
   - Alt sıradaki `Say` düğmesi → `+1`

   Bu, yaşlı kullanıcı için daha kolay; VoiceOver kullanıcısı için de tamamen standarttır.

3. **"Sayıyı Okut" kaldırılması — onay.**
   Düğme çalışmıyorsa tutulmamalı. Daha önemlisi, sayaç elemanının erişilebilir değeri düzgün tanımlanınca ayrı bir "oku" düğmesine ihtiyaç kalmaz. Bu düğme ayrıca odak sırasını ve alt aksiyon alanını gereksiz büyütür.

4. **`accessibilityValue` kısa tutulması — onay; hedef bilgisinin `accessibilityHint`'e taşınmasına itiraz.**
   Her değişimde sadece sayının okunması doğru: `5`, `6`, `7`. Apple'ın adjustable örneği de değer değiştikçe yeni değerin okunması modelini kullanır. [WWDC26 örneği](https://developer.apple.com/videos/play/wwdc2026/220/)

   Ancak hedef, bir eylemin sonucu hakkında ipucu değil; sayaç durumunun parçasıdır. Ayrıca kullanıcı VoiceOver ipuçlarını kapatmış olabilir. Bu yüzden öneri:
   - `accessibilityLabel`: "Sayım, hedef 111" — Serbest sayaçta: "Sayım, hedefsiz"
   - `accessibilityValue`: "5"
   - `accessibilityHint`: boş bırakın; sistem zaten "ayarlanabilir" ve kaydırma yönergesini verir.

   Böylece kullanıcı elemanın üzerine geldiğinde bağlamı bir kez duyar: "Sayım, hedef 111, 5, ayarlanabilir." Ardışık kaydırmada ise yalnızca değişen kısa değer okunur.

5. **`.isAdjustable` trait'i — taslaktaki "otomatik ekleniyor olabilir" varsayımını kaldırın.**
   SwiftUI API belgesi `accessibilityAdjustableAction`'ın trait'i otomatik eklediğini vaat etmiyor. Apple'ın güncel WWDC örneği özel kontrol için önce `.adjustable` trait'ini, sonra adjustable action'ı ekliyor. Bu nedenle açıkça eklemek en güvenli yaklaşımdır:
   ```swift
   .accessibilityAddTraits(.isAdjustable)
   .accessibilityAdjustableAction { direction in ... }
   ```
   Çift eklenme pratikte zararsızdır; eksik trait ise VoiceOver'ın elemanı ayarlanabilir diye sunmamasına yol açabilir.

6. **Kaydırırken titreşim — sınırlı onay.**
   Varsayılanın açık olması, özellikle hızlı ardışık sayımda ses gecikse bile somut geri bildirim vermesi açısından makul. Fakat bunu yalnızca sayım gerçekten değiştiğinde üretin; sınırda geri alma yapılamıyorsa titreşim vermeyin. Ayar adı "Kaydırırken Titreşim" yerine "Sayım geri bildirimi" daha geniş/geleceğe dönük olurdu, ama ürün sadeliği açısından mevcut ad da yeterli.

7. **VoiceOver'ın kendi sesini/tıkını uygulamadan kapatma — onay.**
   Uygulama VoiceOver'ın sistem ses tercihini yönetemez. Çalışmayan veya etkisi belirsiz bir "sessiz okuma" anahtarı eklememek doğru.

8. **Her artışta `UIAccessibility.post(.announcement, ...)` — yapmayın.**
   Adjustable elemanın erişilebilir değeri güncellendiğinde VoiceOver zaten yeni değeri verir. Her artışta ayrıca `.announcement` göndermek, çift seslendirme ve konuşmaların birbirini kesmesi riskini doğurur. Apple, announcement'ı normal UI değer güncellemesi için değil, kısa süreli veya ekranda kalıcı olmayan önemli olaylar için önerir. [Apple: announcement](https://developer.apple.com/documentation/uikit/uiaccessibility/notification/announcement)

   İstisna: hedef tamamlandığında tek, kısa bir anons uygun olur: "111 tamamlandı." Bunu yalnızca tamamlanma anında gönderin; normal her sayıda göndermeyin.

## Açık noktalar için önerim

| Açık nokta | Öneri | Gerekçe |
|---|---|---|
| Magic Tap yalnızca Sayaç mı, uygulama geneli mi? | **Hiç eklemeyin.** | Zaten üç erişim yolu var; Magic Tap ek faydadan çok yanlışlıkla artış ve test yükü getirir. |
| Yine de eklenecekse | Yalnızca **sayma yüzeyi VoiceOver odağındayken** çalışsın. Uygulama geneline veya Sayaç ekranının köküne bağlamayın. | Apple, Magic Tap'i en niyet edilen eylem için tanımlar; Ayarlar/Geçmiş'te sayacı sessizce artırmak bağlamsal olarak yanlış olur. UIKit responder chain yaklaşımı da odağa yakın eylemi önce arar. [Apple'ın erişilebilirlik kılavuzu](https://developer.apple.com/library/archive/featuredarticles/ViewControllerPGforiPhoneOS/SupportingAccessibility.html) |
| Titreşim varsayılanı | **Açık.** | Yaşlı ve VoiceOver kullanıcıları için hızlı sayımda güven veren ek geri bildirimdir. |
| Kısa format | `Label: "Sayım, hedef 111"`, `Value: "5"`. | Hedefi hint'e bağımlı yapmaz; kaydırmada sadece değer kısa kalır. |
| Başka kolaylık | **Ek özellik yok.** | Yeni mod, ses anahtarı, özel jest veya eğitim katmanı eklemeyin. Sadelik burada erişilebilirliktir. |

## Kodlama talimatına eklenmesi gereken iki düzeltme

- Büyük sayma yüzeyinin varsayılan eylemini açıkça erişilebilir yapın. Salt `.onTapGesture` yerine gerçek `Button` semantiği veya `.accessibilityAction(.default)` kullanın.
- `accessibilityHint`i hedef bilgisinin taşıyıcısı yapmayın; hedefi label'a koyun, value'yu yalnızca güncel sayı yapın.

Sonuç: En sağlam ilk sürüm, **Direct Touch yok; Magic Tap yok; büyük `Say` yüzeyi + VoiceOver adjustable kaydırma + görünür Say/Geri Al/Sıfırla düğmeleri** yaklaşımıdır. Bu, hedef önceliğiniz olan yaşlı kullanıcılar için en kolay; VoiceOver için de Apple'ın yerleşik etkileşim modeline en yakın çözümdür.
