import PerfLens
import SwiftUI

@main
struct PerfLensDemoApp: App {

    init() {
        PerfLens.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
