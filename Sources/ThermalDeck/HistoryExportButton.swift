import SwiftUI
import ThermalCore
import UniformTypeIdentifiers

struct HistoryExportButton: View {
    let model: AppModel
    @State private var document: ExportDocument?
    @State private var type = UTType.commaSeparatedText
    @State private var exporting = false
    @State private var preparing = false
    @State private var error = false

    var body: some View {
        Menu {
            Button("CSV") { prepare(.csv) }
            Button("JSON") { prepare(.json) }
        } label: {
            Label("Export…", systemImage: "square.and.arrow.up")
        }
        .fixedSize()
        .disabled(preparing || model.history.records.allSatisfy { $0.values.isEmpty })
        .fileExporter(isPresented: $exporting, document: document, contentType: type,
                      defaultFilename: model.snapshot.simulated ? "ThermalDeck-Simulation" : "ThermalDeck-History") { result in
            if case .failure = result { error = true }
        }
        .alert("History could not be exported", isPresented: $error) {
            Button("OK", role: .cancel) {}
        }
    }

    private func prepare(_ format: HistoryExport.Format) {
        let records = model.history.records
        let simulated = model.snapshot.simulated
        preparing = true
        Task {
            defer { preparing = false }
            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    try HistoryExport.encode(records, simulated: simulated, format: format)
                }.value
                type = format == .csv ? .commaSeparatedText : .json
                document = ExportDocument(data: data)
                exporting = true
            } catch {
                self.error = true
            }
        }
    }
}

private struct ExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.commaSeparatedText, .json]
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
