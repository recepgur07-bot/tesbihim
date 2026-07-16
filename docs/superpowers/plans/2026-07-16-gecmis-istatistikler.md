# Geçmiş / İstatistikler Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Onaylı Geçmiş/İstatistikler deneyimini, sayaç ve günlük geçmiş verisini kaybetmeden atomik saklayan, erişilebilir ve test edilmiş bir iOS özelliği olarak tamamlamak.

**Architecture:** `CounterState` ile günlük `HistoryEntry` agregaları, sürümlü `CounterHistorySnapshot` içinde tek dosyada saklanır. `CounterHistoryRepository` bir actor’dür; tüm mutasyonları en yeni snapshot üzerinde seri uygular, atomik yazıp tekrar decode ederek doğrular ve yalnız başarıdan sonra `@MainActor` ViewModel’e yeni görünümü döndürür. Saf dönem/istatistik hesaplayıcısı UI’dan bağımsız kalır; SwiftUI görünümleri onun hazır sunum modellerini kullanır.

**Tech Stack:** Swift 6, SwiftUI, Observation, Swift Charts, Foundation `Calendar`/`FormatStyle`, XCTest/Swift Testing, XcodeGen.

---

## Kararlaştırılmış teknik sözleşmeler

- **Actor / UI sınırı:** `CounterHistoryRepository` actor’ü disk I/O, yükleme, migrasyon, doğrulama ve mutasyonların tek sahibidir. `CounterViewModel` ve `HistoryViewModel` `@MainActor` kalır; actor’dan dönen doğrulanmış `CounterHistorySnapshot` ile state’i günceller. Sayım için iyimser UI güncellemesi yapılmaz: count, haptic/ses ve hedef anonsu yalnız `await repository.apply(...)` başarılıysa yapılır. Bu, kullanıcıya kaydedilmemiş bir sayım göstermez. Hızlı sayımda actor sırayı korur; UI çağrıları sırayla asenkron başlatılır, her çağrı kendi mutasyon sonucunu uygular. Geri bildirim sağlayıcısı kuyruk oluşturmaz; mevcut proje davranışı korunur.
- **Kurtarma:** Ana dosya önce decode + sürüm + invariant doğrulamasından geçer. Başarısızsa ana ham veri zaman damgalı karantinaya taşınır, doğrulanmış `snapshot.backup` okunur; yedek geçerliyse bu veri bellekte yüklenir ve kullanıcıya “Son güvenli kayıt yüklendi” durumu sunulur. Ana ve yedek geçersizse eski UserDefaults kaynakları yalnız yeni snapshot hiç oluşmamışsa migrasyon için denenir. Geçerli kaynak yoksa sessiz sıfırlama yoktur: `unrecoverableData` hata durumu, “Tekrar Dene” ve yalnız geçmişi silmeye izin veren açık kurtarma akışı gösterilir; kritik sayaç için yeni sayı yazmadan önce kullanıcıya durum bildirilir. Yeni ana dosya encode edilip geçici dosyaya atomik taşınır, yeniden decode/doğrulanır, **ondan sonra** eski doğrulanmış ana kopya yedeğe döndürülür; böylece bozuk yeni yazım sağlam yedeği ezmez.
- **Migrasyon:** Yeni geçerli snapshot her zaman kanoniktir. Yoksa eski `tesbihim.counterState` ve `tesbihim.historyEntries` verileri önce ayrı backup anahtarlarına kopyalanır, tarihli kayıtlar sabit Gregorian yerel gün anahtarına dönüştürülür, snapshot yazılıp doğrulanır; ancak sonra eski anahtarlar silinir. Aşamaların her biri kalıcı “migrasyon tamamlandı” yerine snapshot varlığı/doğrulaması ile idempotent olur; testler backup, yazma, doğrulama ve eski anahtar silme noktalarındaki kapanmayı yeniden başlatır.
- **Silme:** Geçmiş silme sadece `entries`i; zikir silme yalnız eşleşen `dhikrID`yi; tüm veri silme ise snapshot, eski UserDefaults artıkları, zikir/ayar/onboarding yerel verisini geri alınabilir işlem yedeğiyle etkiler. Bildirimler yerel commit sonrası iptal edilir. StoreKit entitlement silinmez.
- **Tek composition root ve revizyon:** `TesbihimApp`/`RootTabView`, bir `CounterHistoryRepository` ve bir `CounterHistoryStore` (`@MainActor`, yükleme durumu + son snapshot + son `mutationRevision`) üretip hem `CounterViewModel`e hem `HistoryViewModel`e enjekte eder. Actor her kalıcı mutasyonda snapshot şema sürümünden ayrı, artan `mutationRevision` değerini kaydeder ve döndürür. Store yalnız sonucu kendi son revizyonundan büyük/eşitse uygular; kontrollü gecikmeli test, önce başlayan ama daha geç dönen sonucun UI’ı geri sarmadığını kanıtlar. `SayacView`, rotalar, Kütüphane ve editör çağrı noktaları yeni async komutları `Task` ile çağırır; command sonucu olmadan feedback üretmez.
- **Kurtarmanın postcondition’ı:** Sağlam yedekten yüklemede ana dosya, yedek korunarak atomik onarılmaya çalışılır; onarım başarısızsa uygulama yedekten çalışır ve bir sonraki açılışta yeniden dener. İki dosya geçersizse sayım engellenir, ham veriler karantinada korunur; görünür hata “Geçmiş verileri okunamadı”, “Tekrar Dene” ve onaylı “Bozuk Veriyi Sil” eylemlerini sunar. Sonuncu yeni bir boş snapshotı ancak kullanıcı onayından sonra oluşturur; öncesinde hiçbir sayı, başarı ya da boş-geçmiş sunulmaz.
- **Migrasyon ham veri sözleşmesi:** Migrasyon `UserDefaults.data(forKey:)` ile raw data okur; eski anahtarlar `tesbihim.counterState`/`tesbihim.historyEntries`, backup’ları aynı isim + `.migrationBackup` olur. Valid snapshot varsa yalnız stale legacy cleanup yürür. Eksik tek anahtar başlangıç değeriyle birleşir; decode edilemeyen legacy veri karantinaya alınır ve açık hata verir. Her backup-copy, snapshot-write/validate, cleanup sonrası yeniden açılış güvenli biçimde aynı noktadan devam eder.
- **Ad snapshot ve sıralama:** `HistoryEntry` kayıt sırası için kalıcı `recordedOrder: Int64` taşır. Aynı gün/zikir tek agregadır; gün içinde ad değişirse son yazılan ad bu agreganın adı olur ve `recordedOrder` güncellenir. Dönem zikir başlığı seçili dönemdeki en yeni `localDayKey`, eşitse en yüksek `recordedOrder` snapshot’ını kullanır; günlük satır kendi snapshotını korur. Zikir ayrıntısı dönem toplamı, hedef, aktif gün, günlük metinsel dağılım ve tüm-zaman toplamını gösterir.
- **Tüm veri servisi:** `AllLocalDataService` actor/protokolü `CounterHistoryRepository`, `UserSettingsRepository`, `CustomDhikrRepository`, `DhikrUserStateRepository`, onboarding anahtarı ve reminder marker/istek adaptörlerini tek rollback paketi altında toplar. Her adaptör `backup()`, `clear()`, `restore()` sağlar; tümünün backupı alınmadan clear başlamaz. Commit başarısızlığında tüm yerel adaptörler geri yüklenir; başarılı yerel committen sonra ReminderManager iptal edilir. RootTabView ve DhikrLibrary ViewModel aynı servisin sonucu ile yeniden yüklenir. Entitlement yalnız okunur, pakete girmez.
- **Kirli ağaç güvenliği:** Bu çalışma mevcut kullanıcının değişiklikleri üzerinde yürütülür; hiçbir geniş `git add` kullanılmaz, commit zorunlu değildir. Her olası committen önce `git diff --cached`, sonra yalnız tam dosya/hunk için `git add -p -- <path>` kullanılır; kullanıcı değişikliği bulunan hunk stage edilmez. `xcodegen generate` sonrası `git status --short` kontrol edilir ve üretilen `.xcodeproj` asla stage edilmez.

