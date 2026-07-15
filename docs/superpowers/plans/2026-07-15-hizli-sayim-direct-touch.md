# Hızlı Sayım Doğrudan Dokunma Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** VoiceOver kullanan kişi Hızlı Sayım modundayken ekranın her yerine tek parmakla dokunarak sayabilsin; iki parmak çift dokunuşla konumdan bağımsız güvenle açıp kapatabilsin.

**Architecture:** UIKit köprüsündeki küçük `FastCountTouchGate`, bir temas dizisinin tam olarak bir sayım üretip üretemeyeceğini belirler. `HizliSayimYuzeyi` bu kapıyı UIKit dokunuş olaylarına bağlar ve yalnızca geçerli tek parmaklı tamamlanmış temas için `CounterViewModel.incrementFast()` çağrısını iletir. `SayacView`, tek sahip olduğu mod durumu ile yüzeyi ekler/kaldırır ve Sihirli Dokunuş geçişlerini anında duyurur.

**Tech Stack:** Swift 6, SwiftUI, UIKit, Swift Testing, XcodeGen, iOS 17.

---

## Chunk 1: Doğrudan dokunma çekirdeği

### Task 0: Gerçek cihaz çıkış-jesti fizibilite kapısı

**Files:**
- Temporary create/delete: `Sources/TesbihimApp/Accessibility/FastCountMagicTapPrototype.swift`
- Temporary modify/revert: `Sources/TesbihimApp/Views/Sayac/SayacView.swift`

- [ ] **Step 1: Ayrı, atılabilir bir debug prototipinde tüm ekranı kaplayan `allowsDirectInteraction` UIKit view'ını ve kök `.magicTap` eylemini kurun.**

Prototip yalnızca şu soruyu yanıtlar: Hızlı mod açıkken iki parmak çift dokunma hâlâ kök `SayacView` eylemine ulaşarak yüzeyi kapatabiliyor mu? `SayacView` içine geçici bir `@State` ve koşullu tam ekran prototip yüzeyi ekleyin; mevcut kök `.accessibilityAction(.magicTap)` bu state'i açıp kapatacak şekilde geçici olarak bağlanır. Prototipte sayım, ayar, ses veya kalıcılık eklemeyin.

Run: `xcodegen generate && xcodebuild -project Tesbihim.xcodeproj -scheme Tesbihim -destination 'platform=iOS,name=<bağlı-cihaz-adı>' build`

- [ ] **Step 2: VoiceOver açık gerçek cihazda en az dört ekranda konumda açma ve kapanmayı deneyin.**

Expected: iki parmak çift dokunma yüzey açıkken de kök eylemi tetikler; yüzey kapanır.

- [ ] **Step 3: Sonucu kaydedin ve kapıya göre ilerleyin.**

Pass: geçici dosyayı silin ve `SayacView` değişikliğini geri alın; tasarım belgesinin "Gerçek cihazda VoiceOver ile kabul testi" bölümüne cihaz/iOS sürümü ve dört konumdaki açma-kapatma sonucunu ekleyin, sonra Task 1'e geçin.  
Fail: geçici dosyayı silin ve `SayacView` değişikliğini geri alın; bu planı uygulamayın ve yeni ekran-geneli çıkış-jesti tasarımı için kullanıcıya dönün.

### Task 1: Dokunma sözleşmesi için başarısız birim testleri

**Files:**
- Create: `Tests/TesbihimAppTests/FastCountTouchGateTests.swift`
- Create: `Sources/TesbihimApp/Accessibility/FastCountTouchGate.swift`

- [ ] **Step 1: Tek parmaklı tamamlanmış temas için başarısız test yazın.**

```swift
@Test func completedSingleFingerTouchProducesOneCount() {
    var gate = FastCountTouchGate()
    let touch = UUID()
    gate.begin(activeTouches: [touch])
    #expect(gate.end(touch: touch))
}
```

