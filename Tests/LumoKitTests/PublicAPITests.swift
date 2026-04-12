import Testing
@testable import LumoKit
import VecturaKit
import Foundation

// MARK: - Public API Tests

private actor MockEmbedder: VecturaEmbedder {
    let dimension: Int = 2

    func embed(texts: [String]) async throws -> [[Float]] {
        texts.map(embedding(for:))
    }

    private func embedding(for text: String) -> [Float] {
        let normalized = text.lowercased()
        if normalized.contains("team") || normalized.contains("roadmap") || normalized.contains("q3") {
            return [1, 0]
        }
        return [0, 1]
    }
}

@Test("LumoKit public API")
func testLumoKitPublicAPI() async throws {
    let config = try VecturaConfig(name: "test-db")
    let lumoKit = try await LumoKit(config: config)

    let text = """
    This is a test document with multiple sentences. It should be chunked properly.

    Here's a second paragraph that adds more content for testing. The chunking should respect paragraph boundaries.
    """

    let chunkingConfig = try ChunkingConfig(
        chunkSize: 100,
        overlapPercentage: 0.15,
        strategy: .semantic,
        contentType: .prose
    )

    // Test chunkText (now returns Chunk objects with metadata)
    let chunks = try lumoKit.chunkText(text, config: chunkingConfig)
    #expect(!chunks.isEmpty, "Should produce chunks from text")
    #expect(chunks.count > 0, "Should have at least one chunk")

    // Verify metadata
    for (index, chunk) in chunks.enumerated() {
        #expect(chunk.metadata.index == index, "Chunk index should match")
        #expect(chunk.metadata.contentType == .prose, "Content type should be prose")
        #expect(chunk.metadata.endPosition >= chunk.metadata.startPosition)
        #expect(!chunk.text.isEmpty, "Chunk text should not be empty")
    }

    // Cleanup
    try await lumoKit.resetDB()
}

@Test("LumoKit supports custom embedding model selection")
func testLumoKitCustomModelSource() async throws {
    let storageDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumo-custom-model-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: storageDirectory)
    }

    let config = try VecturaConfig(
        name: "test-db-custom-model",
        directoryURL: storageDirectory,
        dimension: 64
    )
    let lumoKit = try await LumoKit(
        config: config,
        modelSource: .id("minishlab/potion-base-2M")
    )

    let ids = try await lumoKit.addDocuments(texts: [
        "Milk, eggs, and bread from the grocery store.",
        "The team discussed the product roadmap and Q3 priorities."
    ])

    #expect(ids.count == 2, "Should index documents with the selected embedding model")

    let results = try await lumoKit.semanticSearch(
        query: "What did the team discuss?",
        numResults: 1,
        threshold: 0.0
    )
    #expect(!results.isEmpty, "Should return search results when using a custom model source")

    try await lumoKit.resetDB()
}

@Test("LumoKit supports custom embedder injection")
func testLumoKitCustomEmbedder() async throws {
    let storageDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumo-custom-embedder-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: storageDirectory)
    }

    let config = try VecturaConfig(
        name: "test-db-custom-embedder",
        directoryURL: storageDirectory,
        dimension: 2
    )
    let lumoKit = try await LumoKit(
        config: config,
        embedder: MockEmbedder()
    )

    let ids = try await lumoKit.addDocuments(texts: [
        "Milk, eggs, and bread from the grocery store.",
        "The team discussed the product roadmap and Q3 priorities."
    ])

    #expect(ids.count == 2, "Should index documents with a custom embedder")

    let results = try await lumoKit.semanticSearch(
        query: "What did the team discuss?",
        numResults: 1,
        threshold: 0.0
    )

    #expect(results.count == 1, "Should return a top match for the custom embedder")
    #expect(
        results.first?.text == "The team discussed the product roadmap and Q3 priorities.",
        "Should surface the document preferred by the custom embedder"
    )

    try await lumoKit.resetDB()
}

@Test("LumoKit source metadata")
func testLumoKitSourceMetadata() async throws {
    let config = try VecturaConfig(name: "test-db-source")
    let lumoKit = try await LumoKit(config: config)

    // Create a temporary file
    let tempDir = FileManager.default.temporaryDirectory
    let testFile = tempDir.appendingPathComponent("test-document.txt")
    let testContent = "This is a test document. It has multiple sentences. For testing source metadata."

    try testContent.write(to: testFile, atomically: true, encoding: .utf8)
    defer {
        try? FileManager.default.removeItem(at: testFile)
    }

    let chunks = try await lumoKit.parseDocument(from: testFile)

    #expect(!chunks.isEmpty, "Should produce chunks")

    // Verify all chunks have source metadata populated
    for chunk in chunks {
        #expect(chunk.metadata.source == "test-document.txt", "Source should be the filename")
    }

    // Cleanup
    try await lumoKit.resetDB()
}