## Dosya yapısı

- Create: `Sources/TesbihimApp/Models/CounterHistorySnapshot.swift` — sürüm, invariantlar, işlem komutları ve yükleme durumu.
- Modify: `Sources/TesbihimApp/Models/CounterState.swift` — gün/zikir/ad snapshot’lı `LastIncrement`, uyumlu decode.
- Modify: `Sources/TesbihimApp/Models/HistoryEntry.swift` — kanonik `localDayKey` ve eski `date` decode migrasyonu.
- Create: `Sources/TesbihimApp/Persistence/CounterHistoryRepository.swift` — actor, atomik dosya yazımı, yedek/karantina/migrasyon.
- Create: `Sources/TesbihimApp/Statistics/HistoryStatisticsCalculator.swift` — dönem sınırları, günlük noktalar ve sıralı özetler.
- Modify: `Sources/TesbihimApp/ViewModels/CounterViewModel.swift`, `HistoryViewModel.swift` — actor tabanlı mutasyonlar, yükleme/hata durumları.
- Create: `Sources/TesbihimApp/ViewModels/CounterHistoryStore.swift`, `Sources/TesbihimApp/Persistence/AllLocalDataService.swift` — paylaşılmış snapshot composition root ve rollback’li yerel silme.
- Create: `Sources/TesbihimApp/Views/Gecmis/HistoryDetailViews.swift`, `HistoryChartView.swift` — dönem, gün gün, zikir ayrıntısı ve chart.
- Modify: `Sources/TesbihimApp/Views/Gecmis/GecmisView.swift`, `RootTabView.swift`, `AyarlarView.swift` — yeni akış ve silme yönlendirmeleri.
- Modify/Create: `Tests/TesbihimAppTests/CounterHistoryRepositoryTests.swift`, `HistoryStatisticsCalculatorTests.swift`, `HistoryAccessibilityTests.swift`, mevcut counter/history testleri.

