import SwiftUI

@main
struct BikeGearCalculatorApp: App {
    @StateObject private var store = GearStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
