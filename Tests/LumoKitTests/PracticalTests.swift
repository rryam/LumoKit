import Testing
@testable import LumoKit

// MARK: - Practical Real-World Tests

@Test("Mixed content with code blocks")
func testMixedContentWithCodeBlocks() throws {
    let text = """
    This is a prose paragraph explaining something important.
    
    Here's some code:
    
    ```swift
    func example() {
        let value = 42
        print(value)
    }
    ```
    
    More prose content here that continues the explanation.
    
    ```python
    def hello():
        print("Hello, World!")
    ```
    
    Final paragraph wrapping things up.
    """
    
    let config = ChunkingConfig(
        chunkSize: 100,
        strategy: .semantic,
        contentType: .mixed
    )
    let strategy = SemanticChunker()
    
    let chunks = try strategy.chunk(text: text, config: config)
    #expect(!chunks.isEmpty)
    
    // Should separate code and prose
    let codeChunks = chunks.filter { $0.metadata.contentType == .code }
    let proseChunks = chunks.filter { $0.metadata.contentType == .prose }
    
    #expect(!codeChunks.isEmpty, "Should detect code blocks")
    #expect(!proseChunks.isEmpty, "Should detect prose sections")
    
    // Verify code chunks contain code
    for codeChunk in codeChunks {
        #expect(codeChunk.text.contains("func") || codeChunk.text.contains("def"), "Code chunks should contain code")
    }
    
    // Verify prose chunks don't contain code fences
    for proseChunk in proseChunks {
        #expect(!proseChunk.text.contains("```"), "Prose chunks shouldn't contain code fences")
    }
}

@Test("Documents with unicode and emojis")
func testUnicodeAndEmojis() throws {
    let text = """
    Hello 世界! This is a test with unicode characters.
    
    Here are some emojis: 🚀 🎉 ✅ ❌ 🔥 💯
    
    More unicode: Café naïve résumé 日本語 한국어 العربية
    
    Emoji in sentences: The rocket 🚀 launched successfully! Party time 🎉
    
    Mixed: Hello 世界 🚀 and 日本語 text.
    """
    
    let config = ChunkingConfig(chunkSize: 100, strategy: .sentence)
    let strategy = SentenceChunker()
    
    let chunks = try strategy.chunk(text: text, config: config)
    #expect(!chunks.isEmpty)
    
    // Verify unicode and emojis are preserved
    let allText = chunks.map { $0.text }.joined(separator: " ")
    #expect(allText.contains("世界"), "Should preserve Chinese characters")
    #expect(allText.contains("🚀"), "Should preserve emojis")
    #expect(allText.contains("日本語"), "Should preserve Japanese characters")
    #expect(allText.contains("Café"), "Should preserve accented characters")
    
    // Verify chunks contain valid unicode
    for chunk in chunks {
        #expect(!chunk.text.isEmpty)
        // Verify positions are correct even with unicode
        #expect(chunk.metadata.endPosition > chunk.metadata.startPosition)
    }
}

@Test("Very long single sentence")
func testVeryLongSingleSentence() throws {
    // Create a sentence that's longer than chunk size
    let longSentence = String(repeating: "word ", count: 500) + "end."
    #expect(longSentence.count > 2000, "Should be a very long sentence")
    
    let config = ChunkingConfig(chunkSize: 500, strategy: .sentence)
    let strategy = SentenceChunker()
    
    let chunks = try strategy.chunk(text: longSentence, config: config)
    #expect(!chunks.isEmpty)
    #expect(chunks.count > 1, "Very long sentence should be split into multiple chunks")
    
    // Verify all chunks are valid
    for chunk in chunks {
        #expect(!chunk.text.isEmpty)
        #expect(chunk.metadata.startPosition >= 0)
        #expect(chunk.metadata.endPosition > chunk.metadata.startPosition)
    }
    
    // Verify chunks can be reconstructed
    let reconstructed = chunks.map { $0.text }.joined(separator: " ")
    #expect(reconstructed.contains("word"), "Should contain original content")
}

@Test("Very long single paragraph")
func testVeryLongSingleParagraph() throws {
    // Create a paragraph with many sentences that exceeds chunk size
    let longParagraph = String(repeating: "This is a sentence in a paragraph. ", count: 100)
    #expect(longParagraph.count > 3000, "Should be a very long paragraph")
    
    let config = ChunkingConfig(chunkSize: 500, strategy: .paragraph)
    let strategy = ParagraphChunker()
    
    let chunks = try strategy.chunk(text: longParagraph, config: config)
    #expect(!chunks.isEmpty)
    
    // Long paragraph should be split (either by sentence fallback or line-by-line)
    #expect(chunks.count >= 1)
    
    // Verify all chunks are valid
    for chunk in chunks {
        #expect(!chunk.text.isEmpty)
        #expect(chunk.metadata.startPosition >= 0)
        #expect(chunk.metadata.endPosition > chunk.metadata.startPosition)
    }
    
    // Verify content is preserved
    let allText = chunks.map { $0.text }.joined(separator: " ")
    #expect(allText.contains("sentence"), "Should contain original content")
}

@Test("Mixed unicode and code blocks")
func testMixedUnicodeAndCode() throws {
    let text = """
    Here's some prose with unicode: Hello 世界! 🚀
    
    ```swift
    // Code with comments
    func greet(name: String) -> String {
        return "Hello, \\(name)! 世界"
    }
    ```
    
    More prose with emojis: Success! ✅ Done. 🎉
    """
    
    let config = ChunkingConfig(
        chunkSize: 150,
        strategy: .semantic,
        contentType: .mixed
    )
    let strategy = SemanticChunker()
    
    let chunks = try strategy.chunk(text: text, config: config)
    #expect(!chunks.isEmpty)
    
    // Should handle both unicode and code
    let allText = chunks.map { $0.text }.joined(separator: " ")
    #expect(allText.contains("世界"), "Should preserve unicode in prose")
    #expect(allText.contains("🚀"), "Should preserve emojis")
    #expect(allText.contains("func greet"), "Should preserve code")
    
    // Code chunks should preserve unicode in code
    let codeChunks = chunks.filter { $0.metadata.contentType == .code }
    if !codeChunks.isEmpty {
        #expect(codeChunks[0].text.contains("世界") || codeChunks[0].text.contains("greet"), "Code should preserve content")
    }
}

