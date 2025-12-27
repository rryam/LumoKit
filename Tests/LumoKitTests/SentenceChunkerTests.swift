import Testing
@testable import LumoKit

// MARK: - Sentence Chunker Tests

@Test("Sentence chunker basic")
func testSentenceChunkerBasic() throws {
    let text = "This is the first sentence. This is the second sentence. And here is the third sentence."
    let config = try ChunkingConfig(chunkSize: 50, strategy: .sentence)
    let strategy = SentenceChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(!chunks.isEmpty, "Should produce chunks")
    // Verify that sentences aren't split mid-sentence
    for chunk in chunks {
        #expect(chunk.text.hasSuffix(".") || chunk.text.contains("."), "Chunks should contain complete sentences")
    }
}

@Test("Sentence chunker with overlap")
func testSentenceChunkerWithOverlap() throws {
    let text = "First sentence here. Second sentence here. Third sentence here. Fourth sentence here."
    let config = try ChunkingConfig(
        chunkSize: 40,
        overlapPercentage: 0.2,
        strategy: .sentence
    )
    let strategy = SentenceChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(chunks.count > 1, "Should produce multiple chunks")
    // Check that overlap metadata is set correctly
    if chunks.count > 1 {
        #expect(chunks[1].metadata.hasOverlapWithPrevious, "Second chunk should have overlap")
    }
}

@Test("Sentence chunker long sentence")
func testSentenceChunkerLongSentence() throws {
    let longSentence = String(repeating: "word ", count: 100) + "."
    let config = try ChunkingConfig(chunkSize: 50, strategy: .sentence)
    let strategy = SentenceChunker()

    let chunks = try strategy.chunk(text: longSentence, config: config)

    #expect(!chunks.isEmpty, "Should handle long sentences by splitting them")
}