## Chunk 1: Model, snapshot ve kayıpsız migrasyon

### Task 1: Kanonik gün anahtarını ve snapshot modelini tanımla

**Files:**
- Create: `Sources/TesbihimApp/Models/CounterHistorySnapshot.swift`
- Modify: `Sources/TesbihimApp/Models/HistoryEntry.swift`
- Modify: `Sources/TesbihimApp/Models/CounterState.swift`
- Test: `Tests/TesbihimAppTests/CounterHistoryRepositoryTests.swift`

- [ ] **Step 1: Başarısız model testlerini yaz**

`HistoryEntry(localDayKey: "2026-03-30", recordedOrder: ..., ...)`in saat dilimi/DST değişiminden etkilenmemesini; aynı gün/zikir birikiminde gün içi son ad snapshot’ının ve en yüksek `recordedOrder`ın korunmasını; `completedTargetCount`ın birden fazla olabilmesini; `LastIncrement(localDayKey:dhikrID:dhikrNameSnapshot:completedTarget:)`ın eksiksiz Codable turunu; snapshot `mutationRevision`ının kalıcı artışını doğrula.

- [ ] **Step 2: Testleri çalıştır ve beklenen başarısızlığı doğrula**

Run: `xcodegen generate && xcodebuild test -scheme Tesbihim -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:TesbihimAppTests/CounterHistoryRepositoryTests`

Expected: model/simge bulunamadığı için FAIL.

- [ ] **Step 3: En küçük model uygulamasını yaz**

Gregorian, `en_US_POSIX`, sabit `yyyy-MM-dd` biçimleyicili `LocalDayKey` üret; `HistoryEntry`de `localDayKey`, `recordedOrder`, `dhikrID`, `dhikrNameSnapshot`, `addedCount`, `completedTargetCount`ı kanonik alan yap. `CounterHistorySnapshot(version: 1, mutationRevision: Int64, counter: CounterState, entries: [HistoryEntry])` oluştur; negatif sayıları normalize eden ve aynı `(localDayKey, dhikrID)` çifti tekrarını en yeni ad/order ile birleştiren doğrulama sun.

- [ ] **Step 4: Model testlerini geçir**

Run: yukarıdaki test komutu. Expected: PASS.

- [ ] **Step 5: Commit**

