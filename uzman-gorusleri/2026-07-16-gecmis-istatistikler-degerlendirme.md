# Tesbihim Geçmiş/İstatistikler Uzman Değerlendirmesi

## 1. Kısa Sonuç

**Genel karar: Önemli revizyon gerekli** (tasarım belgesinin kendisi olgun ve tutarlı; ama mevcut kod tabanıyla arasındaki fark, "kodlamaya hazır" iddiasını zayıflatıyor ve belgenin bazı hesaplama/mimari kararları netleştirilmeden uygulamaya geçilmemeli).

**En güçlü 3 yön:**
- Streak/rozet/liderlik tablosunun bilinçli ve gerekçeli biçimde dışlanması, manevi bağlama uygun, tutarlı bir üründür.
- Ham tekrar + tamamlanan hedefin birlikte, biri diğerini gizlemeden sunulması ve "başarı yüzdesi yok" kararı isabetlidir.
- `localDayKey` + versiyonlu migrasyon + bozuk veri karantinası fikri doğru yönde; "sessizce sıfırlama yerine açık hata" ilkesi yaşlı/VoiceOver kullanıcısını gizli veri kaybından koruyor.

**En önemli 3 risk:**
1. Tasarım belgesi, mevcut kodda **hiç var olmayan** bir `CounterHistoryTransactionCoordinator`, `localDayKey`, ay/tüm-zamanlar hesaplayıcıları, grafik ve zikir bazlı silme varsayıyor — bu bir "MVP küçük ek" değil, `HistoryEntry`, `HistoryViewModel`, `CounterState.LastIncrement` ve `CounterViewModel`'in yeniden yazılmasını gerektiren bir mimari geçiştir (bkz. Bölüm 3).
2. Mevcut `CounterState.LastIncrement` yalnızca `completedTarget: Bool` taşıyor; gün anahtarı/zikir kimliği yok. Tasarımın "gece yarısını aşan Geri Al doğru güne uygulanır" gereksinimi **bugünkü kodda karşılanmıyor** — bu ciddi bir veri bütünlüğü açığı, kozmetik değil.
3. Sayaç durumu ile geçmiş yazımı bugün iki ayrı, atomik olmayan yazma (`persist()` sonra `history.recordDelta()`); tasarım belgesindeki transaction coordinator bunu çözmeyi hedefliyor ama coordinator'ın kendisi de (pending-log + idempotency) gerçek karmaşıklık/risk taşıyor, aşağıda ayrıntılı ele alınıyor.

**Uygulama planına geçmeyi engelleyen konu var mı?** Evet, kısmen: gün anahtarı/geri alma mimarisi (Bölüm 6.1) ve transaction coordinator'ın somut hata-kurtarma semantiği netleşmeden kodlamaya geçilirse, geriye dönük düzeltilmesi pahalı bir veri modeli hatası riski var. Bunun dışında ürün/bilgi mimarisi kodlamaya başlanabilir düzeyde olgun.

---

## 2. Zorunlu Düzeltmeler

### [Öncelik: Kritik] `LastIncrement` gün/zikir bilgisi taşımıyor — gece yarısı Geri Al kuralı bugünkü kodda uygulanamaz

- **İlgili belge ve bölüm:** Tasarım Bölüm 6.1 ("Geri Al gece yarısından sonra yapılsa bile delta bugüne değil son artışın özgün gün/zikir kaydına uygulanır") vs. `Sources/TesbihimApp/Models/CounterState.swift:18-20` (`LastIncrement` yalnız `completedTarget: Bool`).
- **Sorun:** `CounterViewModel.undo()` (CounterViewModel.swift:191-204) geri alma deltasını **her zaman `Date()`** (yani "şimdi") ile `history.recordDelta` çağırarak yazıyor (`HistoryViewModel.recordDelta` içinde `calendar.startOfDay(for: Date())` kullanılıyor — HistoryViewModel.swift:56). Kullanıcı 23:58'de sayıp 00:02'de Geri Al derse, düzeltme yanlışlıkla **bugüne** değil **yeni güne** yazılır; dünün toplamı yanlış yüksek kalır, bugünün toplamı yanlış negatif yönde etkilenir.
- **Neden önemli:** Bu, tasarım belgesinin kendi kabul kriteri olan bir sınır durumu (Bölüm 9: "Saat dilimi/DST/sistem takvimi değişiminde..." ve PLAN.md Bölüm 6 "Gece yarısından sonra yapılan Geri Al doğru güne uygulanıyor mu?"). İstatistik ekranının tüm güvenilirliği günlük toplamların doğruluğuna dayanıyor; bu sessiz bir yanlışlık, kullanıcı fark etmez.
- **Somut öneri:** `CounterState.LastIncrement`'a `localDayKey: String`, `dhikrID: String`, `dhikrNameSnapshot: String` alanları eklenmeli (tasarımın zaten öngördüğü gibi); `undo()` bu saklı gün anahtarıyla `history.recordDelta` çağırmalı, `Date()`'i değil.
- **Kabul ölçütü:** Birim testi: 23:59'da increment, sistem saatini ertesi güne ilerlet, undo çağır → dünün `HistoryEntry`'sinden `-1`, bugüne hiçbir kayıt yazılmaz.

