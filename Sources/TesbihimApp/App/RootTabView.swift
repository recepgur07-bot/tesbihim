import SwiftUI

struct RootTabView: View {
    @State private var viewModel: CounterViewModel
    @State private var libraryViewModel = DhikrLibraryViewModel()
    @State private var libraryPath = NavigationPath()
    @State private var selectedTab = 0

    init() {
        let defaults = UserDefaults.standard
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Tesbihim", isDirectory: true)
        let repository = CounterHistoryRepository(
            directoryURL: directory,
            legacyCounterData: defaults.data(forKey: "tesbihim.counterState"),
            legacyHistoryData: defaults.data(forKey: "tesbihim.historyEntries")
        )
        _viewModel = State(initialValue: CounterViewModel(snapshotRepository: repository))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SayacView(viewModel: viewModel, libraryViewModel: libraryViewModel)
                .tabItem { Label("Zikirmatik", systemImage: "circle.circle") }
                .tag(0)

            NavigationStack(path: $libraryPath) {
                KutuphaneView(viewModel: viewModel, libraryViewModel: libraryViewModel, path: $libraryPath)
                    .sayacRouteDestinations(viewModel: viewModel, libraryViewModel: libraryViewModel, path: $libraryPath)
            }
            .tabItem { Label("Zikirler", systemImage: "book") }
            .tag(1)

            GecmisView(counterViewModel: viewModel)
                .tabItem { Label("Geçmiş", systemImage: "clock") }
                .tag(2)

            AyarlarView(counterViewModel: viewModel)
                .tabItem { Label("Ayarlar", systemImage: "gearshape") }
                .tag(3)
        }
        .preferredColorScheme(colorScheme(for: viewModel.settings.theme))
        .task { await viewModel.reloadUnifiedSnapshot() }
        .onReceive(NotificationCenter.default.publisher(for: .tesbihimReminderOpened)) { notification in
            let id = notification.object as? String
            switch NotificationDeepLinkRouter.destination(dhikrID: id, activeIDs: Set(libraryViewModel.activeDhikrs.map(\.id))) {
            case .counter(let id):
                if let dhikr = libraryViewModel.resolved(id: id) { viewModel.selectDhikr(id: id, target: dhikr.defaultTarget) }
                selectedTab = 0
            case .library: selectedTab = 1; libraryPath = NavigationPath()
            }
        }
    }

    private func colorScheme(for theme: UserSettings.Theme) -> ColorScheme? {
        switch theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

#Preview {
    RootTabView()
}
