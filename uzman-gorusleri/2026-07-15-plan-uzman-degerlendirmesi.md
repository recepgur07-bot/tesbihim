# Uzman Değerlendirmesi: Tesbihim Proje Planı İncelemesi

Aşağıdaki değerlendirme, deneyimli bir iOS/Swift geliştiricisi, VoiceOver erişilebilirlik mühendisi ve ürün tasarımcısı şapkaları takılarak `PLAN.md` dosyasının analizi sonucunda hazırlanmıştır.

## 1. Mimari ve Teknik Yığın
*   **SwiftData vs. Codable (Persistans):** Plan'da SwiftData veya Codable arasında kalınmış. Yaşlı kullanıcıların eski cihaz/iOS sürümleri kullanma eğilimi yüksektir. iOS 18 veya iOS 17 zorunluluğu getirecek olan SwiftData yerine, Faz 1 için **geriye dönük uyumlu basit `Codable` + FileSystem/UserDefaults** kullanılması çok daha risksiz ve doğru bir karardır.
*   **MVVM ve Observation Framework:** Eğer iOS 17 ve üzeri hedeflenirse, `ObservableObject` yerine kesinlikle `@Observable` makrosu kullanılmalıdır. Bellek yönetimi ve View render performansını ciddi şekilde iyileştirir.
*   **XcodeGen ve State Yönetimi:** `project.yml` kullanımı CI/CD için mükemmel. Ancak "Undo (Geri Al)" sisteminin uygulama kapandığında da saklanması talebi (Session modeli) MVP için **gereksiz bir over-engineering (aşırı mühendislik)** riskidir. Uygulama kapandığında undo geçmişinin silinmesi, mimariyi oldukça basitleştirir; ilk versiyonda sadece in-memory undo tutulmasını öneririm.

## 2. Erişilebilirlik Yaklaşımı (Hızlı Sayım / DirectTouch)
*   **Teknik Yaklaşım (`.requiresActivation` & `accessibilityDirectTouch`):** Mükemmel bir kurgu. DirectTouch'ın VoiceOver deneyiminde yanlış sayımlara yol açmasını `.requiresActivation` ile çözmek tam olarak best-practice'dir.
*   **App Store İnceleme Riski:** Apple inceleme ekibi (App Review) bu tarz spesifik erişilebilirlik kullanımlarını ilk bakışta anlayamayabilir veya "standart dışı" bularak reddedebilir. **Öneri:** App Store incelemesine gönderirken "App Review Information" kısmına, VoiceOver açıkken bu modun nasıl hayat kurtardığını anlatan 30-40 saniyelik bir video bağlantısı eklenmelidir.
*   **Konuşma Kuyruğu (Speech Queue):** "Her 10 sayımda bir sesli duyuru" kararı harika. Ancak haptic feedback'in (titreşim) yaşlı kullanıcılar için "Heavy" veya "Rigid" olarak ayarlanabilmesi gerekir, zira yaşa bağlı parmak hassasiyeti azalması hafif titreşimleri hissetmelerini zorlaştırır.

## 3. Özellik Kapsamı ve Faz Bölünmesi
*   **MVP Kapsamı Biraz Fazla Yüklü:** Faz 1 için "Özel Zikir Ekle-Düzenle" modülü listelenmiş. Özel veri girişi (klavye kullanımı, validasyonlar, klavyenin VoiceOver ile yönetimi) her zaman karmaşıklık yaratır. Eğer gerçekten bir "Minimum Uygulanabilir Ürün" hedefleniyorsa, Faz 1 sadece "Serbest Sayaç" ve "Hazır Kütüphane" ile çıkmalı; özel zikir ekleme Faz 1.5 veya Faz 2'ye kaydırılmalıdır.
*   **Duraklat Butonu İptali:** "Duraklat" eyleminin MVP'den çıkarılması kararına kesinlikle katılıyorum; zikir zaten pasif bir süreçtir, basmadıkça ilerlemez.

## 4. Monetizasyon Planı
*   **Model Seçimi:** Abonelik yerine "Tek seferlik Destekçi Paketi" + "Tüketilebilir (Consumable) Gönüllü Destek" modeli hedef kitle (yaşlılar ve manevi bir araç arayanlar) için en dürüst ve güven verici yaklaşımdır.
*   **Güven ve İletişim:** Yaşlı veya görme engelli kullanıcıların IAP (Uygulama İçi Satın Alma) ekranında yanlışlıkla para harcamasından çok korktukları bilinir. Bu yüzden IAP ekranındaki düğmelerin `accessibilityLabel`'larına "Bu bir bağış niteliğinde destektir, uygulamayı değiştirmeyecek" minvalinde çok net açıklamalar eklenmelidir.

## 5. Yaşlı ve VoiceOver Kullanıcısı İçin Kullanılabilirlik
*   **Sıfırlama Kilidi (Basılı Tutma Sorunu):** Planda "basılı tutma tek koruma olmayacak, onay diyaloğu çıkacak" denmiş, bu güzel. Ancak yaşlılarda motor beceri zayıflığı veya el titremesi (tremor) "Long Press" (Basılı Tutma) eylemini imkansız kılabilir. Sıfırlama işlemi için uzun basma yerine, yeterince büyük (min 60x60pt) ve ekranın ulaşılması biraz daha zor bir köşesinde konumlanmış standart bir "Sıfırla" butonu ve ardından gelen erişilebilir bir onay (Alert) çok daha kapsayıcıdır.
*   **Dynamic Type Taşmaları:** Sayı göstergesinin fontu Dynamic Type ile çok büyütüldüğünde, 10.000, 100.000 gibi sayılarda ekrana sığmama riski yüksektir. Planda bahsedilmiş ama tasarım kısmında `minimumScaleFactor` veya `ViewThatFits` kullanarak gerekirse alt alta dizilim gibi fallback mekanizmaları düşünülmelidir.

## 6. Gözden Kaçmış / Eksik Noktalar
*   **Ekranın Uyku Moduna Geçmesi (Wake Lock / Idle Timer):** Zikir çeken kullanıcı uzun süre ekrana bakabilir ama dokunmayabilir (örneğin fiziksel tesbih kullanıp ekrandan metni okuyor olabilir) veya dokunma aralıkları uzun olabilir. Ekranın kararması (Auto-Lock) büyük bir UX problemi yaratır. Sayma ekranındayken `UIApplication.shared.isIdleTimerDisabled = true` yapılmalı ve bu durum Ayarlar'da opsiyonel ("Ekran Uyanık Kalsın") olarak sunulmalıdır.
*   **VoiceOver ile "Mevcut Durumu Oku":** DirectTouch yüzeyindeyken VoiceOver kullanıcısı ekrana her dokunduğunda sayı artacaktır. Peki anlık sayıyı duymak istediğinde ne yapacak? Ekranın üst kısmına, sayma alanının dışında kalan net bir "Mevcut durumu dinle" (Sayıyı Okut) butonu eklenmelidir. Aksi takdirde durumu öğrenmek için mecburen sayıyı bir kez daha artırmak zorunda kalabilirler.