### [Öncelik: Kritik] Sayaç durumu ve geçmiş yazımı atomik değil — kısmi yazma senaryosu tanımsız

- **İlgili belge ve bölüm:** Tasarım Bölüm 6.1 (`CounterHistoryTransactionCoordinator`) vs. `CounterViewModel.increment()` (CounterViewModel.swift:107-123): `persist()` çağrılır, hemen ardından `history.recordDelta(...)` çağrılır — iki ayrı `UserDefaults.set` işlemi, aralarında hiçbir işlem kaydı yok.
- **Neden önemli:** Uygulama bu iki çağrı arasında sonlanırsa (crash, arka planda öldürülme), sayaç ilerlemiş ama geçmişe yazılmamış olur — Genel Bakış/Bugün toplamı gerçek sayımdan **kalıcı olarak** düşük kalır, kullanıcı bunu asla fark edemez ve düzeltemez. Bu tam olarak PLAN.md Bölüm 6'nın sorduğu "yazmanın her aşamasında uygulamanın kapanması" senaryosu.
- **Somut öneri:** Ya (a) tasarımın önerdiği transaction coordinator'ı gerçekten uygula (aşağıda Bölüm 3'te bu yaklaşımın kendi riskleri tartışılıyor), ya da (b) daha basit bir alternatif: sayaç ve geçmişi **tek bir depoda, tek yazmada** tut (aynı UserDefaults anahtarı altında `{state, historyEntries}` birlikte encode edilip tek `save` ile yazılır). (b), iki ayrı depo + pending-transaction-log karmaşıklığından daha az risklidir ve UserDefaults zaten atomik tek-anahtar yazma sağlıyor.
- **Kabul ölçütü:** `increment()` çağrısı sırasında rastgele bir noktada process sonlandırılırsa (test: yazma sırasını simüle eden fake repository), sayaç ve geçmiş her zaman tutarlı bir çift olarak yeniden yüklenir (ya ikisi de eski, ya ikisi de yeni; asla biri eski biri yeni olmaz).

### [Öncelik: Yüksek] `HistoryEntry.date: Date` hâlâ mevcut kodda; `localDayKey`'e geçiş henüz yapılmamış

- **İlgili belge ve bölüm:** Tasarım Bölüm 6 ("kanonik alanlar... `localDayKey`") vs. `Sources/TesbihimApp/Models/HistoryEntry.swift:9` (`var date: Date`).
- **Sorun:** Şu anki model saat dilimi/DST karşısında kırılgan: `date` bir `Date` (mutlak an) olarak saklanıyor, günü belirlemek için her sorguda `calendar.isDate(_:inSameDayAs:)` çağrılıyor — kullanıcı saat dilimi değiştirirse (seyahat) geçmiş kayıtlar farklı güne kayabilir, çünkü gün sınırı kayıt anında değil **okuma anındaki** takvimle hesaplanıyor.
- **Neden önemli:** Tasarımın en isabetli kararlarından biri tam olarak bunu önlemek için var ("sonraki saat dilimi/DST/sistem takvimi değişiklikleri `localDayKey` değerini yeniden yorumlamaz"); mevcut kod bu korumayı sağlamıyor.
- **Somut öneri:** `HistoryEntry.localDayKey: String` (`yyyy-MM-dd`, kayıt anında hesaplanıp donmuş) alanına geçiş yapılmalı; migrasyon adımı (eski `date` alanından tek seferlik türetme) tasarımdaki gibi yedekli ve geri alınabilir olmalı.
- **Kabul ölçütü:** Kayıt oluşturulduktan sonra cihaz saat dilimi değiştirilirse, o kaydın günü değişmez; birim testi sabit `Calendar`/saat dilimiyle doğrulanır.

### [Öncelik: Orta] Mevcut `GecmisView`/`HistoryViewModel`, tasarım belgesinin kapsamının küçük bir alt kümesi — "Ay", "Tümü", grafik, karşılaştırma, en yoğun gün, zikir bazlı silme yok

