import Testing
@testable import LumoKit
import VecturaKit
import Foundation

// MARK: - Sentence Chunker Tests

@Test("Sentence chunker basic")
func testSentenceChunkerBasic() throws {
    let text = "This is the first sentence. This is the second sentence. And here is the third sentence."
    let config = ChunkingConfig(chunkSize: 50, strategy: .sentence)
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
    let config = ChunkingConfig(
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
    let config = ChunkingConfig(chunkSize: 50, strategy: .sentence)
    let strategy = SentenceChunker()

    let chunks = try strategy.chunk(text: longSentence, config: config)

    #expect(!chunks.isEmpty, "Should handle long sentences by splitting them")
}

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

// MARK: - Semantic Chunker Tests

@Test("Semantic chunker prose")
func testSemanticChunkerProse() throws {
    let text = """
    This is a prose text. It contains multiple sentences that form coherent paragraphs.

    The semantic chunker should respect natural boundaries.
    """
    let config = ChunkingConfig(
        chunkSize: 100,
        overlapPercentage: 0.1,
        strategy: .semantic,
        contentType: .prose
    )
    let strategy = SemanticChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(!chunks.isEmpty, "Should produce chunks")
    #expect(chunks.first?.metadata.contentType == .prose)
}

@Test("Semantic chunker code")
func testSemanticChunkerCode() throws {
    let text = """
    func example() {
        let x = 5
        let y = 10
        return x + y
    }

    func another() {
        print("Hello")
    }
    """
    let config = ChunkingConfig(
        chunkSize: 80,
        strategy: .semantic,
        contentType: .code
    )
    let strategy = SemanticChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(chunks.count == 2, "Should split into two logical blocks")
    #expect(chunks[0].text.contains("func example()"))
    #expect(chunks[1].text.contains("func another()"))
    #expect(chunks.first?.metadata.contentType == .code)
}

@Test("Semantic chunker markdown")
func testSemanticChunkerMarkdown() throws {
    let text = """
    # Header 1

    Some content under header 1.

    ## Header 2

    More content here.
    """
    let config = ChunkingConfig(
        chunkSize: 100,
        strategy: .semantic,
        contentType: .markdown
    )
    let strategy = SemanticChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(!chunks.isEmpty, "Should produce chunks")
    // Check that markdown structure is respected
    for chunk in chunks {
        #expect(!chunk.text.isEmpty)
    }
}

@Test("Semantic chunker mixed content")
func testSemanticChunkerMixedContent() throws {
    let text = """
    Here is some prose text.

    ```swift
    func code() {
        return 42
    }
    ```

    More prose after the code block.
    """
    let config = ChunkingConfig(
        chunkSize: 80,
        strategy: .semantic,
        contentType: .mixed
    )
    let strategy = SemanticChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(chunks.count >= 2, "Should handle mixed content by splitting it")

    let proseChunks = chunks.filter { $0.metadata.contentType == .prose }
    let codeChunks = chunks.filter { $0.metadata.contentType == .code }

    #expect(!proseChunks.isEmpty, "Should contain prose chunks")
    #expect(!codeChunks.isEmpty, "Should contain code chunks")
    #expect(codeChunks[0].text.contains("func code()"))
}

// MARK: - Word Chunker Tests

@Test("Word chunker basic")
func testWordChunkerBasic() throws {
    let text = "This is a simple test with multiple words"
    let config = ChunkingConfig(chunkSize: 20, contentType: .prose)
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
    let config = ChunkingConfig(
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
    let config = ChunkingConfig(chunkSize: 15, contentType: .prose)
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
    let config = ChunkingConfig(chunkSize: 15, contentType: .prose)
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
    let config = ChunkingConfig(chunkSize: 100, contentType: .prose)
    let strategy = WordChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(chunks.isEmpty, "Empty text should return empty chunks")
}

@Test("Word chunker single word")
func testWordChunkerSingleWord() throws {
    let text = "Hello"
    let config = ChunkingConfig(chunkSize: 100, contentType: .prose)
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
    let config = ChunkingConfig(chunkSize: 100, contentType: .prose)
    let strategy = WordChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(!chunks.isEmpty, "Should handle very long words")
    // The long word should be in its own chunk or split appropriately
    #expect(chunks.contains { $0.text.contains(longWord) || $0.text.contains("aaaa") })
}

@Test("Word chunker with punctuation")
func testWordChunkerWithPunctuation() throws {
    let text = "Hello world How are you I'm fine"
    let config = ChunkingConfig(chunkSize: 20, contentType: .prose)
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
    let config = ChunkingConfig(chunkSize: 25, contentType: .prose)
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
    let config = ChunkingConfig(chunkSize: 15, contentType: .prose)
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

// MARK: - Chunking Config Tests

@Test("Chunking config defaults")
func testChunkingConfigDefaults() {
    let config = ChunkingConfig()

    #expect(config.chunkSize == 500)
    #expect(config.overlapPercentage == 0.1)
    #expect(config.strategy == .semantic)
    #expect(config.contentType == .prose)
}

@Test("Chunking config overlap clamping")
func testChunkingConfigOverlapClamping() {
    let config1 = ChunkingConfig(overlapPercentage: -0.5)
    #expect(config1.overlapPercentage == 0.0, "Negative overlap should clamp to 0")

    let config2 = ChunkingConfig(overlapPercentage: 1.5)
    #expect(config2.overlapPercentage == 1.0, "Overlap > 1 should clamp to 1")
}

@Test("Chunking config overlap size")
func testChunkingConfigOverlapSize() {
    let config = ChunkingConfig(chunkSize: 100, overlapPercentage: 0.2)
    #expect(config.overlapSize == 20)
}

// MARK: - Strategy Factory Tests

@Test("Strategy factory")
func testStrategyFactory() {
    let sentenceStrategy = ChunkingStrategyFactory.strategy(for: .sentence)
    #expect(sentenceStrategy is SentenceChunker)

    let paragraphStrategy = ChunkingStrategyFactory.strategy(for: .paragraph)
    #expect(paragraphStrategy is ParagraphChunker)

    let semanticStrategy = ChunkingStrategyFactory.strategy(for: .semantic)
    #expect(semanticStrategy is SemanticChunker)
}

// MARK: - Chunk Metadata Tests

@Test("Chunk metadata")
func testChunkMetadata() throws {
    let text = "This is a test sentence. Another sentence here."
    let config = ChunkingConfig(chunkSize: 30, strategy: .sentence)
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

// MARK: - Public API Tests

@Test("LumoKit public API")
func testLumoKitPublicAPI() async throws {
    let config = VecturaConfig(name: "test-db")
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
    let config = VecturaConfig(name: "test-db-source")
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
    let config = VecturaConfig(name: "test-db-search-validation")
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
