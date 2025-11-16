import Testing
@testable import LumoKit

// MARK: - Integration Tests

@Test("LumoKit integration")
func testLumoKitIntegration() async throws {
    // This test requires VecturaKit setup, so we'll test the chunking methods only
    let text = "This is a test. It has multiple sentences. Each sentence is important."

    let config = ChunkingConfig(chunkSize: 30, strategy: .sentence)
    let strategy = SentenceChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(!chunks.isEmpty)

    // Verify chunks can be converted to strings (simulating what LumoKit does)
    let chunkTexts = chunks.map { $0.text }
    #expect(!chunkTexts.isEmpty)
    let totalLength = chunkTexts.joined(separator: " ").count
    #expect(totalLength >= text.count - 20 && totalLength <= text.count + 20, "Length should be approximately correct")
}

@Test("Chunking with special characters")
func testChunkingWithSpecialCharacters() throws {
    let text = "Hello! How are you? I'm fine, thanks. What about you?"
    let config = ChunkingConfig(chunkSize: 25, strategy: .sentence)
    let strategy = SentenceChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(!chunks.isEmpty)
}

@Test("Chunking with unicode characters")
func testChunkingWithUnicodeCharacters() throws {
    let text = "Hello 世界! This is a test. Unicode 文字 support."
    let config = ChunkingConfig(chunkSize: 30, strategy: .sentence)
    let strategy = SentenceChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(!chunks.isEmpty)
}

@Test("Chunking very small chunk size")
func testChunkingVerySmallChunkSize() throws {
    let text = "Short text"
    let config = ChunkingConfig(chunkSize: 5, strategy: .sentence)
    let strategy = SentenceChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(!chunks.isEmpty)
}

@Test("Invalid chunk size")
func testInvalidChunkSize() throws {
    let text = "Some text"
    let config = ChunkingConfig(chunkSize: 0, strategy: .sentence)
    let strategy = SentenceChunker()

    #expect(throws: LumoKitError.invalidChunkSize) {
        try strategy.chunk(text: text, config: config)
    }
}
