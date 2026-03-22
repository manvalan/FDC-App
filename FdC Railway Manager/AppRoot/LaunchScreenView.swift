import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            Image("LaunchImage")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    LaunchScreenView()
}
