import SwiftUI
import Combine
import UniformTypeIdentifiers
import Foundation
import Charts

struct FDCFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.fdc, .plainText] }
    var content: String
    init(content: String = "") {
        self.content = content
    }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let str = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.content = str
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8) ?? Data()
        return .init(regularFileWithContents: data)
    }
}
