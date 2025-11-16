import Testing
@testable import LumoKit
import VecturaKit
import Foundation

// MARK: - Public API Tests

@Test("LumoKit public API")
func testLumoKitPublicAPI() async throws {
    let config = try VecturaConfig(name: "test-db")
    let lumoKit = try await LumoKit(config: config)

    let text = """
    This is a test document with multiple sentences. It should be chunked properly.

    Here's a second paragraph that adds more content for testing. The chunking should respect paragraph boundaries.
    """

    let chunkingConfig = ChunkingConfig(
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

    try await lumoKit.parseAndIndex(url: testFile)

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
