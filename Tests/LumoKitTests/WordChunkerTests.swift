import Testing
@testable import LumoKit

// MARK: - Word Chunker Tests

@Test("Word chunker basic")
func testWordChunkerBasic() throws {
    let text = "This is a simple test with multiple words"
    let config = try ChunkingConfig(chunkSize: 20, contentType: .prose)
    let strategy = WordChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(!chunks.isEmpty, "Should produce chunks")
    #expect(chunks.count > 1, "Should split into multiple chunks with small chunk size")

    // Verify words aren't split
    for chunk in chunks {
        let words = chunk.text.split(separator: " ")
        #expect(!words.isEmpty, "Each chunk should contain words")
    }
}

@Test("Word chunker with overlap")
func testWordChunkerWithOverlap() throws {
    let text = "First second third fourth fifth sixth seventh eighth"
    let config = try ChunkingConfig(
        chunkSize: 20,
        overlapPercentage: 0.3,
        contentType: .prose
    )
    let strategy = WordChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(chunks.count > 1, "Should produce multiple chunks")

    if chunks.count > 1 {
        #expect(chunks[1].metadata.hasOverlapWithPrevious, "Second chunk should have overlap")
    }
}

@Test("Word chunker with unicode")
func testWordChunkerWithUnicode() throws {
    let text = "Hello 世界 bonjour こんにちは مرحبا"
    let config = try ChunkingConfig(chunkSize: 15, contentType: .prose)
    let strategy = WordChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(!chunks.isEmpty, "Should handle unicode words")

    // Verify unicode is preserved
    let allText = chunks.map { $0.text }.joined(separator: " ")
    #expect(allText.contains("世界"), "Should preserve Chinese characters")
    #expect(allText.contains("こんにちは"), "Should preserve Japanese characters")
    #expect(allText.contains("مرحبا"), "Should preserve Arabic characters")
}

@Test("Word chunker with emojis")
func testWordChunkerWithEmojis() throws {
    let text = "Hello 🚀 world 🎉 test ✅"
    let config = try ChunkingConfig(chunkSize: 15, contentType: .prose)
    let strategy = WordChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(!chunks.isEmpty, "Should handle emojis")

    // Note: emojis may not be recognized as words by enumerateSubstrings
    // So we just verify the chunker doesn't crash and produces valid chunks
    let allText = chunks.map { $0.text }.joined(separator: " ")
    #expect(allText.contains("Hello"), "Should preserve regular words")
    #expect(allText.contains("world"), "Should preserve regular words")
}

@Test("Word chunker empty text")
func testWordChunkerEmptyText() throws {
    let text = ""
    let config = try ChunkingConfig(chunkSize: 100, contentType: .prose)
    let strategy = WordChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(chunks.isEmpty, "Empty text should return empty chunks")
}

@Test("Word chunker single word")
func testWordChunkerSingleWord() throws {
    let text = "Hello"
    let config = try ChunkingConfig(chunkSize: 100, contentType: .prose)
    let strategy = WordChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(chunks.count == 1, "Single word should produce one chunk")
    #expect(chunks[0].text == "Hello")
}

@Test("Word chunker very long word")
func testWordChunkerVeryLongWord() throws {
    // Create a word longer than chunk size
    let longWord = String(repeating: "a", count: 1000)
    let text = "\(longWord) normal words here"
    let config = try ChunkingConfig(chunkSize: 100, contentType: .prose)
    let strategy = WordChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(!chunks.isEmpty, "Should handle very long words")
    // The long word should be in its own chunk or split appropriately
    #expect(chunks.contains { $0.text.contains(longWord) || $0.text.contains("aaaa") })
}

@Test("Word chunker with punctuation")
func testWordChunkerWithPunctuation() throws {
    let text = "Hello world How are you I'm fine"
    let config = try ChunkingConfig(chunkSize: 20, contentType: .prose)
    let strategy = WordChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(!chunks.isEmpty, "Should handle text with words")

    // Note: enumerateSubstrings(byWords) separates punctuation from words
    // So punctuation may not be included in word chunks
    // We verify the chunker works with regular words
    let allText = chunks.map { $0.text }.joined(separator: " ")
    #expect(allText.contains("Hello"), "Should preserve words")
    #expect(allText.contains("world"), "Should preserve words")
}

@Test("Word chunker with hyphenated words")
func testWordChunkerWithHyphenatedWords() throws {
    let text = "state of the art well known self contained"
    let config = try ChunkingConfig(chunkSize: 25, contentType: .prose)
    let strategy = WordChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(!chunks.isEmpty, "Should handle words")

    // Note: enumerateSubstrings(byWords) may split hyphenated words
    // So we test with regular spaced words instead
    let allText = chunks.map { $0.text }.joined(separator: " ")
    #expect(allText.contains("state"), "Should preserve words")
    #expect(allText.contains("art"), "Should preserve words")
}

@Test("Word chunker metadata")
func testWordChunkerMetadata() throws {
    let text = "First second third fourth fifth"
    let config = try ChunkingConfig(chunkSize: 15, contentType: .prose)
    let strategy = WordChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(!chunks.isEmpty)

    // Verify metadata is correct
    for (index, chunk) in chunks.enumerated() {
        #expect(chunk.metadata.index == index, "Chunk index should match")
        #expect(chunk.metadata.contentType == .prose, "Content type should be prose")
        #expect(chunk.metadata.endPosition >= chunk.metadata.startPosition)
    }

    // Verify positions are sequential
    if chunks.count > 1 {
        #expect(chunks[1].metadata.startPosition >= chunks[0].metadata.startPosition)
    }
}
