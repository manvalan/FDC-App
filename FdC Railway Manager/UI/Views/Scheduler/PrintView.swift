import SwiftUI
import Combine
import UniformTypeIdentifiers
import Foundation
import Charts

struct PrintView: View {
    let text: String
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .leading) {
            Text("print_preview_title".localized)
                .font(.headline)
                .padding(.top)
            ScrollView {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            HStack {
                Spacer()
                Button("close".localized) { dismiss() }
                Button("print".localized) {
                    printText(text)
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    func printText(_ text: String) {
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "print_job_scheduler".localized
        printController.printInfo = printInfo
        let formatter = UISimpleTextPrintFormatter(text: text)
        printController.printFormatter = formatter
        printController.present(animated: true, completionHandler: nil)
    }
}