Bu kirli ağaçta otomatik commit yok: `git diff --check && git diff --cached`; kullanıcı isterse yalnız oluşturulan/yalnızca bu görev hunk’ları `git add -p -- Sources/TesbihimApp/Models/CounterHistorySnapshot.swift Sources/TesbihimApp/Models/HistoryEntry.swift Sources/TesbihimApp/Models/CounterState.swift Tests/TesbihimAppTests/CounterHistoryRepositoryTests.swift` ile seçilir.

### Task 2: Atomik repository ve idempotent eski veri migrasyonu

**Files:**
- Create: `Sources/TesbihimApp/Persistence/CounterHistoryRepository.swift`
- Modify: `Sources/TesbihimApp/Persistence/CounterRepository.swift`
- Modify: `Sources/TesbihimApp/Persistence/HistoryRepository.swift`
- Test: `Tests/TesbihimAppTests/CounterHistoryRepositoryTests.swift`

- [ ] **Step 1: Başarısız repository testlerini yaz**

Test çiftini `FileManager` geçici dizini ve ayrı test `UserDefaults(suiteName:)` ile kur. Şunları kapsa: eski anahtarların backup → yeni snapshot → validate → cleanup sırası; her ara aşamada yeniden açılış; yeni snapshotın eski kaynağa üstünlüğü; ana dosya bozukken sağlam yedek; ikisi de bozukken `unrecoverableData`; yazma hatasında eski ana/yedek korunması; karantina dosyası.

- [ ] **Step 2: Başarısızlığı doğrula**

Run: aynı `-only-testing` komutu. Expected: repository tipi/metotları bulunamadığı için FAIL.

- [ ] **Step 3: Actor repositoryyi uygula**

`actor CounterHistoryRepository` `load()` ve `mutate(_:) async throws -> SnapshotLoadResult` sağlar. Geçici dosyaya yaz, `replaceItemAt`/atomic move yap, yeniden decode+validate et; yeni ana doğrulandıktan sonra önceki sağlıklı ana kopyayı `.backup`a güncelle. Hata türleri `recoveredFromBackup`, `unrecoverableData`, `writeFailed` olarak UI’ın ayrım yapacağı değerleri taşır. Eski iki repositoryyi kullanımdan çıkarırken yalnız migrasyon okuyucusu olarak koru.

- [ ] **Step 4: Repository testlerini geçir**

Run: aynı komut. Expected: PASS.

- [ ] **Step 5: Commit**

Bu kirli ağaçta otomatik commit yok: `git diff --check && git diff --cached`; kullanıcı isterse yalnız görev hunk’ları `git add -p -- Sources/TesbihimApp/Persistence/CounterHistoryRepository.swift Sources/TesbihimApp/Models/CounterHistorySnapshot.swift Tests/TesbihimAppTests/CounterHistoryRepositoryTests.swift` ile seçilir.

## Chunk 2: Sayma bütünlüğü ve saf istatistikler

### Task 3: Sayaç komutlarını tek atomik mutasyona taşı

**Files:**
- Modify: `Sources/TesbihimApp/ViewModels/CounterViewModel.swift`
- Modify: `Sources/TesbihimApp/ViewModels/HistoryViewModel.swift`
- Create: `Sources/TesbihimApp/ViewModels/CounterHistoryStore.swift`
- Modify: `Sources/TesbihimApp/App/RootTabView.swift`, `Views/Sayac/SayacView.swift`, `Views/SayacRoute.swift`, ilgili Kütüphane/editör çağrı noktaları
- Modify: `Tests/TesbihimAppTests/CounterViewModelTests.swift`
- Modify: `Tests/TesbihimAppTests/HistoryViewModelTests.swift`

- [ ] **Step 1: Başarısız async testleri yaz**

Eşzamanlı 1.000 `increment`ın kayıpsız sonucu; kasıtlı gecikmiş eski actor dönüşünün daha yeni `mutationRevision` UI’ını ezememesi; hedef tamamlanması; gece yarısı sonrası undo’nun özgün gün/zikir/adı azaltması; manuel değer farkının yalnız tekrar deltası; reset/zikir-hedef değişiminin `lastIncrement`ı temizlemesi; geçmiş silindikten sonra undo’nun negatif satır yaratmaması; repository write failure’da state/feedback değişmemesi testlerini yaz.

