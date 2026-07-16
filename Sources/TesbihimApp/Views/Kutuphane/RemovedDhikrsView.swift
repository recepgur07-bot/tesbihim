import SwiftUI

struct RemovedDhikrsView: View {
    var viewModel: DhikrLibraryViewModel
    @State private var pendingDelete: ResolvedDhikr?
    var body: some View { List {
        ForEach(viewModel.removedDhikrs) { item in
            VStack(alignment: .leading) {
                Text(item.name)
                if let days = viewModel.remainingDays(for: item) { Text("\(days) gün sonra kalıcı silinecek").font(.caption).foregroundStyle(.secondary) }
                Button("Geri Getir") { viewModel.restore(id: item.id) }
                if item.origin == .bundled { Button("Varsayılana Sıfırla ve Geri Getir") { viewModel.resetAndRestore(id: item.id) } }
                else { Button("Kalıcı Olarak Sil", role: .destructive) { pendingDelete = item } }
            }
        }
    }.navigationTitle("Kaldırılanlar")
      .overlay { if viewModel.removedDhikrs.isEmpty { ContentUnavailableView("Kaldırılan zikir yok", systemImage: "tray") } }
      .alert("Kalıcı Olarak Sil", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
          Button("İptal", role: .cancel) { pendingDelete = nil }; Button("Kalıcı Olarak Sil", role: .destructive) { if let id = pendingDelete?.id { viewModel.permanentlyDelete(id: id) }; pendingDelete = nil }
      } message: { Text("Bu özel zikir kalıcı olarak silinecek. Geçmiş kayıtlarınız etkilenmeyecek. Bu işlem geri alınamaz.") }
    }
}
