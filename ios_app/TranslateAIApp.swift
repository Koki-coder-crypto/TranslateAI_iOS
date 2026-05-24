import SwiftUI

@main
struct TranslateAIApp: App {
    @StateObject private var store = StoreManager()
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(store) }
    }
}