- [ ] **Step 2: Başarısızlığı doğrula**

Run: `xcodegen generate && xcodebuild test -scheme Tesbihim -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:TesbihimAppTests/CounterViewModelTests -only-testing:TesbihimAppTests/HistoryViewModelTests`

- [ ] **Step 3: `@MainActor` ViewModel köprüsünü uygula**

App root tek actor/store örneğini iki ViewModel’e enjekte eder. Her komut actor mutasyonuna `await` eder; `CounterState` ve entries ancak store revizyon kontrolünden sonra atanır. `increment` komutu gün anahtarı/ad snapshot’ını bir kez üretir; `undo` onu kullanır. Eşzamanlı UI task’ları için store eski revizyonu reddeder. Tüm senkron çağrı noktaları `Task`a taşınır. Başarıdan sonra feedback/anons, hatada erişilebilir tekrar dene duyurusu verilir.

- [ ] **Step 4: İlgili testleri geçir**

Run: yukarıdaki komut. Expected: PASS.

- [ ] **Step 5: Commit**

Bu kirli ağaçta otomatik commit yok: `git diff --check && git diff --cached`; kullanıcı isterse yalnız görev hunk’ları `git add -p -- Sources/TesbihimApp/ViewModels/CounterHistoryStore.swift Sources/TesbihimApp/ViewModels/CounterViewModel.swift Sources/TesbihimApp/ViewModels/HistoryViewModel.swift Tests/TesbihimAppTests/CounterViewModelTests.swift Tests/TesbihimAppTests/HistoryViewModelTests.swift` ile seçilir.

### Task 4: Saf dönem ve istatistik hesaplayıcısını oluştur

**Files:**
- Create: `Sources/TesbihimApp/Statistics/HistoryStatisticsCalculator.swift`
- Test: `Tests/TesbihimAppTests/HistoryStatisticsCalculatorTests.swift`

- [ ] **Step 1: Başarısız sınır testlerini yaz**

Bugün/hafta/ay/tümü; pazartesi başlangıcı; yıl/ay geçişi; sıfır günlü Pazartesi–Pazar noktaları; devam eden dönem günlük ortalama paydası; geçmiş dönem tam paydası; önceki dönem boş; tümü için ortalama/karşılaştırma yok; eşit yoğun gün/zikirde `localDayKey` sonra `recordedOrder` ile deterministik sıralama; seçili dönem zikir başlığında en yeni snapshot testlerini yaz.

- [ ] **Step 2: Başarısızlığı doğrula**

Run: `xcodegen generate && xcodebuild test -scheme Tesbihim -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:TesbihimAppTests/HistoryStatisticsCalculatorTests`

- [ ] **Step 3: Hesaplayıcıyı uygula**

`HistoryPeriod` ve referans `Date`/Gregorian calendar alan `HistoryStatisticsCalculator` uygula. Girdi yalnız `localDayKey` karşılaştırır; ekranın ihtiyacı olan özet, karşılaştırma metin verisi, yedi günlük grafik noktası, gün gün satırı ve zikir dökümünü üretir. Sayı formatlaması hesaplayıcıda değil ortak sunum biçimleyicide yapılır.

- [ ] **Step 4: Testleri geçir ve commit et**

Run: yukarıdaki komut. Expected: PASS.

Bu kirli ağaçta otomatik commit yok: `git diff --check && git diff --cached`; kullanıcı isterse yalnız görev hunk’ları `git add -p -- Sources/TesbihimApp/Statistics/HistoryStatisticsCalculator.swift Tests/TesbihimAppTests/HistoryStatisticsCalculatorTests.swift` ile seçilir.

## Chunk 3: Geçmiş kullanıcı arayüzü ve erişilebilirlik

### Task 5: Ana ekran, dönem ayrıntısı ve zikir geçmişini uygula

**Files:**
- Modify: `Sources/TesbihimApp/Views/Gecmis/GecmisView.swift`
- Create: `Sources/TesbihimApp/Views/Gecmis/HistoryDetailViews.swift`
- Modify: `Sources/TesbihimApp/ViewModels/HistoryViewModel.swift`
- Test: `Tests/TesbihimAppTests/HistoryAccessibilityTests.swift`

