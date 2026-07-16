import SwiftUI

/// Sayaç → Zikir Kütüphanesi → Zikir Detayı akışı iki farklı yerden
/// (Sayaç ekranındaki zikir adı ve "Zikirler" sekmesi) aynı ekranlara push
/// yapabilsin diye ortak bir rota tanımı — bkz. PLAN.md Bölüm 7.1, 7.2.
enum SayacRoute: Hashable {
    case library
    case dhikrDetail(String)
}

extension View {
    func sayacRouteDestinations(viewModel: CounterViewModel, libraryViewModel: DhikrLibraryViewModel, path: Binding<NavigationPath>) -> some View {
        navigationDestination(for: SayacRoute.self) { route in
            switch route {
            case .library:
                KutuphaneView(viewModel: viewModel, libraryViewModel: libraryViewModel, path: path)
            case .dhikrDetail(let id):
                ZikirDetayView(dhikrID: id, viewModel: viewModel, libraryViewModel: libraryViewModel, path: path)
            }
        }
    }
}
