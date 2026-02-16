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
                    .onAppear {
                        print("🚀 APP AVVIATA - TEST CONSOLE OK 🚀")
                        // Keep splash for at least 2.5 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation {
                                showSplash = false
                            }
                        }
                    }
                    .task {
                        await loader.performInitialLoad()
                    }
            } else {
                ContentView()
                    .environmentObject(appState)
                    .environmentObject(appState.railroad.network)
                    .environmentObject(appState.railroad.lines)
                    .environmentObject(loader)
                    .task {
                        // Periodic autosave every 30 seconds
                        while true {
                            try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)
                            await loader.saveCurrentState()
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