- **İlgili belge ve bölüm:** Tasarım Bölüm 3.2–3.6, 5 vs. `HistoryViewModel.swift` (yalnız `today`, `thisWeek`, `total`; ay yok, karşılaştırma yok, günlük ortalama yok, en yoğun gün yok) ve `GecmisView.swift` (düz liste, grafik yok, "Dönemleri İncele" yok, zikir bazlı silme yok).
- **Sorun:** Bu beklenen bir durum olabilir (tasarım "sonraki adım" olarak yazıldıysa), ama belge "Durum: Kullanıcı tarafından onaylandı; uygulama planı öncesi tasarım şartnamesi" diyor — mevcut kodun bunun bir öncül/prototip mi yoksa terk edilecek bir MVP mi olduğu belirtilmemiş.
- **Neden önemli:** Aradaki fark küçük bir "ekleme" değil; `HistoryViewModel` ve `GecmisView`'in ciddi bir yeniden yazımını gerektiriyor. Bu, planlama/efor tahmini açısından şeffaf olmalı.
- **Somut öneri:** PLAN.md Bölüm 12'ye (Yol Haritası) bu geçişin kapsamını netleştiren bir not eklenmeli: mevcut basit `HistoryViewModel` tamamen mi değiştirilecek, yoksa kademeli mi genişletilecek?
- **Kabul ölçütü:** Yol haritasında "Geçmiş" adımı somut alt görevlere bölünmüş (veri modeli migrasyonu → hesaplayıcı → view → grafik → silme akışları) ve her biri ayrı test edilebilir.

---

## 3. Teknik Mimari Değerlendirmesi

### HistoryEntry ve localDayKey
**Karar: Revize edilmeli.** Alan seçimi (`localDayKey`, `dhikrID`, ad snapshot, `completedTargetCount: Int`) doğru — boolean yerine Int olması, bir günde birden fazla hedef tamamlanabilmesi gerçeğiyle uyumlu. Ama mevcut kod henüz `date: Date` kullanıyor (yukarıda Zorunlu Düzeltme). Migrasyonun "ham veri yedeklenir, yeni veri doğrulanmadan eski anahtar silinmez" kuralı doğru bir güvenlik ağı; küçük veri hacminde (muhtemelen birkaç yüz kayıt) bu maliyetsiz.

### Dönem/istatistik hesaplayıcısı
**Karar: Uygun, tasarım olarak.** Hesaplayıcının `Date()`'e doğrudan bağımlı olmaması, takvim/referans tarihin dışarıdan verilmesi (Bölüm 6 sonu) doğru bir test edilebilirlik kararı. Günlük ortalamanın devam eden dönemde yalnızca geçmiş günleri paydaya alması, tamamlanmış geçmiş dönemde tüm günleri alması tutarlı ve mantıklı. Tek dikkat noktası: "Tümü" görünümünde payda "ilk geçmiş kaydı ile bugün arasındaki gün sayısı" — bu, kullanıcı aylarca ara verdiyse günlük ortalamayı olduğundan düşük gösterir (ör. 1 yıl önce 1 gün kullanıp bırakan kullanıcı "günde 0,3 tekrar" görür). Bu; matematiksel olarak doğru ama ürün olarak yanıltıcı olabilir — bkz. Bölüm 8.

### CounterHistoryTransactionCoordinator
**Karar: Gereksiz karmaşık, aynı zamanda eksik tanımlı.** Pending-transaction-log + iki depoda `lastAppliedTransactionID` + idempotent recovery deseni, dağıtık sistemlerde (birden fazla süreç/makine) yerinde bir teknik; ama burada **tek süreç, tek cihaz, UserDefaults** bağlamında bu, çözdüğü sorunun büyüklüğüyle orantısız bir mimari ağırlık getiriyor:
- UserDefaults zaten tek bir `set(_:forKey:)` çağrısı için atomiklik sağlar (plist senkron yazılır). Sayaç + geçmişi **tek bir Codable zarfta, tek anahtar altında** tutmak, iki depo + pending log + idempotency ID yönetiminden çok daha az kod, çok daha az hata yüzeyiyle aynı garantiyi (atomik çift-yazma) verir.
- Tasarımın kendisi de "Bu günlük yalnız tamamlanmamış tek işlemi tutar" diyor — yani zaten çoklu-işlem senaryosunu desteklemiyor; o zaman neden genel bir transaction-log soyutlaması, neden tek bir "pending write" flag + iki alanı aynı anda içeren tek dosya değil?
- Ayrıca belirtilmemiş bir risk: adım 2 ("Geçmiş deposu deltayı uygular") başarılı, adım 3 ("Sayaç deposu yeni durumu saklar") başarısız olursa, geçmiş ilerlemiş ama sayaç geride kalmış olur — kullanıcı ekranda eski sayıyı görür ama geçmişte fazladan bir tekrar var. Recovery mantığı "yalnız eksik tarafı uygular" diyor ama sayaç durumu zaten değişmez bir "yeni durum" olarak pending kayıtta saklıysa, geçmiş tarafı zaten uygulanmışken sayaç tarafını da aynı pending kayıttan tekrar uygulamak güvenli mi (idempotent mi) — bu, "iki taraf da version/hash ile karşılaştırılıp doğrulanmalı" ayrıntısı belgede yok.

