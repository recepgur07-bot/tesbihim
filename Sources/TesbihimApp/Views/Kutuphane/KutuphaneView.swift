import SwiftUI
import UIKit

struct DhikrLibraryRowPresentation: Equatable {
    let showsSelectionIndicator: Bool
    let accessibilityValue: String
    init(dhikrID: String, selectedDhikrID: String) {
        showsSelectionIndicator = dhikrID == selectedDhikrID
        accessibilityValue = showsSelectionIndicator ? "Seçili" : ""
    }
}

struct KutuphaneView: View {
    var viewModel: CounterViewModel
    var libraryViewModel: DhikrLibraryViewModel
    @Binding var path: NavigationPath
    @State private var editing: ResolvedDhikr?
    @State private var showingNew = false
    @State private var pendingRemoval: ResolvedDhikr?

    var body: some View {
        List {
            Section { row(for: ResolvedDhikr.resolve(.freeCounter, state: nil)) }
            ForEach([DhikrCategory.tesbihat, .salavat, .istigfar, .diger]) { category in
                let values = libraryViewModel.activeDhikrs.filter { $0.category == category }
                if !values.isEmpty { Section(category.title) { ForEach(values) { row(for: $0) } } }
            }
            Section {
                NavigationLink("Kaldırılanlar") { RemovedDhikrsView(viewModel: libraryViewModel) }
                    .accessibilityHint("Kaldırılan zikirleri yönetmek için çift dokunun.")
            }
        }
        .navigationTitle("Zikirler")
        .toolbar { Button("Zikir Ekle", systemImage: "plus") { showingNew = true }.accessibilityHint("Yeni bir özel zikir oluşturur.") }
        .sheet(isPresented: $showingNew) { DhikrEditView(viewModel: libraryViewModel, dhikr: nil) }
        .sheet(item: $editing) { DhikrEditView(viewModel: libraryViewModel, dhikr: $0) }
        .alert("Zikir Kütüphanesi'nden Kaldır", isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } })) {
            Button("İptal", role: .cancel) { pendingRemoval = nil }
            Button("Kaldır", role: .destructive) { if let item = pendingRemoval { libraryViewModel.remove(id: item.id); UIAccessibility.post(notification: .layoutChanged, argument: nil) }; pendingRemoval = nil }
        } message: { Text("\(pendingRemoval?.name ?? "Bu zikir"), Zikir Kütüphanesi'nden kaldırılacak. Kaldırılanlar bölümünden geri getirebilirsiniz.") }
    }

    private func row(for dhikr: ResolvedDhikr) -> some View {
        let presentation = DhikrLibraryRowPresentation(dhikrID: dhikr.id, selectedDhikrID: viewModel.state.selectedDhikrID)
        return HStack {
            NavigationLink(value: SayacRoute.dhikrDetail(dhikr.id)) {
                VStack(alignment: .leading) { Text(dhikr.name); Text(dhikr.defaultTarget.map { "Hedef: \($0)" } ?? "Hedefsiz").font(.caption).foregroundStyle(.secondary) }
            }
            if presentation.showsSelectionIndicator {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint).accessibilityHidden(true)
            }
            Menu { Button("Düzenle") { editing = dhikr }; Button("Kaldır", role: .destructive) { pendingRemoval = dhikr } } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("Diğer İşlemler, \(dhikr.name)")
        }
        .accessibilityValue(presentation.accessibilityValue)
        .accessibilityAction(named: "Düzenle") { editing = dhikr }
        .accessibilityAction(named: "Kaldır") { pendingRemoval = dhikr }
    }
}

#Preview { NavigationStack { KutuphaneView(viewModel: CounterViewModel(), libraryViewModel: DhikrLibraryViewModel(), path: .constant(.init())) } }