- [ ] **Step 2: Çoklu parmak, sonradan eklenen parmak ve iptal edilen temasların sayılmadığını gösteren başarısız testleri ekleyin.**

```swift
@Test func multiTouchAndCancelledTouchesNeverProduceCounts() {
    var gate = FastCountTouchGate()
    let first = UUID(); let second = UUID()
    gate.begin(activeTouches: [first, second])
    #expect(gate.end(touch: first) == false)

    gate.begin(activeTouches: [first])
    gate.begin(activeTouches: [first, second])
    #expect(gate.end(touch: first) == false)

    gate.cancel()
    #expect(gate.end(touch: first) == false)
}
```

- [ ] **Step 3: İlgili test hedefini çalıştırıp testin eksik tür nedeniyle başarısız olduğunu doğrulayın.**

Run: `xcodegen generate && xcodebuild -project Tesbihim.xcodeproj -scheme Tesbihim -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TesbihimAppTests/FastCountTouchGateTests test`

Expected: `FastCountTouchGate` bulunamadığı için derleme başarısız olur.

- [ ] **Step 4: Kapıyı en küçük davranışla uygulayın.**

```swift
struct FastCountTouchGate {
    private var candidate: UUID?
    private var invalid = false

    mutating func begin(activeTouches: Set<UUID>) {
        guard candidate == nil else {
            if activeTouches.count > 1 { invalid = true }
            return
        }
        guard activeTouches.count == 1, let touch = activeTouches.first else { invalid = true; return }
        candidate = touch
    }

    mutating func end(touch: UUID) -> Bool {
        guard candidate == touch else { return false }
        defer { reset() }
        return !invalid
    }

    mutating func moved() { invalid = true }
    mutating func cancel() { reset() }
    mutating func reset() { candidate = nil; invalid = false }
}
```

Define `typealias TouchID = UUID` inside `FastCountTouchGate` and use `Set<FastCountTouchGate.TouchID>` everywhere. Add explicit tests for `moved()` and for an unrelated touch ending before the candidate; neither must produce a count.

- [ ] **Step 5: İlgili testleri yeniden çalıştırıp geçtiğini doğrulayın.**

Run: same command as Step 3.

Expected: `FastCountTouchGateTests` passes.

- [ ] **Step 6: Commit.**

```bash
git add Sources/TesbihimApp/Accessibility/FastCountTouchGate.swift Tests/TesbihimAppTests/FastCountTouchGateTests.swift
git commit -m "Hızlı Sayım dokunma kapısını ekle"
```

### Task 2: Tam ekran UIKit yüzeyini test-first ekleyin

**Files:**
- Create: `Sources/TesbihimApp/Accessibility/HizliSayimYuzeyi.swift`
- Modify: `Tests/TesbihimAppTests/FastCountTouchGateTests.swift`

- [ ] **Step 1: UIKit adapter'ın trait'ini ve event-to-gate eşlemesini test eden başarısız test ekleyin.**

```swift
@Test @MainActor func surfaceAllowsDirectInteractionAndCanBeDisabled() {
    var counts = 0
    let candidateTouch = UUID()
    let surface = FastCountDirectTouchView(onCount: { counts += 1 })
    #expect(surface.accessibilityTraits.contains(.allowsDirectInteraction))
    surface.processForTesting(.began([candidateTouch]))
    surface.processForTesting(.ended(candidateTouch))
    #expect(counts == 1)
    surface.processForTesting(.began([candidateTouch]))
    surface.disableAndReset()
    surface.processForTesting(.ended(candidateTouch))
    #expect(counts == 1)
}
```

Also add separate failing tests for `.began([first, second])`, a second `.began([first, second])` after a valid first begin, `.moved`, and `.cancelled`; every sequence must leave `counts` unchanged. Add a started valid sequence, invoke `disableAndReset()`, then end it and assert no callback.

- [ ] **Step 2: Testi çalıştırın ve eksik yüzey türü nedeniyle başarısız olduğunu doğrulayın.**

