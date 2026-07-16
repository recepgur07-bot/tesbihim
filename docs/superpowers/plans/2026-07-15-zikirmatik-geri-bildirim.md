# Zikirmatik Geri Bildirim Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ses efektini bağımsız ve varsayılan açık bir ayara dönüştürmek; kuyruksuz, parmakla eşzamanlı geri bildirim sağlamak.

**Architecture:** `UserSettings` ses tercihini kalıcı olarak tutar ve eski kayıtları koruyarak çözer. `CounterViewModel` ses/konuşma kararlarını ayırır. `SystemFeedbackProvider`, sesi tekrar başlatılabilen tek bir oynatıcıyla üretir; titreşim her geçerli sayımda anlık kalır.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation, Swift Testing, XcodeGen/iOS 17.

---

## Chunk 1: Ayar ve ViewModel davranışı

### Task 1: Ses anahtarı testleri

**Files:**
- Modify: `Tests/TesbihimAppTests/CounterViewModelTests.swift`
- Modify: `Sources/TesbihimApp/Models/UserSettings.swift`
- Modify: `Sources/TesbihimApp/ViewModels/CounterViewModel.swift`

- [ ] **Step 1:** Ses açıkken, konuşma açık/kapalı olmasına bakmadan artış ve geri almada tik üretildiğini; ses kapalıyken sıfır tik üretildiğini belirten başarısız testler ekle.
- [ ] **Step 2:** Sadece ilgili test hedefini çalıştırıp testin yeni alan/davranış eksikliğiyle başarısız olduğunu doğrula.
- [ ] **Step 3:** `soundEffectEnabled` alanını varsayılan `true` ile ekle; özel kod çözmeyle eski JSON'daki diğer ayarları koru ve ViewModel ses kararını bu alana bağla.
- [ ] **Step 4:** İlgili testi yeniden çalıştırıp geçtiğini doğrula.

### Task 2: Ayarlar arayüzü

**Files:**
- Modify: `Sources/TesbihimApp/Views/Ayarlar/AyarlarView.swift`
- Test: `Tests/TesbihimAppTests/CounterViewModelTests.swift`

- [ ] **Step 1:** Ayar güncellemesinin ses alanını kalıcılaştırdığını ve eski JSON'un eksik alanla başarıyla yüklendiğini gösteren başarısız birim testleri ekle.
- [ ] **Step 2:** Testi çalıştırıp başarısızlığını doğrula.
- [ ] **Step 3:** Ayarlar'a `Ses Efekti` anahtarını ekle; açıklamasını sıra dışı gecikme olmayacağını anlatacak şekilde güncelle.
- [ ] **Step 4:** Testi çalıştırıp geçtiğini doğrula.

## Chunk 2: Kuyruksuz sistem geri bildirimi

### Task 3: İptal edilebilir ses oynatma

**Files:**
- Modify: `Sources/TesbihimApp/Accessibility/FeedbackProviding.swift`
- Test: Gerçek cihaz doğrulaması (ses/haptic donanım API'si birim testte taklit edilmez)

- [ ] **Step 1:** Mevcut `AudioServicesPlaySystemSound` kullanımının geri çağrısız ve iptal edilemez olduğunu doğrula.
- [ ] **Step 2:** `AVAudioPlayer` ile önceden hazır tek oynatıcı kullan; her yeni tikte önce durdurup başa sararak çal.
- [ ] **Step 3:** Titreşimi ses sınırından bağımsız tut; her geçerli sayımda anlık üret.
- [ ] **Step 4:** Xcode test paketini çalıştır ve gerçek cihazda rotorla ileri/geri seri hareket, ani bırakma, ayarı kapatıp yeniden açma kontrolünü yap.
