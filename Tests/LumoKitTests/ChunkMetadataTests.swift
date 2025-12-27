import Testing
@testable import LumoKit

// MARK: - Chunk Metadata Tests

@Test("Chunk metadata")
func testChunkMetadata() throws {
    let text = "This is a test sentence. Another sentence here."
    let config = try ChunkingConfig(chunkSize: 30, strategy: .sentence)
    let strategy = SentenceChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(!chunks.isEmpty)

    // Check first chunk metadata
    let firstChunk = chunks[0]
    #expect(firstChunk.metadata.index == 0)
    #expect(firstChunk.metadata.startPosition == 0)
    #expect(!firstChunk.metadata.hasOverlapWithPrevious)

    // If there's a second chunk, check its metadata
    if chunks.count > 1 {
        let secondChunk = chunks[1]
        #expect(secondChunk.metadata.index == 1)
        #expect(secondChunk.metadata.startPosition > firstChunk.metadata.startPosition)
    }
}
