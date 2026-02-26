import SwiftUI
import Combine
import UniformTypeIdentifiers
import Foundation
import Charts

struct SchedulerResultDocument: FileDocument {
    static var readableContentTypes: [UTType] { [UTType.plainText] }
    var result: String
    init(result: String) { self.result = result }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let str = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.result = str
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = result.data(using: .utf8) ?? Data()
        return .init(regularFileWithContents: data)
    }
}