**Önerilen değişiklik:** Tek bir `CounterHistorySnapshot` struct'ı (`state: CounterState`, `entries: [HistoryEntry]`) tanımlayıp tek bir repository/tek bir `save()` ile yaz. Bu, "iki depo arası tutarsızlık" sınıfının tamamını yapısal olarak ortadan kaldırır; ayrı transaction ID, pending log, recovery kodu gerekmez. Dezavantajı: geçmiş büyüdükçe her artışta tüm geçmişi yeniden yazmak I/O maliyeti getirir — ama Faz 1 hacminde (günlük birkaç yüz KB'a kadar) bu önemsizdir; büyürse (yıllar sonra binlerce `HistoryEntry`) o zaman ayrı dosyaya geçiş düşünülebilir, şimdiden değil.

### Repository ve veri migrasyonu
**Karar: Uygun.** Protokol arkasında soyutlama (`HistoryRepository`, `CounterRepository`) zaten mevcut kodda var ve doğru desende. Versiyonlu zarf + migrasyon fikri sağlam.

### Bozuk veri kurtarma
**Karar: Uygun.** "Sessizce sıfırlamak yerine açık hata + Tekrar Dene + Bozuk Geçmişi Sil" kararı, hedef kitle (yaşlı/VoiceOver) için doğru — sessiz veri kaybı, yanlış ama kendinden emin bir "0 kayıt" göstermekten daha kötü olurdu. Zaman damgalı karantina anahtarına kopyalama, kullanıcı desteği/hata ayıklama için de faydalı. Mevcut kodda (`UserDefaultsHistoryRepository.load()`) bu davranış **henüz yok** — decode hatasında sessizce `[]` dönüyor (HistoryRepository.swift:18-26), bu tasarımın "Ekran kayıt yokmuş gibi davranmaz" ilkesini bugün ihlal ediyor. Bu, "Zorunlu Düzeltmeler"e eklenebilecek kadar önemli ama kritik değil çünkü henüz gerçek veri kaybı riski taşıyan bir üretim senaryosu yok; yine de kodlama sırasında ilk yapılacaklardan biri olmalı.

### Tüm verileri silme akışı
**Karar: Uygun, iyi düşünülmüş.** "Yedek al → geri alınabilir silmeleri yap → kalıcı 'tamamlanıyor' işareti yaz → bildirimleri iptal et → işareti kaldır" sırası, uygulama ara adımlar arasında kapanırsa bile tutarlı bir kurtarma sağlıyor — bu, PLAN.md Bölüm 6'nın sorduğu riski doğru ele alıyor. StoreKit entitlement'ının silinmemesi, yalnız yerel önbelleğin temizlenmesi doğru (satın alma hakkı Apple hesabına ait). Mevcut kodda (`GecmisView.swift:59-68`) bu davranış henüz **yok** — "Tüm Verilerimi Sil" bugün sadece `clearHistory()` + `resetAllData()` çağırıyor, ayarlar/hatırlatıcı/onboarding silinmiyor, yedek alma/kısmi başarısızlık kurtarma yok. Bu beklenen bir eksiklik (henüz o kapsam kodlanmamış) ama net biçimde işaretlenmeli.

### Gelecekte CloudKit uyumu
**Karar: Şimdilik uygun, ama tek bir gerçek risk var.** `localDayKey` + `dhikrID` bazlı günlük agregasyon, CloudKit senkronizasyonuna PLAN.md'nin öngördüğü gibi "olay tabanlı birleştirme" değil, "son yazan kazanır" birleştirme uygulanırsa **iki cihazda aynı gün aynı zikre yapılan artışlar birbirini ezer**, kayıp verir (Cihaz A'da 5, Cihaz B'de 3 artış yapılmış olsa, senkron sonrası 5 veya 3 kalır, 8 değil). Bu tasarım belgesinde açıkça kapsam dışı bırakılmış ("CloudKit tasarımında ayrıca ele alınır") — bu doğru bir erteleme, ama günlük agregasyon modelinin **kendisinin** bu sorunu yapısal olarak zorlaştırdığı (tam olay log'u olsaydı diff/merge mümkün olurdu, agregat sayılarda mümkün değil) net biçimde not edilmeli ki Faz 2 başında sürpriz olmasın.

