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
    let config = try ChunkingConfig(chunkSize: 100, strategy: .paragraph)
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
    let config = try ChunkingConfig(
        chunkSize: 30,
        overlapPercentage: 0.15,
        strategy: .paragraph
    )
    let strategy = ParagraphChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(chunks.count > 1, "Should produce multiple chunks")
}

@Test("Paragraph chunker oversized paragraph does not emit oversized chunk")
func testParagraphChunkerOversizedParagraphDoesNotEmitOversizedChunk() throws {
    let longParagraph = """
    This is sentence one and it is a bit longer than usual. This is sentence two with some extra words.
    This is sentence three that keeps the paragraph length high.
    """
    let text = """
    \(longParagraph)

    This is a short paragraph.
    """
    let config = try ChunkingConfig(chunkSize: 60, overlapPercentage: 0.0, strategy: .paragraph)
    let strategy = ParagraphChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(!chunks.isEmpty, "Should produce chunks")
    for chunk in chunks {
        #expect(chunk.text.count <= config.chunkSize, "Chunk should not exceed configured size")
    }
}

@Test("Paragraph chunker oversized paragraph applies sentence overlap")
func testParagraphChunkerOversizedParagraphOverlapUsesSentenceReuse() throws {
    let sentence1 = "Short one."
    let sentence2 = "Alpha beta."
    let sentence3 = "This sentence makes it long."
    let longParagraph = "\(sentence1) \(sentence2) \(sentence3)"

    let config = try ChunkingConfig(chunkSize: 40, overlapPercentage: 0.5, strategy: .paragraph)
    let strategy = ParagraphChunker()

    let chunks = try strategy.chunk(text: longParagraph, config: config)

    #expect(chunks.count > 1, "Should produce multiple chunks")
    #expect(chunks[0].text.contains(sentence2), "First chunk should include sentence two")
    #expect(chunks[1].text.contains(sentence2), "Second chunk should include overlapped sentence two")
    for chunk in chunks {
        #expect(
            chunk.text.count <= config.chunkSize,
            """
            Chunk should not exceed configured size. Text: '\(chunk.text)', Size: \(chunk.text.count), Max: \(config.chunkSize)
            """
        )
    }
}
