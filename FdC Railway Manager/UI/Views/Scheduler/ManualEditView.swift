import SwiftUI
import Combine
import UniformTypeIdentifiers
import Foundation
import Charts

struct ManualEditView: View {
    @Binding var schedulerResult: String
    @Environment(\.dismiss) var dismiss
    @State private var editedText: String = ""
    var body: some View {
        VStack(alignment: .leading) {
            Text("manual_edit_title".localized)
                .font(.headline)
                .padding(.top)
            TextEditor(text: $editedText)
                .font(.system(.body, design: .monospaced))
                .border(Color.gray)
                .padding(.vertical)
            HStack {
                Spacer()
                Button("cancel".localized) { dismiss() }
                Button("save".localized) {
                    schedulerResult = editedText
                    dismiss()
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear { editedText = schedulerResult }
    }
}