---

## 4. Ürün ve Bilgi Mimarisi Değerlendirmesi

**Ana ekran bilgi sırası:** Bugün → Genel Bakış → Haftanın Seyri → Zikirler → Dönemleri İncele → Veri Yönetimi sırası mantıklı: en somut/güncel bilgiden genele, sonra ayrıntıya, sonra yönetime doğru gidiyor. Veri Yönetimi'nin en altta, istatistik içeriğinden ayrı tutulması isabetli — yanlışlıkla silme butonuna erken rastlama riskini azaltıyor.

**Dönem seçimi:** Bugün/Hafta/Ay/Tümü dört seçenek, çoğu benzer uygulamadaki 5-6 seçenekten (gün/hafta/ay/3ay/yıl/tümü) daha sade — bu doğru bir kısıtlama, "yıl" ve "3 ay" gibi ara dönemler gerçek kullanıcı değeri katmadan karmaşıklık ekler.

**Genel seyir / zikir bazlı ayrıntı dengesi:** Dengeli. "Zikirler" bölümünün üstte özet, altta ayrıntıya inen bir yapı sunması (Bölüm 3.4 → Zikir Geçmişi Ayrıntısı) doğru kademeli açılma.

**Karşılaştırma ve ortalamalar:** Genel olarak isabetli, ama iki nokta zayıf:
- "Tümü" görünümünde günlük ortalamanın "ilk kayıttan bugüne kadarki tüm günler" üzerinden hesaplanması, ara verilen dönemleri de paydaya kattığı için kullanıcının gerçek/yakın zamanlı temposunu yansıtmıyor — bu matematiksel olarak savunulabilir ama ürün değeri tartışmalı (bkz. Bölüm 8).
- "Önceki eşdeğer dönemle sayısal karşılaştırma" iyi bir karar (yüzde değil sayı — küçük sayılarda yüzdenin abartılı görünmesini önlüyor), ama **her zaman gösterilmesi** bazı kullanıcılarda istemeden bir "performans takibi" hissi yaratabilir; bu, "streak yok" ilkesiyle hafif gerilim içinde. Yine de rakip/rekabet çağrışımı taşımayan nötr dil ("320 tekrar fazla" vs "4 gün streak") kullanıldığı için kabul edilebilir bir denge.

**Boş durumlar:** İyi ele alınmış — "henüz kayıt yok" dili yargılamıyor, grafik yerine metin gösteriliyor, gelecek döneme gezinme engelleniyor.

**Silme işlemlerinin anlaşılabilirliği:** Dört farklı silme kavramı var: Geçmişi Sil, Tüm Verilerimi Sil, Bu Zikrin Geçmişini Sil, Sayacı Sıfırla. Bunların isimleri ve etki alanları belgede net tanımlanmış, ama **dört farklı geri alınamaz aksiyonun aynı ürün içinde bu kadar yakın konumlarda bulunması**, özellikle yaşlı kullanıcı için kavramsal yük oluşturuyor — bkz. Bölüm 8 (sadeleştirme önerisi).

**Manevi bağlama uygunluk:** Güçlü yön. Dil sakin, yargılamayan, rekabet unsuru yok. Bu, belgenin en tutarlı başarısı.

---

## 5. Erişilebilirlik Değerlendirmesi

