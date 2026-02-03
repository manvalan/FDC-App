import SwiftUI
import Combine

struct CreditsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // Header with Larger Splash Image
                    VStack {
                        Image("SplashImage")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 400)
                            .shadow(radius: 10)
                        
                        Text("FdC Railway Manager")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .padding(.top, 10)
                    }
                    .padding(.top, 40)
                    
                    VStack(spacing: 15) {
                        Text("developed_by".localized)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Michele Bigi")
                            .font(.title2.bold())
                        
                        Divider()
                            .padding(.horizontal, 60)
                        
                        Text(String(format: "version_label".localized, "1.2.0"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text("project_info_title".localized)
                            .font(.title3.bold())
                        
                        Text("project_description".localized)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineSpacing(5)
                        
                        Text("technologies_used".localized)
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            labelPair(icon: "swift", title: "SwiftUI", description: "reactive_interface".localized)
                            labelPair(icon: "brain.head.profile", title: "RailwayAI", description: "ml_optimization".localized)
                            labelPair(icon: "map.fill", title: "MapKit", description: "geographic_visualization".localized)
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer(minLength: 50)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("close".localized) {
                        dismiss()
                    }
                }
            }
            .navigationTitle("credits".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func labelPair(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 25)
            VStack(alignment: .leading) {
                Text(title).bold()
                Text(description).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    CreditsView()
}
