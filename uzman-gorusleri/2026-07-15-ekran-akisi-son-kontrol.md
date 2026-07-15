# Ekran Akışı Son Kontrolü

Genel olarak akışlar sade ve hedef kitle önceliğiyle uyumlu. Kodlamadan önce aşağıdaki maddeleri netleştirmenizi öneririm.

1. Karşılama ekranında sayfalar arası açık bir ilerleme yolu tanımlı değil.
   * Eksik: "1 / 3" yalnızca durum bilgisidir; kullanıcı sayfayı nasıl ilerleteceğini planda göremiyor. Yatay kaydırmaya güvenmek yaşlı kullanıcı, VoiceOver, Switch Control ve klavye için yeterli değil.
   * Neden önemli: Apple, sık yapılan işlerde basit ve tanıdık etkileşimleri; jest kullanılan yerde görünür alternatifleri önerir. "Atla" var ama ikinci ve üçüncü bilgiye ulaşmanın açık yolu yok. [Apple HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
   * Öneri: Her sayfada altta büyük, sabit birincil düğme kullanın: ilk iki sayfada "Devam", son sayfada "Başla". "1 / 3" metni kalsın. Sayfa kaydırma yalnızca ek kolaylık olsun.
2. İlk açılış sonrası varsayılan sayaç durumu belirtilmemiş.
   * Eksik: Kullanıcı "Başla" veya "Atla" dediğinde Sayaç ekranında hangi zikir ve hedefin seçili olduğu tanımlı değil.
   * Neden önemli: İlk ekranda belirsiz/boş sayaç görmek, özellikle yardım almadan başlaması hedeflenen yaşlı kullanıcı için duraksama yaratır. "Seçili zikir adı" Sayaç ekranının ilk odak öğesi olduğundan bu alanın her zaman anlamlı bir değeri olmalı.
   * Öneri: Deterministik bir başlangıç kuralı ekleyin: örneğin varsayılan olarak "Serbest Sayaç, hedefsiz" ya da "Sübhanallah, hedef 33". Tercihim, kullanıcının dinî tercihine varsayım yüklememesi nedeniyle Serbest Sayaç olur. Bu ilk durum VoiceOver'da açıkça okunmalı.
3. Hedef tamamlanınca sayacın devam davranışı ve geçmişe yazım kuralı eksik.
   * Eksik: 33/33'e ulaşıldığında sayının 33'te mi kaldığı, 0'a dönüp yeni tur mu başlattığı, 34'e ilerleyip ilerlemediği; ayrıca tek dokunuşun hedefi aşması halinde geçmişe kaç tekrar/kaç tamamlanmış hedef yazacağı belirtilmiyor.
   * Neden önemli: Bu, Sayaç, Geri Al ve Geçmiş ekranlarının aynı veriyi tutarlı yorumlaması için gerekli. Belirsizlik yanlış geçmiş toplamına ve "Geri Al"ın şaşırtıcı davranmasına yol açar.
   * Öneri: Tek bir açık kural kilitleyin. Örneğin: "Hedefe ulaşınca hedef tamamlandı kaydedilir, sayaç 0'dan yeni tura başlar; her artış tek olduğundan bir işlem en fazla bir hedef tamamlar; Geri Al son artışı ve oluştuysa ilgili tamamlanmış hedef kaydını geri alır." Sayaçta geçiş anı kısa bir "33 tamamlandı; yeni tur 0" duyurusuyla belirtilsin.
4. Sayaçtaki dört alt eylem tek satırda yaşlı kullanıcı için dar kalabilir.
   * Eksik: "Say / Geri Al / Sayıyı Okut / Sıfırla" dört ayrı denetimin hedef ölçüsü, aralığı ve en büyük Dynamic Type boyutundaki yerleşimi belirtilmemiş. Sadece Sıfırla için 60×60 pt koşulu var.
   * Neden önemli: Apple iOS'ta varsayılan 44×44 pt denetim boyutunu ve denetimler arasında yeterli boşluğu öneriyor; Türkçe etiketler dört sütunda hızla sıkışır. [Apple HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
   * Öneri: "Alt sıra" kararını koruyarak bunu en az iki satırlı 2×2 büyük düğme düzeni olarak kabul kriterine bağlayın. Her düğme en az 44×44 pt, tercihen 60 pt dokunma alanına ve yeterli aralığa sahip olsun. `Say` en belirgin düğme olarak kalsın; gerçek cihazda en büyük yazı boyutuyla doğrulansın.
5. Her odak değişiminde zorla `screenChanged` göndermek fazla geniş bir kural.
   * Eksik/yanlış: Plan, her push/modal/alert açılış-kapanışında odağın manuel taşınmasını istiyor. Apple'ın ayrımı daha dar: `screenChanged`, ekranın büyük bölümü değiştiğinde; `layoutChanged`, mevcut ekranda düzen değiştiğinde kullanılmalı. [UIAccessibility bildirimleri](https://developer.apple.com/documentation/uikit/uiaccessibility/notification), [ScreenChanged](https://developer.apple.com/documentation/accessibility/accessibilitynotification/screenchanged)
   * Neden önemli: Sistem zaten doğru odağı yönettiğinde ek bildirim göndermek VoiceOver odağını beklenmedik biçimde sıçratabilir veya konuşmayı kesebilir. Özellikle Alert kapandıktan sonra doğrudan ekran başlığına dönmek, kullanıcının kaldığı bağlamı kaybettirir.
   * Öneri: Kuralı şöyle daraltın: sistemin varsayılan odağı yanlışsa manuel taşı; yeni tam ekran/push için `screenChanged`, disclosure açma veya silme sonrası değişen içerik için `layoutChanged`, karşılama sayfası geçişi için `pageScrolled` kullan. Alert kapanınca mümkünse eylemi başlatan düğmeye dön; tüm veriler silindiyse ekran başlığına dönmek uygundur.
6. Değerlendirme istemi hedef tamamlayan dokunuşu kesebilir.
   * Eksik/yanlış: Hedef tamamlama, doğrudan "Say" eyleminin sonucu. Apple, kullanıcıyı kesintiye uğratmamak ve değerlendirme istemini bir kullanıcı eyleminin sonucu olarak göstermemek gerektiğini söylüyor. Sistem isteminin görünmesi de garanti değildir. [WWDC22 — requestReview](https://developer.apple.com/videos/play/wwdc2022/10007/?time=2335)
   * Neden önemli: Zikir akışında sistem değerlendirme penceresi sakin deneyimi böler; VoiceOver kullanıcısı beklenmedik modal ile karşılaşır.
   * Öneri: Faz 1'de otomatik değerlendirme istemini kaldırın veya yalnızca daha sonraki bir uygulama açılışında, sayaç etkileşimi başlamadan önce ve seyrek bir uygunluk kuralıyla değerlendirin. Bu davranış, hedef tamamlanmasının kendisine bağlanmamalı. SwiftUI uygulamasında güncel `requestReview` ortam eylemini kullanın.
7. Dynamic Type yönlendirmesi "daha büyük erişilebilir boyutlar" için eksik kalıyor.
   * Eksik: Ayarlar'daki metin yalnızca "Ekran ve Parlaklık → Metin Boyutu" yolunu veriyor. Bu, erişilebilirlikteki daha büyük metin boyutlarını kapsamaz.
   * Neden önemli: Hedef kitlede yalnızca standart metin boyutu değil, Accessibility Sizes kullanan kişiler beklenmeli. Apple büyük metni desteklemeyi özellikle ister. [Apple HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
   * Öneri: Metni "iPhone Ayarları → Erişilebilirlik → Ekran ve Metin Boyutu → Daha Büyük Metin" şeklinde düzeltin; ekranın en büyük erişilebilir boyutta test edildiğini de uygulama içi yardımda kısa biçimde belirtin.
