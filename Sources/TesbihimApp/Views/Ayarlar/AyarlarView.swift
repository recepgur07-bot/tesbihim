import SwiftUI

/// Ayarlar ekranı — bkz. PLAN.md Bölüm 7.4. `Form`, iOS Ayarlar
/// uygulamasının tanıdık desenine uygun bölümlere ayrılmıştır.
struct AyarlarView: View {
    var counterViewModel: CounterViewModel
    @State private var showingClearHistoryConfirmation = false
    @State private var showingClearAllConfirmation = false

    private var historyViewModel: HistoryViewModel { counterViewModel.historyViewModel }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sayma ve Erişilebilirlik") {
                    Toggle("Sayıyı Sesli Söyle", isOn: spokenCountBinding)
                    Toggle("Ses Efekti", isOn: soundEffectBinding)
                    Text("Ses efekti, sayma ve geri alma hareketiyle eşzamanlı kısa bir tık verir. Sayıyı sesli söyleme tercihiyle bağımsızdır.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    NavigationLink("Nasıl çalışır?") {
                        KarsilamaView()
                    }
                    Picker("Haptic Yoğunluğu", selection: hapticIntensityBinding) {
                        Text("Hafif").tag(UserSettings.HapticIntensity.light)
                        Text("Orta").tag(UserSettings.HapticIntensity.medium)
                        Text("Güçlü").tag(UserSettings.HapticIntensity.strong)
                    }
                    .pickerStyle(.segmented)
                    Toggle("Ekran Uyanık Kalsın", isOn: keepScreenAwakeBinding)
                }

                Section("Hızlı Sayım (Tek Dokunuş)") {
                    Toggle("Hızlı Sayımı Etkinleştir", isOn: fastCountModeBinding)
                    Text("Sayaç ekranında Sihirli Dokunuş (iki parmakla çift dokunuş) ile açılır; tek dokunuşla art arda sayar. Kapatmak için her zaman görünen 'Kapat' düğmesi kullanılır.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Toggle("Hızlı Sayımda Titreşim", isOn: fastCountHapticBinding)
                        .disabled(!counterViewModel.settings.fastCountModeEnabled)
                    Toggle("Hızlı Sayımda Ses Efekti", isOn: fastCountSoundBinding)
                        .disabled(!counterViewModel.settings.fastCountModeEnabled)
                    Toggle("Hızlı Sayımda Sayıyı Duyur", isOn: fastCountAnnounceBinding)
                        .disabled(!counterViewModel.settings.fastCountModeEnabled)
                    Text("Sayıyı Duyur açıksa, çok hızlı art arda dokunuşlarda VoiceOver anonsu geriden gelebilir; emin değilseniz kapalı bırakın.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Görünüm") {
                    Picker("Tema", selection: themeBinding) {
                        Text("Sistem").tag(UserSettings.Theme.system)
                        Text("Açık").tag(UserSettings.Theme.light)
                        Text("Koyu").tag(UserSettings.Theme.dark)
                    }
                    Text("Yazı boyutunu değiştirmek için iPhone Ayarları → Erişilebilirlik → Ekran ve Metin Boyutu → Daha Büyük Metin.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Ses") {
                    Picker("Ses/Titreşim Profili", selection: soundProfileBinding) {
                        Text("Sessiz").tag(UserSettings.SoundProfile.silent)
                        Text("Hafif").tag(UserSettings.SoundProfile.light)
                        Text("Normal").tag(UserSettings.SoundProfile.normal)
                    }
                }

                Section("Destek") {
                    Text("Destekçi Paketi ve Gönüllü Destek yakında burada olacak (bkz. PLAN.md Bölüm 8).")
                        .foregroundStyle(.secondary)
                }

                Section("Veri") {
                    Button("Geçmişi Sil", role: .destructive) {
                        showingClearHistoryConfirmation = true
                    }
                    Button("Tüm Verilerimi Sil", role: .destructive) {
                        showingClearAllConfirmation = true
                    }
                }

                Section("Hakkında") {
                    LabeledContent("Sürüm", value: appVersion)
                    Link("Gizlilik Politikası", destination: URL(string: "https://recepgur07-bot.github.io/tesbihim/gizlilik-politikasi.html")!)
                    Link("Destek / Düzeltme Bildirimi", destination: URL(string: "mailto:seslerinizindeapps@outlook.com")!)
                    NavigationLink("Nasıl Kullanılır?") {
                        KarsilamaView()
                    }
                }
            }
            .navigationTitle("Ayarlar")
            .alert("Geçmiş Silinsin mi?", isPresented: $showingClearHistoryConfirmation) {
                Button("İptal", role: .cancel) {}
                Button("Sil", role: .destructive) {
                    historyViewModel.clearHistory()
                }
            } message: {
                Text("Bugün/Bu Hafta/Toplam kayıtları silinir. Güncel zikir sayacınız etkilenmez. Bu işlem geri alınamaz.")
            }
            .alert("Tüm Veriler Silinsin mi?", isPresented: $showingClearAllConfirmation) {
                Button("İptal", role: .cancel) {}
                Button("Sil", role: .destructive) {
                    historyViewModel.clearHistory()
                    counterViewModel.resetAllData()
                }
            } message: {
                Text("Geçmiş kayıtları ve güncel zikir sayaç durumu tamamen silinir. Bu işlem geri alınamaz.")
            }
        }
    }

    private var appVersion: String {
        Bundle(for: BundleMarker.self).infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var spokenCountBinding: Binding<Bool> {
        Binding(
            get: { counterViewModel.settings.spokenCountEnabled },
            set: { value in counterViewModel.updateSettings { $0.spokenCountEnabled = value } }
        )
    }

    private var soundEffectBinding: Binding<Bool> {
        Binding(
            get: { counterViewModel.settings.soundEffectEnabled },
            set: { value in counterViewModel.updateSettings { $0.soundEffectEnabled = value } }
        )
    }

    private var hapticIntensityBinding: Binding<UserSettings.HapticIntensity> {
        Binding(
            get: { counterViewModel.settings.hapticIntensity },
            set: { value in counterViewModel.updateSettings { $0.hapticIntensity = value } }
        )
    }

    private var keepScreenAwakeBinding: Binding<Bool> {
        Binding(
            get: { counterViewModel.settings.keepScreenAwake },
            set: { value in counterViewModel.updateSettings { $0.keepScreenAwake = value } }
        )
    }

    private var themeBinding: Binding<UserSettings.Theme> {
        Binding(
            get: { counterViewModel.settings.theme },
            set: { value in counterViewModel.updateSettings { $0.theme = value } }
        )
    }

    private var soundProfileBinding: Binding<UserSettings.SoundProfile> {
        Binding(
            get: { counterViewModel.settings.soundProfile },
            set: { value in counterViewModel.updateSettings { $0.soundProfile = value } }
        )
    }

    private var fastCountModeBinding: Binding<Bool> {
        Binding(
            get: { counterViewModel.settings.fastCountModeEnabled },
            set: { value in counterViewModel.updateSettings { $0.fastCountModeEnabled = value } }
        )
    }

    private var fastCountHapticBinding: Binding<Bool> {
        Binding(
            get: { counterViewModel.settings.fastCountHapticEnabled },
            set: { value in counterViewModel.updateSettings { $0.fastCountHapticEnabled = value } }
        )
    }

    private var fastCountSoundBinding: Binding<Bool> {
        Binding(
            get: { counterViewModel.settings.fastCountSoundEnabled },
            set: { value in counterViewModel.updateSettings { $0.fastCountSoundEnabled = value } }
        )
    }

    private var fastCountAnnounceBinding: Binding<Bool> {
        Binding(
            get: { counterViewModel.settings.fastCountAnnounceEnabled },
            set: { value in counterViewModel.updateSettings { $0.fastCountAnnounceEnabled = value } }
        )
    }
}

#Preview {
    AyarlarView(counterViewModel: CounterViewModel())
}
