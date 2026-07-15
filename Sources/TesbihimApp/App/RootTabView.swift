import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            SayacView()
                .tabItem { Label("Sayaç", systemImage: "circle.circle") }

            KutuphaneView()
                .tabItem { Label("Zikirler", systemImage: "book") }

            GecmisView()
                .tabItem { Label("Geçmiş", systemImage: "clock") }

            AyarlarView()
                .tabItem { Label("Ayarlar", systemImage: "gearshape") }
        }
    }
}

#Preview {
    RootTabView()
}
