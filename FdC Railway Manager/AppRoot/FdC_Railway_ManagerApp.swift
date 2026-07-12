import SwiftUI
import Combine

@main
struct FdC_Railway_ManagerApp: App {
    @StateObject private var appState: AppState
    @StateObject private var loader: AppLoaderService

    init() {
        let a = AppState()
        _appState = StateObject(wrappedValue: a)
        _loader = StateObject(wrappedValue: AppLoaderService(appState: a))
    }

    @State private var showSplash = true

    var body: some Scene {
        WindowGroup("RailWay Manager") {
            if showSplash {
                SplashScreen()
                    .task {
                        print("🚀 APP AVVIATA - TEST CONSOLE OK 🚀")
                        let started = Date()
                        loader.performInitialLoad()
                        let remaining = max(0, 2.5 - Date().timeIntervalSince(started))
                        try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                        withAnimation {
                            showSplash = false
                        }
                    }
            } else {
                ContentView()
                    .environmentObject(appState)
                    .environmentObject(appState.railroad.network)
                    .environmentObject(appState.railroad.lines)
                    .environmentObject(loader)
                    .environmentObject(appState.aiService)
                    .task {
                        // Periodic autosave every 30 seconds
                        while true {
                            try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)
                            loader.saveCurrentState()
                        }
                    }
            }
        }
    }
}

struct SplashScreen: View {
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all) // Background color
            VStack {
                Image(systemName: "train.side.front.car")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200)
                    .foregroundColor(.white)
                Text("Railway Manager")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .bold()
                    .padding(.top, 20)
            }
        }
    }
}
