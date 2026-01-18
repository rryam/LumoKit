import Testing
@testable import LumoKit

// MARK: - Semantic Markdown Chunker Tests

@Test("Markdown oversized section is chunked without duplication")
func testMarkdownOversizedSectionChunking() throws {
    let repeatedSentence = "This is a long sentence for markdown chunking."
    let longBody = Array(repeating: repeatedSentence, count: 40).joined(separator: " ")
    let text = """
    # Header
    \(longBody)
    """

    let config = try ChunkingConfig(chunkSize: 120, strategy: .semantic, contentType: .markdown)
    let strategy = SemanticMarkdownChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(!chunks.isEmpty, "Should produce chunks for oversized markdown sections")
    for chunk in chunks {
        #expect(chunk.text.count <= config.chunkSize, "Chunk should not exceed configured size")
    }

    // Ensure the oversized section was not duplicated in the output.
    let combinedText = chunks.map { $0.text }.joined(separator: " ")
    let occurrences = combinedText.components(separatedBy: repeatedSentence).count - 1
    #expect(occurrences == 40, "Oversized section should not be duplicated")
}
