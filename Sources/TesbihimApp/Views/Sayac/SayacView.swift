import SwiftUI
import UIKit

/// Ana Sayaç ekranı — bkz. PLAN.md Bölüm 7.1 ve
/// 2026-07-15-sayac-sayma-alani-karar-taslagi.md Bölüm 10. VoiceOver
/// odak sırası: zikir adı → ilerleme özeti → büyük sayı → sayma yüzeyi →
/// alt aksiyonlar.
///
/// Hızlı Sayım, Sihirli Dokunuş ile açılıp kapanır (Ayarlar'da açıksa).
/// Açıkken doğrudan etkileşim yüzeyi ekranın her yerindeki geçerli tek
/// parmak dokunuşlarını sayar. Ekranın herhangi bir yerinde tek parmakla
/// kısa süre basılı tutmak, VoiceOver jestleriyle çakışmadan moddan çıkar.
struct SayacView: View {
    var viewModel: CounterViewModel
    var libraryViewModel: DhikrLibraryViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var path = NavigationPath()
    @State private var showingResetConfirmation = false
    @State private var fastCountingEnabled = false
    @State private var showingCountEditor = false

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Group {
                    if fastCountingEnabled {
                        fastCountScreen
                    } else {
                        ScrollView {
                            VStack(spacing: 24) {
                            NavigationLink(value: SayacRoute.library) {
                                Text(viewModel.selectedDhikrSummary)
                                    .font(.headline)
                            }
                            .accessibilityHint("Zikri veya hedefi değiştirmek için çift dokunun.")

                            Text(progressVisualText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)

                            Button { showingCountEditor = true } label: {
                                Text("\(viewModel.currentCount)")
                                .font(.system(size: 96, weight: .bold, design: .rounded))
                                .minimumScaleFactor(0.3)
                                .lineLimit(1)
                                .monospacedDigit()
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Geçerli sayı, \(viewModel.currentCount)")
                            .accessibilityHint("Sayıyı doğrudan girmek için çift dokunun.")

                            countingSurface

                            actionGrid
                        }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Zikirmatik")
            .sayacRouteDestinations(viewModel: viewModel, libraryViewModel: libraryViewModel, path: $path)
            .accessibilityAction(.magicTap, toggleFastCounting)
        }
        // Bölüm 5: "Ekran Uyanık Kalsın" açıkken Sayaç ekranındayken ekran
        // uyku moduna geçmez; ekrandan ayrılınca varsayılana dönülür.
        .onChange(of: viewModel.settings.keepScreenAwake, initial: true) { _, newValue in
            UIApplication.shared.isIdleTimerDisabled = newValue
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            exitFastCounting(announce: false)
        }
        // Zikir değiştirmek gibi başka bir ekrana geçilince Hızlı Sayım'da
        // kalınmaz — kullanıcı geri döndüğünde net bir başlangıç durumu olur.
        .onChange(of: path) { _, _ in
            exitFastCounting(announce: false)
        }
        .onChange(of: showingResetConfirmation) { _, isShowing in
            if isShowing { exitFastCounting(announce: false) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .inactive || phase == .background {
                exitFastCounting(announce: false)
            }
        }
        .onAppear { syncResolvedName() }
        .onChange(of: viewModel.state.selectedDhikrID) { _, _ in syncResolvedName() }
        .sheet(isPresented: $showingCountEditor) {
            CountEditorView(currentCount: viewModel.currentCount) { viewModel.setCurrentCount($0) }
        }
    }
    private func syncResolvedName() { viewModel.updateResolvedDisplayName(libraryViewModel.resolved(id: viewModel.state.selectedDhikrID)?.name) }

    private func toggleFastCounting() {
        if fastCountingEnabled {
            exitFastCounting(announce: true)
        } else {
            guard viewModel.settings.fastCountModeEnabled else { return }
            fastCountingEnabled = true
            viewModel.announceFastCountModeChange(isEnabled: true)
        }
    }

    private func exitFastCounting(announce: Bool) {
        guard fastCountingEnabled else { return }
        fastCountingEnabled = false
        if announce {
            viewModel.announceFastCountModeChange(isEnabled: false)
        }
    }

    private var fastCountScreen: some View {
        HizliSayimYuzeyi(
            onCount: { let state = activeDhikrState; viewModel.incrementFast(milestoneInterval: state?.milestoneInterval, soundOverride: state?.soundOverride ?? .inherit, hapticOverride: state?.hapticOverride ?? .inherit) },
            onExit: { exitFastCounting(announce: true) },
            onStatus: viewModel.announceFastCountStatus
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var progressVisualText: String {
        viewModel.countProgressDescription
    }

    /// Mod/aktivasyon gerektirmeyen, her zaman aynı davranan tek bir
    /// yüzey (bkz. 2026-07-15-sayac-sayma-alani-karar-taslagi.md Bölüm 9/10):
    /// - VoiceOver kapalıyken dokunma doğrudan artırır.
    /// - VoiceOver açıkken çift dokunma (`Button` semantiği ile) artırır.
    ///
    /// Yukarı/aşağı kaydırma (`accessibilityAdjustableAction`) KASITLI
    /// OLARAK yok — o, tamamen VoiceOver'ın kendi jest tanıma/dağıtım
    /// hattına bağlıydı; hızlı art arda kaydırmada VoiceOver'ın kendisi
    /// jestleri geç işliyor/dağıtıyor, uygulama kodu bunu düzeltemiyordu
    /// (bkz. Bölüm 8 tanılama bulgusu). Gerçekten hızlı sayım isteyen
    /// kullanıcı için VoiceOver'ı tamamen atlayan Hızlı Sayım (Bölüm 7)
    /// var; bu yüzeyde ayrıca kaydırma eklemek gereksiz karmaşıklık
    /// olurdu (Hızlı Sayım zaten her dokunuşta ilerliyor).
    private var countingSurface: some View {
        Button {
            let state = activeDhikrState
            viewModel.increment(milestoneInterval: state?.milestoneInterval, soundOverride: state?.soundOverride ?? .inherit, hapticOverride: state?.hapticOverride ?? .inherit)
        } label: {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.accentColor.opacity(0.15))
                .frame(minHeight: 220)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(viewModel.accessibilitySpokenValue)
        .accessibilityValue("")
        .accessibilityHint("Bir artırmak için çift dokunun.")
    }
    private var activeDhikrState: DhikrUserState? { libraryViewModel.resolved(id: viewModel.state.selectedDhikrID)?.userState }

    private var actionGrid: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                actionButton("Geri Al", systemImage: "arrow.uturn.backward") {
                    viewModel.undo()
                }
                .disabled(!viewModel.canUndo)
                actionButton("Sıfırla", systemImage: "arrow.counterclockwise") {
                    showingResetConfirmation = true
                }
                .disabled(!viewModel.canReset)
            }
        }
        .alert("Sayaç Sıfırlansın mı?", isPresented: $showingResetConfirmation) {
            Button("İptal", role: .cancel) {}
            Button("Sıfırla", role: .destructive) {
                viewModel.reset()
            }
        } message: {
            Text("Güncel sayım 0'a döner. Bu işlem geri alınamaz.")
        }
    }

    private func actionButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title2)
                Text(title)
                    .font(.footnote)
            }
            .frame(minWidth: 60, minHeight: 60)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}

private struct CountEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    let onSave: (Int) -> Void
    init(currentCount: Int, onSave: @escaping (Int) -> Void) {
        _text = State(initialValue: String(currentCount)); self.onSave = onSave
    }
    var body: some View {
        NavigationStack {
            Form { TextField("Yeni sayı", text: $text).keyboardType(.numberPad).accessibilityLabel("Yeni sayı") }
                .navigationTitle("Sayıyı Ayarla")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Kaydet") { onSave(Int(text) ?? 0); dismiss() }.disabled(Int(text) == nil)
                    }
                }
        }
    }
}

#Preview {
    SayacView(viewModel: CounterViewModel(), libraryViewModel: DhikrLibraryViewModel())
}
