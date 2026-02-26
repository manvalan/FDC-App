import SwiftUI
import UIKit

struct MetricView: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(.secondary)
            Text(value).font(.system(.subheadline, design: .rounded).bold())
        }
    }
}