@Test("LumoKit search parameter validation")
func testLumoKitSearchParameterValidation() async throws {
    let config = try VecturaConfig(name: "test-db-search-validation")
    let lumoKit = try await LumoKit(config: config)

    // Add some documents for testing
    let tempDir = FileManager.default.temporaryDirectory
    let testFile = tempDir.appendingPathComponent("test-search.txt")
    let testContent = "This is a test document for search validation."

    try testContent.write(to: testFile, atomically: true, encoding: .utf8)
    defer {
        try? FileManager.default.removeItem(at: testFile)
    }

    _ = try await lumoKit.parseAndIndex(url: testFile)

    // Test invalid numResults (zero)
    do {
        _ = try await lumoKit.semanticSearch(query: "test", numResults: 0)
        #expect(Bool(false), "Should throw invalidSearchParameters")
    } catch LumoKitError.invalidSearchParameters {
        // Expected
    }

    // Test invalid numResults (negative)
    do {
        _ = try await lumoKit.semanticSearch(query: "test", numResults: -1)
        #expect(Bool(false), "Should throw invalidSearchParameters")
    } catch LumoKitError.invalidSearchParameters {
        // Expected
    }

    // Test invalid threshold (too high)
    do {
        _ = try await lumoKit.semanticSearch(query: "test", threshold: 1.5)
        #expect(Bool(false), "Should throw invalidSearchParameters")
    } catch LumoKitError.invalidSearchParameters {
        // Expected
    }

    // Test invalid threshold (negative)
    do {
        _ = try await lumoKit.semanticSearch(query: "test", threshold: -0.1)
        #expect(Bool(false), "Should throw invalidSearchParameters")
    } catch LumoKitError.invalidSearchParameters {
        // Expected
    }

    // Test valid parameters (should work)
    let results = try await lumoKit.semanticSearch(query: "test", numResults: 5, threshold: 0.7)
    #expect(results.count >= 0, "Should return results or empty array")

    // Cleanup
    try await lumoKit.resetDB()
}

@Test("LumoKit strategy factory")
func testLumoKitStrategyFactory() {
    let sentenceStrategy = ChunkingStrategyFactory.strategy(for: .sentence)
    #expect(sentenceStrategy is SentenceChunker)

    let paragraphStrategy = ChunkingStrategyFactory.strategy(for: .paragraph)
    #expect(paragraphStrategy is ParagraphChunker)

    let semanticStrategy = ChunkingStrategyFactory.strategy(for: .semantic)
    #expect(semanticStrategy is SemanticChunker)
}

@Test("LumoKit parseDocument URL validation")
func testLumoKitParseDocumentURLValidation() async throws {
    let config = try VecturaConfig(name: "test-db-parse-url-validation")
    let lumoKit = try await LumoKit(config: config)

    let nonFileURL = URL(string: "https://example.com/test.txt")!
    await #expect(throws: LumoKitError.invalidURL) {
        _ = try await lumoKit.parseDocument(from: nonFileURL)
    }
}

@Test("LumoKit parseAndIndex URL validation")
func testLumoKitParseAndIndexURLValidation() async throws {
    let config = try VecturaConfig(name: "test-db-index-url-validation")
    let lumoKit = try await LumoKit(config: config)

    let nonFileURL = URL(string: "https://example.com/test.txt")!
    await #expect(throws: LumoKitError.invalidURL) {
        _ = try await lumoKit.parseAndIndex(url: nonFileURL)
    }
}

@Test("LumoKit file not found validation")
func testLumoKitFileNotFoundValidation() async throws {
    let config = try VecturaConfig(name: "test-db-file-not-found")
    let lumoKit = try await LumoKit(config: config)

    let missingURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumo-missing-\(UUID().uuidString).txt")

    await #expect(throws: LumoKitError.fileNotFound) {
        _ = try await lumoKit.parseDocument(from: missingURL)
    }

    await #expect(throws: LumoKitError.fileNotFound) {
        _ = try await lumoKit.parseAndIndex(url: missingURL)
    }
}

@Test("LumoKit empty file handling")
func testLumoKitEmptyFileHandling() async throws {
    let config = try VecturaConfig(name: "test-db-empty-file")
    let lumoKit = try await LumoKit(config: config)

    let tempDir = FileManager.default.temporaryDirectory
    let emptyFile = tempDir.appendingPathComponent("lumo-empty-\(UUID().uuidString).txt")
    try "".write(to: emptyFile, atomically: true, encoding: .utf8)
    defer {
        try? FileManager.default.removeItem(at: emptyFile)
    }

    await #expect(throws: LumoKitError.emptyDocument) {
        _ = try await lumoKit.parseDocument(from: emptyFile)
    }

    await #expect(throws: LumoKitError.emptyDocument) {
        _ = try await lumoKit.parseAndIndex(url: emptyFile)
    }
}
