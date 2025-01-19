import PicoDocs
import VecturaKit
import Foundation

public final class LumoKit {
    private let vectura: VecturaKit

    public init(config: VecturaConfig) throws {
        self.vectura = try VecturaKit(config: config)
    }

    /// Parse and index a document from a given file URL
    public func parseAndIndex(url: URL, chunkSize: Int = 500) async throws {
        let parsedSections = try await parseDocument(from: url, chunkSize: chunkSize)

        guard !parsedSections.isEmpty else {
            print("No valid content to index from document.")
            return
        }
        _ = try await vectura.addDocuments(texts: parsedSections)
    }

    /// Parse a document from a file and return its content in chunks
    public func parseDocument(from url: URL, chunkSize: Int = 500) async throws -> [String] {
        let doc = await PicoDocument(url: url)
        await doc.fetch()
        await doc.parse(to: .markdown)

        guard let fullContent = await doc.exportedContent?.joined(separator: "\n") else {
            throw NSError(domain: "LumoKitError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Document content is empty or invalid."])
        }

        return chunkText(fullContent, size: chunkSize)
    }

    /// Split text into smaller chunks
    private func chunkText(_ text: String, size: Int) -> [String] {
        let words = text.split(separator: " ")
        var chunks: [String] = []
        var currentChunk: [Substring] = []
        var currentSize = 0

        for word in words {
            if currentSize + word.count + 1 > size {
                chunks.append(currentChunk.joined(separator: " "))
                currentChunk = []
                currentSize = 0
            }
            currentChunk.append(word)
            currentSize += word.count + 1
        }
        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: " "))
        }
        return chunks
    }

    /// Search for relevant documents in the vector database
    public func semanticSearch(query: String, numResults: Int = 5, threshold: Float = 0.7) async throws -> [VecturaSearchResult] {
        try await vectura.search(query: query, numResults: numResults, threshold: threshold)
    }

    /// Reset the vector database
    public func resetDB() async throws {
        try await vectura.reset()
    }
}