**Kör/gören eşdeğerliği:** Kavramsal olarak doğru tasarlanmış — "Gün Gün İncele" listesi hem görsel hem VoiceOver kullanıcısı için **aynı ekranda, aynı görünürlükte** (yalnız VoiceOver'a özel gizli bir liste değil). Bu doğru bir karar; genellikle yapılan hata, görsel kullanıcıya grafik + VoiceOver kullanıcıya ayrı "gizli" metin sunmaktır — burada ikisi de aynı listeyi görüyor, bu iyi.

**VoiceOver gezinme sırası:** Belgede açıkça tanımlanmamış tek nokta: "Gün Gün İncele" listesinin grafikle **aynı ekranda mı yoksa ayrı bir alt ekranda mı** olduğu netleşmemiş (Bölüm 3.3 metninden ikisi de aynı ekranda gibi okunuyor, ama bu VoiceOver odak sırası açısından — 7 satırlık bir liste + kartlar + grafik + zikir listesi bir arada— ekranı **çok sayıda öğeyle** yorucu hale getirebilir; bkz. sorulan soru "Ekran çok sayıda VoiceOver öğesi oluşturarak yorucu hale gelebilir mi?" → evet, gerçek bir risk).

**`accessibilityChartDescriptor` konumlandırması:** Teknik olarak doğru API seçimi (SwiftUI Charts + `accessibilityChartDescriptor` iOS 15+'ta mevcut, iOS 17 min hedefiyle uyumlu). Ama belge, grafiğin VoiceOver'da AXChart olarak mı yoksa descriptor'ın grafik View'ına mı yoksa ayrı bir invisible elemana mı bağlanacağını belirtmiyor — bu implementasyon detayı ama yanlış yapılırsa grafik VoiceOver'da hiç görünmez ya da "Gün Gün İncele" ile duplike okunur riski var. Kodlama öncesi netleştirilmeli.

**Dynamic Type / Bold Text / Increase Contrast / Reduce Motion:** Belgede genel olarak anılmış (Bölüm 7) ama somut kabul kriteri yok — "desteklenir" demek yeterli değil; hangi bileşenin (kartlar, grafik, liste) en büyük Dynamic Type'ta nasıl davranacağı (dikey akış, `ViewThatFits`, min ölçek faktörü) tanımlanmamış. PLAN.md Bölüm 5'teki genel kural burada tekrar somutlaştırılmalı.

**Voice Control / Switch Control:** Belgede "Voice Control için görünür eylemlerin kısa ve benzersiz adları" deniyor ama Switch Control için özel bir madde yok — Ana Sayaç ekranı bölümünde (PLAN.md 7.1) bu ayrım titizlikle yapılmışken, Geçmiş ekranında aynı titizlik eksik. Özellikle önceki/sonraki dönem düğmeleri ve grafik etkileşiminin Switch Control ile nasıl çalışacağı belirsiz.

**Büyük sayıların okunması:** Belirtilmemiş bir boşluk — "1.240 tekrar" gibi büyük sayılar VoiceOver'da yerel sayı formatlamasıyla mı (`NumberFormatter.locale`) okunacak, yoksa ham `Int` string'i mi? Türkçe'de binlik ayraç nokta, İngilizce'de virgül; VoiceOver bunu farklı okuyabilir. Kabul kriteri eksik.

**Eksik kabul kriterleri (özet):** Grafik-liste VoiceOver odak sırası, en büyük Dynamic Type'ta kart/grafik/liste davranışı, Switch Control için önceki/sonraki dönem gezinmesi, büyük sayı formatlaması.

---

## 6. Eksik Testler ve Sınır Durumları

| Öncelik | Senaryo | Beklenen davranış | Neden gerekli |
|---|---|---|---|
| Kritik | Gece yarısını aşan Geri Al | Delta, artışın orijinal `localDayKey`'ine yazılır, bugüne değil | Mevcut kodda bu kural uygulanmıyor (Bölüm 2, Kritik madde 1) |
| Kritik | `increment()` sırasında process crash (sayaç yazıldı, geçmiş yazılmadı ya da tersi) | Yeniden açılışta sayaç ve geçmiş tutarlı bir çift olarak yüklenir | Bugün atomik olmayan iki ayrı yazma var |
| Yüksek | Geçmiş kaydı Geri Al'dan önce "Geçmişi Sil" ile silinmiş | Geri alma sayaçta uygulanır ama geçmişte no-op olur, negatif kayıt oluşmaz | Tasarımda tanımlı (Bölüm 6.1) ama test yok |
| Yüksek | Saat dilimi/DST değişimi sonrası eski `localDayKey` kayıtları | Eski kayıtların günü değişmez | Seyahat eden kullanıcı senaryosu, tasarımın temel iddiası |
| Yüksek | Depo decode hatası (bozuk JSON) | Ekran "okunamadı" gösterir, sessizce boş liste göstermez, karantina anahtarına kopyalanır | Mevcut kod bugün sessizce `[]` dönüyor |
| Orta | Zikir özelinde geçmiş silme, aynı `dhikrID`'nin başka güne ait kayıtları | Yalnız o `dhikrID`'ye ait tüm kayıtlar silinir, diğer zikirler etkilenmez | Doğrudan Bölüm 4'ün gereksinimi |
| Orta | Tüm verileri silerken üçüncü depo (örn. hatırlatıcı) başarısız olur | Yedekten geri dönülür, kısmi başarı duyurulmaz | Bölüm 3.6'nın kritik kabul kriteri |
| Orta | Ay/hafta geçişinde "önceki dönem" boşsa | Yüzde/sonsuz artış gösterilmez, "geçen ay kayıt yoktu" | Bölüm 5'in açık kuralı |
| Orta | Aynı gün içinde birden fazla hedef tamamlanması | `completedTargetCount` günlük satırda doğru artıyor (Int, boolean değil) | Model kararının doğruluğunu doğrulamak için |
| Orta | En yoğun gün / en çok yapılan zikir eşitliği | Tanımlı deterministik sıralama (Bölüm 5) uygulanıyor | Belirsiz sıralama testte flaky sonuç doğurur |
| Düşük | En büyük Dynamic Type'ta kart/grafik/liste taşması | İçerik kesilmez, dikey akışa geçer | PLAN.md Bölüm 5 genel kural |
| Düşük | VoiceOver ile grafik + "Gün Gün İncele" arasında dolaşma | Aynı 7 veri noktasına iki farklı yoldan erişim tutarlı, duplike anons yok | Erişilebilirlik eşdeğerliği iddiası |

---

## 7. Yaratıcı veya Farklı Fikirler

- **Fikir:** "Tümü" görünümünde günlük ortalamayı tek bir sayı yerine, kullanıcının **etkin kullandığı günler** üzerinden ikinci bir görünümle de sunmak — örn. yalnız "günde X" demek yerine "340 günde 12.400 tekrar" gibi her ikisini birden göstermek.
  - **Kullanıcıya faydası:** Uzun süre ara vermiş kullanıcının "günlük ortalamam neden bu kadar düşük" kafa karışıklığını önler; sayı yanıltıcı olmaktan çıkar.
  - **Erişilebilirlik etkisi:** Nötr, metinsel — ek karmaşıklık yaratmaz.
  - **Teknik maliyet:** Düşük (mevcut hesaplanan değerlerin yeniden ifadesi).
  - **Şimdi mi, sonra mı:** Şimdi (tasarım metnine tek cümlelik ekleme).
  - **Mevcut sade ürün anlayışına uyuyor mu:** Evet, sadeliği azaltmaz, netliği artırır.

- **Fikir:** Dört ayrı silme aksiyonunu (Geçmişi Sil, Tüm Verilerimi Sil, Bu Zikrin Geçmişini Sil, Sayacı Sıfırla) kavramsal olarak **iki katmana** indirmek: "Bu zikri etkileyen işlemler" (Sayacı Sıfırla + Bu Zikrin Geçmişini Sil, Zikir Detayı'nda yan yana) ve "Tüm uygulamayı etkileyen işlemler" (Geçmişi Sil + Tüm Verilerimi Sil, Veri Yönetimi'nde yan yana) — isimlendirme aynı kalır, sadece gruplama netleşir.
  - **Kullanıcıya faydası:** Dört ayrı geri alınamaz butonun "hangisi ne yapıyor" karmaşasını azaltır; yaşlı kullanıcı için kritik.
  - **Erişilebilirlik etkisi:** VoiceOver'da section header'larla ("Bu Zikri Etkileyenler" / "Tüm Uygulamayı Etkileyenler") gruplandığı için Rotor'la atlanabilir, karışıklık azalır.
  - **Teknik maliyet:** Düşük (yalnızca view düzeni, mantık değişmiyor).
  - **Şimdi mi, sonra mı:** Şimdi — bu bir görsel/bilgi mimarisi kararı, kodlamayı etkilemiyor.
  - **Mevcut sade ürün anlayışına uyuyor mu:** Evet.

- **Fikir:** "Bu ayki en uzun ara" gibi boşluk/kesinti odaklı bir ölçü **önerilmiyor** — bu tür ölçüler pasif olsa bile suçluluk/kesinti hissi yaratma riski taşıdığından bilinçli olarak dışarıda bırakılıyor.

En fazla 3 fikir sundum çünkü geri kalan olası fikirler (paylaşılabilir istatistik kartı, haftalık özet bildirimi, yıl görünümü) ya kapsam dışı kararla zaten çelişiyor ya da gerçek kullanıcı değeri kanıtlanmamış küçük eklemeler; zorla 5'e tamamlamak istemedim.

---

## 8. Çıkarılması veya Sadeleştirilmesi Gerekenler

- **`CounterHistoryTransactionCoordinator` mevcut haliyle aşırı mühendislik.** Yukarıda (Bölüm 3) detaylandırıldığı gibi, tek-cihaz/tek-süreç bağlamında pending-log + iki depo + idempotent recovery yerine tek zarfta atomik tek yazma yeterli ve çok daha az hata yüzeyi taşıyor. Bu, PLAN.md'nin kendi ilkesiyle de örtüşüyor: "Bu çözüm güvenilir mi, yoksa gereğinden fazla karmaşık mı?" — cevap: gereğinden fazla karmaşık.
- **"Tümü" görünümünde günlük ortalama, az değer sağlıyor olabilir.** Yıllarca ara veren bir kullanıcı için bu sayı sürekli düşer ve anlamını kaybeder; ya Bölüm 7'deki fikirle (etkin gün sayısı da göster) tamamlanmalı ya da "Tümü" görünümünden tamamen çıkarılıp yalnız Hafta/Ay'da gösterilmeli.
- **Dört ayrı silme aksiyonu birleştirilebilir konumlandırma açısından** (Bölüm 7'deki gruplama önerisi) — işlevsellik korunur, sadece bilgi mimarisi netleşir.
- **Daha sade teknik alternatif — Genel Bakış kartlarının ve "Dönemleri İncele" seçicisinin kısmen aynı bilgiyi tekrar ediyor olabileceği** düşünülmeli: şu an hem üstte sabit "Genel Bakış" (Hafta/Ay/Tümü toplamları) hem altta ayrı bir "Dönemleri İncele" seçici var. Belge bunu "genel seyir vs ayrıntı" ayrımıyla gerekçelendiriyor (haklı bir gerekçe), ama kullanıcı testinde bu iki bölümün kafa karıştırıp karıştırmadığı özellikle gözlenmeli — burada net bir hata iddia etmiyorum, sadece prototip aşamasında doğrulanması gereken bir varsayım olarak işaretliyorum.

---

## 9. Nihai Öneri

1. **Tasarım uygulama planına geçmeye hazır mı?** Kısmen. Ürün/bilgi mimarisi ve erişilebilirlik ilkeleri kodlamaya başlanabilecek olgunlukta. Ama veri modeli/transaction katmanı (Bölüm 6.1) mevcut kodla tutarsız ve kendi içinde gereğinden karmaşık; bu katman netleşmeden geçmiş ekranının veri yazma tarafına geçilmemeli.

2. **Uygulamadan önce mutlaka değişmesi gerekenler neler?**
   - `CounterState.LastIncrement`'a gün anahtarı/zikir kimliği eklenmeli (gece yarısı Geri Al düzeltmesi).
   - Sayaç+geçmiş yazımı atomik hale getirilmeli — tercihen tek zarf/tek yazma ile, transaction-log yerine.
   - `HistoryEntry.date` → `localDayKey` migrasyonu gerçekten uygulanmalı.
   - Bozuk veri kurtarma davranışı (`load()` sessizce `[]` dönmemeli) kodlanmalı.

3. **Korunması gereken kararlar neler?**
   - Streak/rozet/liderlik tablosu yokluğu.
   - Ham tekrar + tamamlanan hedefin birlikte, yüzdesiz sunumu.
   - Grafik + "Gün Gün İncele" metinsel eşdeğerliği (aynı ekranda, aynı görünürlükte).
   - İki aşamalı zikir kaldırma modeli (PLAN.md 7.7) ile tutarlı, geri alınabilir silme yaklaşımı.
   - Sakin, yargılamayan dil.

4. **En değerli tek yeni fikir nedir?** Transaction coordinator'ı tek-zarf/tek-yazma modeliyle değiştirmek — hem karmaşıklığı hem kırılganlığı azaltır, tasarımın kendi "aşırı mühendislik olmasın" ilkesiyle daha tutarlıdır.

5. **Önerdiğin nihai ekran ve teknik modelin kısa özeti nedir?** Ekran mimarisi (Bugün → Genel Bakış → Haftanın Seyri → Zikirler → Dönemleri İncele → Veri Yönetimi) olduğu gibi korunmalı; teknik tarafta `HistoryEntry` `localDayKey` alanına geçmeli, `CounterState.LastIncrement` gün/zikir bilgisini taşımalı, sayaç ve geçmiş **tek bir Codable zarfta tek repository üzerinden** atomik yazılmalı (ayrı transaction-log/idempotency katmanı olmadan), bozuk veri kurtarma açıkça hata gösterip karantinaya almalı, ve hesaplayıcı katmanı `Date()`'e bağımlı olmayan saf fonksiyonlar olarak kalmalı.
