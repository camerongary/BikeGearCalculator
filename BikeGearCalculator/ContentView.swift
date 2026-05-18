import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: GearStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            CalculatorView()
                .tag(0)
                .tabItem { Label("Calculator", systemImage: "gearshape.2.fill") }

            PresetsView()
                .tag(1)
                .tabItem { Label("Presets", systemImage: "list.bullet.rectangle") }

            SavedView()
                .tag(2)
                .tabItem { Label("Saved", systemImage: "bookmark.fill") }
        }
    }
}
