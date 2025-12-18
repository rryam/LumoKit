import Testing
@testable import LumoKit

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

@Test("Semantic chunker mixed content with unclosed code fence")
func testSemanticChunkerMixedContentWithUnclosedCodeFence() throws {
    let text = """
    Prose before code.

    ```swift
    func code() {
        return 1
    }
    """
    let config = ChunkingConfig(
        chunkSize: 80,
        strategy: .semantic,
        contentType: .mixed
    )
    let strategy = SemanticChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(!chunks.isEmpty, "Should produce chunks")
    let codeChunks = chunks.filter { $0.metadata.contentType == .code }
    #expect(!codeChunks.isEmpty, "Should detect code even without closing fence")
    #expect(codeChunks[0].text.contains("func code()"))
    for chunk in chunks {
        #expect(!chunk.text.contains("```"), "Chunks should exclude code fences")
    }
}

@Test("Semantic chunker markdown with consecutive headers")
func testSemanticChunkerMarkdownConsecutiveHeaders() throws {
    let text = """
    # Header 1

    ## Header 2

    Content under header 2.
    """
    let config = ChunkingConfig(
        chunkSize: 80,
        strategy: .semantic,
        contentType: .markdown
    )
    let strategy = SemanticChunker()

    let chunks = try strategy.chunk(text: text, config: config)

    #expect(!chunks.isEmpty, "Should produce chunks")
    for chunk in chunks {
        #expect(!chunk.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    #expect(chunks.map { $0.text }.joined(separator: " ").contains("Header 2"))
}
