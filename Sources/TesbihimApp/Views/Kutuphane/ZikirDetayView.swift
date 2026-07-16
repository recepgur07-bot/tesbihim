import SwiftUI
import UIKit

/// Zikir Detayı ekranı — bkz. PLAN.md Bölüm 7.2. Tam Arapça + Türkçe
/// okunuş + anlam + kaynak/sürüm bilgisi + hedef ayarlayıcı; "Bu Zikri
/// Seç" onayı Sayaç ekranına döner ve odağı başlığa taşır.
struct ZikirDetayView: View {
    let dhikrID: String
    var viewModel: CounterViewModel
    var libraryViewModel: DhikrLibraryViewModel
    @Binding var path: NavigationPath

    @State private var target: Int

    init(dhikrID: String, viewModel: CounterViewModel, libraryViewModel: DhikrLibraryViewModel, path: Binding<NavigationPath>) {
        self.dhikrID = dhikrID
        self.viewModel = viewModel
        self.libraryViewModel = libraryViewModel
        self._path = path
        _target = State(initialValue: libraryViewModel.resolved(id: dhikrID)?.defaultTarget ?? DhikrLibrary.definition(for: dhikrID)?.defaultTarget ?? 0)
    }

    private var dhikr: ResolvedDhikr {
        libraryViewModel.resolved(id: dhikrID) ?? ResolvedDhikr.resolve(.freeCounter, state: nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let arabic = dhikr.arabicText, !arabic.isEmpty {
                    Text(arabic)
                        .font(.title2)
                        .lineSpacing(12)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .environment(\.locale, Locale(identifier: "ar"))
                }

                Text(dhikr.name)
                    .font(.title3.weight(.semibold))
                    .environment(\.locale, Locale(identifier: "tr"))

                if let meaning = dhikr.meaning, !meaning.isEmpty {
                    Text(meaning)
                        .font(.body)
                        .environment(\.locale, Locale(identifier: "tr"))
                }

                targetStepper

                if let source = dhikr.source, !source.isEmpty {
                    Text("Kaynak: \(source)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Bu Zikri Seç") {
                    confirmSelection()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, minHeight: 60)
            }
            .padding()
        }
        .navigationTitle(dhikr.name)
        .onAppear {
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }

    private var targetStepper: some View {
        HStack {
            Text("Hedef")
            Spacer()
            Text(targetDisplayText)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hedef")
        .accessibilityValue(targetDisplayText)
        .accessibilityHint("Değiştirmek için yukarı veya aşağı kaydırın.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                if target >= 9999 {
                    UIAccessibility.post(notification: .announcement, argument: "En yüksek değer")
                } else {
                    target += 1
                }
            case .decrement:
                if target <= 0 {
                    UIAccessibility.post(notification: .announcement, argument: "En düşük değer")
                } else {
                    target -= 1
                }
            @unknown default:
                break
            }
        }
    }

    private var targetDisplayText: String {
        target == 0 ? "Hedefsiz" : "\(target)"
    }

    private func confirmSelection() {
        viewModel.selectDhikr(id: dhikr.id, target: target == 0 ? nil : target)
        viewModel.updateResolvedDisplayName(dhikr.name)
        path = NavigationPath()
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }
}

#Preview {
    NavigationStack {
        ZikirDetayView(dhikrID: "subhanallah", viewModel: CounterViewModel(), libraryViewModel: DhikrLibraryViewModel(), path: .constant(NavigationPath()))
    }
}