Run: command in Task 1, Step 3.

Expected: `FastCountDirectTouchView` bulunamadığı için derleme başarısız olur.

- [ ] **Step 3: Minimal UIKit köprüsünü uygulayın.**

`HizliSayimYuzeyi` `UIViewRepresentable` olmalı; iç `FastCountDirectTouchView`i tüm alanı kaplamalı ve `.allowsDirectInteraction` trait'ini vermelidir. `FastCountTouchGate.TouchID` somut olarak `UUID`dir; UIKit view her `UITouch` için yaşamı boyunca sabit bir `UUID` üretip saklar. `FastCountDirectTouchView.TestEvent` internal enumu tam olarak `.began(Set<TouchID>)`, `.ended(TouchID)`, `.moved`, `.cancelled` olmalı; `processForTesting(_:)` ve üretim `touches*` metodları aynı private event işleyicisini kullanmalıdır. `touchesBegan` tüm aktif temasların kimlik setini verir; `touchesMoved` kapıyı geçersiz kılar; `touchesEnded` yalnızca aday temas başarılı tamamlandıysa callback çağırır; `touchesCancelled` ve `disableAndReset()` kapıyı sıfırlar. `dismantleUIView` `disableAndReset()` çağırır.

- [ ] **Step 4: İlgili testleri çalıştırıp geçtiğini doğrulayın.**

Run: command in Task 1, Step 3.

Expected: tüm `FastCountTouchGateTests` geçer.

- [ ] **Step 5: Commit.**

```bash
git add Sources/TesbihimApp/Accessibility/HizliSayimYuzeyi.swift Tests/TesbihimAppTests/FastCountTouchGateTests.swift
git commit -m "Hızlı Sayım doğrudan dokunma yüzeyini ekle"
```

## Chunk 2: Sayaç ekranı bütünleştirmesi ve cihaz doğrulaması

### Task 3: Hızlı mod geçişini ve duyurularını test-first bütünleştirin

**Files:**
- Modify: `Sources/TesbihimApp/Views/Sayac/SayacView.swift`
- Modify: `Sources/TesbihimApp/ViewModels/CounterViewModel.swift`
- Modify: `Tests/TesbihimAppTests/CounterViewModelTests.swift`

- [ ] **Step 1: Hızlı mod geçiş duyurusu için başarısız ViewModel testleri ekleyin.**

```swift
@Test func fastCountModeAnnouncementsInterruptRatherThanQueue() {
    let announcer = RecordingAnnouncer()
    let viewModel = makeViewModel(announcer: announcer)
    viewModel.announceFastCountModeChange(isEnabled: true)
    viewModel.announceFastCountModeChange(isEnabled: false)
    #expect(announcer.announcements.isEmpty)
    #expect(announcer.interruptingAnnouncements == ["Hızlı sayım açık", "Hızlı sayım kapalı"])
}
```

No SwiftUI inspection dependency is added. Entry refusal, toggling, repeated-gesture idempotence, visible-button removal, and modal exit are verified by the mandatory device acceptance test because they are `@State`-local view integration behavior.

- [ ] **Step 2: İlgili testleri çalıştırın ve yeni helper veya davranış eksikliği nedeniyle başarısız olduğunu doğrulayın.**

Run: `xcodegen generate && xcodebuild -project Tesbihim.xcodeproj -scheme Tesbihim -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TesbihimAppTests test`

Expected: `announceFastCountModeChange(isEnabled:)` bulunamadığı için yeni test derleme başarısız olur.

- [ ] **Step 3: `SayacView`i minimal biçimde değiştirin.**

