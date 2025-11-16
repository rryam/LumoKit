import Testing
@testable import LumoKit

// MARK: - Paragraph Chunker Tests

@Test("Paragraph chunker basic")
func testParagraphChunkerBasic() throws {
    let text = """
    This is the first paragraph. It has multiple sentences.

    This is the second paragraph. It also has sentences.

    And here is the third paragraph.
    """
    let config = ChunkingConfig(chunkSize: 100, strategy: .paragraph)
    let strategy = ParagraphChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(!chunks.isEmpty, "Should produce chunks")
    // Paragraphs should be respected
    for chunk in chunks {
        #expect(!chunk.text.isEmpty)
    }
}

@Test("Paragraph chunker with overlap")
func testParagraphChunkerWithOverlap() throws {
    let text = """
    First paragraph.

    Second paragraph.

    Third paragraph.
    """
    let config = ChunkingConfig(
        chunkSize: 30,
        overlapPercentage: 0.15,
        strategy: .paragraph
    )
    let strategy = ParagraphChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(chunks.count > 1, "Should produce multiple chunks")
}