- [ ] **Step 1: Başarısız sunum/erişilebilirlik testleri yaz**

Bugün boş/dolu metni; genel bakış; dönem seçicinin seçili değeri; gelecek dönem düğmesinin devre dışılığı ve gidilecek dönem etiketinin yerelleştirilmiş olması; zikir adının en yeni snapshot’tan gelmesi; zikir ayrıntısının dönem toplamı/hedef/aktif gün/günlük dağılım/tüm-zaman toplamını göstermesi; “Gün Gün İncele”nin görünür ayrı ekran olması; boş dönem “Zikirmatiğe Git” eyleminin tab yönlendirmesi; Voice Control kısa adları; silme odağının başlığa dönmesi ve zikir silmenin yalnız o zikirde etkili olması testlerini yaz.

- [ ] **Step 2: Başarısızlığı doğrula**

Run: `xcodegen generate && xcodebuild test -scheme Tesbihim -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:TesbihimAppTests/HistoryAccessibilityTests`

- [ ] **Step 3: Ekranları uygula**

Ana bilgi sırasını Bugün → Genel Bakış → Bu Haftanın Seyri → Zikirler → Dönemleri İncele → Veri Yönetimi tut. Dönem ayrıntısında `Picker` ile Bugün/Hafta/Ay/Tümü, hafta/ay için açık önceki-sonraki düğmeleri, zikir ayrıntısında gün gün görünüm ve “Bu Zikrin Geçmişini Sil” onayı bulunur. Kartlar büyük yazıda `ViewThatFits`/dikey `VStack` kullanır. Bozuk veri durumunda boş görünüm yerine erişilebilir hata ve tekrar dene göster.

- [ ] **Step 4: Testleri geçir ve commit et**

Run: yukarıdaki komut. Expected: PASS.

Bu kirli ağaçta otomatik commit yok: `git diff --check && git diff --cached`; kullanıcı isterse yalnız görev hunk’ları `git add -p -- Sources/TesbihimApp/Views/Gecmis/GecmisView.swift Sources/TesbihimApp/Views/Gecmis/HistoryDetailViews.swift Sources/TesbihimApp/ViewModels/HistoryViewModel.swift Tests/TesbihimAppTests/HistoryAccessibilityTests.swift` ile seçilir.

### Task 6: Görünür chart ve metinsel eşdeğerini ekle

**Files:**
- Create: `Sources/TesbihimApp/Views/Gecmis/HistoryChartView.swift`
- Modify: `Sources/TesbihimApp/Views/Gecmis/GecmisView.swift`
- Test: `Tests/TesbihimAppTests/HistoryAccessibilityTests.swift`

- [ ] **Step 1: Başarısız eşdeğerlik testini yaz**

Grafiğin yedi `DailyHistoryPoint`ı ile Gün Gün İncele satırlarının aynı gün/tekrar/hedef verisini kullandığını, sıfır günlerin her iki kaynakta korunduğunu test et.

- [ ] **Step 2: Başarısızlığı doğrula**

Run: önceki erişilebilirlik test komutu. Expected: FAIL.

- [ ] **Step 3: Swift Charts ve descriptor uygula**

Görünür `Chart` üstüne doğrudan `accessibilityChartDescriptor` bağla; gizli ikinci chart/list oluşturma. Grafik seçimi zorunlu eylem değildir. Doğal dil özeti ve “Gün Gün İncele” NavigationLink’i aynı grafik modelini alır. Görünür ve accessibility metinlerinde aynı `IntegerFormatStyle`/locale kullanılır.

- [ ] **Step 4: Testleri geçir ve commit et**

Run: önceki komut. Expected: PASS.

Bu kirli ağaçta otomatik commit yok: `git diff --check && git diff --cached`; kullanıcı isterse yalnız görev hunk’ları `git add -p -- Sources/TesbihimApp/Views/Gecmis/HistoryChartView.swift Sources/TesbihimApp/Views/Gecmis/GecmisView.swift Tests/TesbihimAppTests/HistoryAccessibilityTests.swift` ile seçilir.