- `CounterViewModel`e `announceFastCountModeChange(isEnabled:)` ekleyin; bu metot yalnızca `announcer.announceInterrupting(...)` kullanarak yukarıdaki iki sabit metni gönderir. `SystemAccessibilityAnnouncer`ın mevcut attributed, queue-disabled uygulamasını kullanın; `UIAccessibility.post(.announcement, ...)` doğrudan `SayacView` içinde çağrılmayacaktır.
- `fastCountScreen` içinde eski `fastCountButton` ve `Kapat` düğmesini kaldırın; onun yerine tam ekran `HizliSayimYuzeyi(onCount: viewModel.incrementFast)` yerleştirin.
- Kök `.accessibilityAction(.magicTap)` tek giriş/çıkış olmaya devam etsin.
- Açarken önce `fastCountingEnabled = true` ile yüzeyi kurun, sonra `viewModel.announceFastCountModeChange(isEnabled: true)` çağırın. Kapatırken önce `fastCountingEnabled = false` ile yüzeyi kaldırın, sonra `viewModel.announceFastCountModeChange(isEnabled: false)` çağırın.
- Tek bir `exitFastCounting(announce:)` yardımcı metodu tanımlayın. `onDisappear`, rota değişimi, `showingResetConfirmation` değişimi ve `@Environment(\\.scenePhase)` ile `.background`/`.inactive` durumları bu yardımcıyı `announce: false` ile çağırır. Uygulamanın gelecekte sunacağı her sheet/alert/dialog da sunulmadan önce aynı yardımcıyı çağırmalıdır; bu ekranın mevcut tek alert'i `showingResetConfirmation`dır.
- Tekrarlı Magic Tap, açık modda yalnızca kapatır; ayar kapalıyken açma hiçbir durum değişikliği veya duyuru üretmez.
- Açma jestinin yüzey kurulmadan önceki dokunuşlarının sayılmaması, kapatma sırasında yüzeyin callback'inin çalışmaması zorunludur.

- [ ] **Step 4: Tüm otomatik test paketini çalıştırın.**

Run: `xcodegen generate && xcodebuild -project Tesbihim.xcodeproj -scheme Tesbihim -destination 'platform=iOS Simulator,name=iPhone 17' test`

Expected: bütün `TesbihimAppTests` ve `TesbihimProjectTests` geçer.

- [ ] **Step 5: Gerçek cihaz VoiceOver prototip kapısını uygulayın.**

VoiceOver açık iPhone’da aşağıdakileri kayda geçirerek doğrulayın:

1. Ayar kapalıyken iki parmak çift dokunma mod açmaz.
2. Ayar açıkken ekranın en az dört farklı bölgesinde iki parmak çift dokunma modu açar; sayı değişmez ve yalnızca bir kez “Hızlı sayım açık” duyulur.
3. Açıkken en az dört farklı bölgede tek parmak tek dokunuş tam +1 üretir.
4. Açıkken aynı dört bölgede iki parmak çift dokunma gerçekten modu kapatır; sayı değişmez ve yalnızca bir kez “Hızlı sayım kapalı” duyulur.
5. Kapanıştan sonra tek dokunma yalnızca VoiceOver keşfi yapar.
6. On hızlı dokunuşun ardından parmaklar kaldırıldığında sayı, ses veya titreşim geriden devam etmez.
7. Ayar kapalıyken Magic Tap mod açmaz veya duyuru yapmaz; mod açıkken ayar sonradan kapatılmış olsa bile Magic Tap kapatır. Arka plana geçme, rota değişimi ve sıfırlama uyarısı açılması hızlı modu sessizce kapatır.

If step 4 fails, stop implementation work. Do not add a location-dependent button fallback; return to design for an equivalent screen-wide exit gesture.

- [ ] **Step 6: Karar belgesini gerçek cihaz sonucu ile güncelleyin ve commit edin.**

```bash
git add Sources/TesbihimApp/Views/Sayac/SayacView.swift Sources/TesbihimApp/ViewModels/CounterViewModel.swift Sources/TesbihimApp/Accessibility/HizliSayimYuzeyi.swift Tests/TesbihimAppTests docs/superpowers/specs/2026-07-15-hizli-sayim-direct-touch-design.md
git commit -m "Hızlı Sayım ekran geneli dokunmayı etkinleştir"
```
