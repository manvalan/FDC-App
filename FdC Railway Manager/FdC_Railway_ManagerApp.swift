import SwiftUI

@main
struct FdC_Railway_ManagerApp: App {
    @StateObject private var network: RailwayNetwork
    @StateObject private var trainManager: TrainManager
    @StateObject private var appState: AppState
    @StateObject private var loader: AppLoaderService

    init() {
        let n = RailwayNetwork(name: "FdC Demo")
        let t = TrainManager()
        let a = AppState()
        _network = StateObject(wrappedValue: n)
        _trainManager = StateObject(wrappedValue: t)
        _appState = StateObject(wrappedValue: a)
        _loader = StateObject(wrappedValue: AppLoaderService(network: n, trainManager: t, appState: a))
    }

    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
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
                    .environmentObject(network)
                    .environmentObject(trainManager)
                    .environmentObject(appState)
            }
        }
    }
}

struct SplashScreen: View {
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all) // Background color
            VStack {
                Image("SplashImage") // Name of the asset
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 500)
                Text("FdC Railway Manager")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .bold()
                    .padding(.top, 20)
            }
        }
    }
}