## Chunk 4: Silme, uygulama genelinde temizleme ve doğrulama

### Task 7: Geçmiş/tüm veri silme işlemlerini güvenli uygula

**Files:**
- Modify: `Sources/TesbihimApp/Persistence/CounterHistoryRepository.swift`
- Create: `Sources/TesbihimApp/Persistence/AllLocalDataService.swift`
- Modify: `Sources/TesbihimApp/Views/Gecmis/GecmisView.swift`
- Modify: `Sources/TesbihimApp/Views/Ayarlar/AyarlarView.swift`
- Modify: `Sources/TesbihimApp/App/RootTabView.swift`
- Test: `Tests/TesbihimAppTests/CounterHistoryRepositoryTests.swift`

- [ ] **Step 1: Başarısız silme/kurtarma testleri yaz**

Zikir geçmişi silme, tüm geçmişi silme, tüm veri silme ayrımı; tüm veri silmede snapshot, legacy key, ayar, custom/state, onboarding ve reminder-marker yedeği; üçüncü yerel adaptör temizleme hatasında geri yükleme ve iki ViewModel reloadu; bildirim iptalinin commit sonrası yapılması; silmeden sonra undo no-op geçmiş deltası testlerini yaz. Ayrıca backup recovery sonrası ikinci açılış, primary repair write failure, iki geçersiz dosyada Retry/onaylı Bozuk Veriyi Sil ve bu çözülmeden sayımın engelli olması testlerini ekle.

- [ ] **Step 2: Başarısızlığı doğrula**

Run: repository test komutu. Expected: FAIL.

- [ ] **Step 3: İşlemleri uygula**

Repositoryde scoped delete komutları uygula. `AllLocalDataService`, her somut local adaptörün backup/clear/restore sözleşmesini uygular. Tüm veri işlemini, işlem öncesi backup + kalıcı cleanup marker + local commit + dış bildirim iptali + marker temizliği olarak modelle; uygulama açılışında marker varsa tamamla. Alert metinleri etki alanını açıkça ayırsın; başarıda root/library state yeniden yüklenir ve odak ilgili başlığa kısa duyuru ile taşınır.

- [ ] **Step 4: Testleri geçir ve commit et**

Run: repository test komutu. Expected: PASS.

Bu kirli ağaçta otomatik commit yok: `git diff --check && git diff --cached`; kullanıcı isterse yalnız görev hunk’ları `git add -p -- Sources/TesbihimApp/Persistence/AllLocalDataService.swift Sources/TesbihimApp/Persistence/CounterHistoryRepository.swift Sources/TesbihimApp/Views/Gecmis/GecmisView.swift Sources/TesbihimApp/Views/Ayarlar/AyarlarView.swift Sources/TesbihimApp/App/RootTabView.swift Tests/TesbihimAppTests/CounterHistoryRepositoryTests.swift` ile seçilir.

### Task 8: Uçtan uca derleme ve erişilebilirlik doğrulaması

**Files:** tüm değişen üretim/test dosyaları.

- [ ] **Step 1: Tüm testleri çalıştır**

Run: `xcodegen generate && xcodebuild test -scheme Tesbihim -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`

Expected: tüm testler PASS.

- [ ] **Step 2: Manuel cihaz kontrol listesi uygula**

Gerçek cihazda VoiceOver ile odak sırası/descriptor ve bozuk-veri Retry/silme akışı, en büyük Dynamic Type, Switch Control dönem gezinmesi, Voice Control görünür düğme adları, Türkçe ve İngilizce büyük sayı okunuşu, koyu tema/Bold Text/Increase Contrast/Reduce Motion, ana/backup dosya hata durumları ve hızlı sayımda gecikmeyen feedback kontrol edilir. Sonuçları her madde için cihaz/iOS sürümü ve geçti/kaldı olarak teslim notuna kaydet.

- [ ] **Step 3: Son doğrulama ve commit**

Run: aynı tam test komutu ve `git diff --check`.

`git diff --check && git status --short`; yalnız kullanıcı hunk’ları dışındaki, tek tek seçilmiş dosya/hunklar istenirse `git add -p -- <path>` ile stage edilir.
