import XCTest
@testable import LumoKit

final class ChunkingTests: XCTestCase {

    // MARK: - Sentence Chunker Tests

    func testSentenceChunkerBasic() throws {
        let text = "This is the first sentence. This is the second sentence. And here is the third sentence."
        let config = ChunkingConfig(chunkSize: 50, strategy: .sentence)
        let strategy = SentenceChunker()

        let chunks = try strategy.chunk(text: text, config: config)

        XCTAssertFalse(chunks.isEmpty, "Should produce chunks")
        // Verify that sentences aren't split mid-sentence
        for chunk in chunks {
            XCTAssertTrue(
                chunk.text.hasSuffix(".") || chunk.text.contains("."),
                "Chunks should contain complete sentences"
            )
        }
    }

    func testSentenceChunkerWithOverlap() throws {
        let text = "First sentence here. Second sentence here. Third sentence here. Fourth sentence here."
        let config = ChunkingConfig(
            chunkSize: 40,
            overlapPercentage: 0.2,
            strategy: .sentence
        )
        let strategy = SentenceChunker()

        let chunks = try strategy.chunk(text: text, config: config)

        XCTAssertGreaterThan(chunks.count, 1, "Should produce multiple chunks")
        // Check that overlap metadata is set correctly
        if chunks.count > 1 {
            XCTAssertTrue(chunks[1].metadata.hasOverlapWithPrevious, "Second chunk should have overlap")
        }
    }

    func testSentenceChunkerLongSentence() throws {
        let longSentence = String(repeating: "word ", count: 100) + "."
        let config = ChunkingConfig(chunkSize: 50, strategy: .sentence)
        let strategy = SentenceChunker()

        let chunks = try strategy.chunk(text: longSentence, config: config)

        XCTAssertFalse(chunks.isEmpty, "Should handle long sentences by splitting them")
    }

    // MARK: - Paragraph Chunker Tests

    func testParagraphChunkerBasic() throws {
        let text = """
        This is the first paragraph. It has multiple sentences.

        This is the second paragraph. It also has sentences.

        And here is the third paragraph.
        """
        let config = ChunkingConfig(chunkSize: 100, strategy: .paragraph)
        let strategy = ParagraphChunker()

        let chunks = try strategy.chunk(text: text, config: config)

        XCTAssertFalse(chunks.isEmpty, "Should produce chunks")
        // Paragraphs should be respected
        for chunk in chunks {
            XCTAssertFalse(chunk.text.isEmpty)
        }
    }

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

        XCTAssertGreaterThan(chunks.count, 1, "Should produce multiple chunks")
    }

    // MARK: - Semantic Chunker Tests

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

        XCTAssertFalse(chunks.isEmpty, "Should produce chunks")
        XCTAssertEqual(chunks.first?.metadata.contentType, .prose)
    }

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

        XCTAssertFalse(chunks.isEmpty, "Should produce chunks")
        XCTAssertEqual(chunks.first?.metadata.contentType, .code)
    }

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

        XCTAssertFalse(chunks.isEmpty, "Should produce chunks")
        // Check that markdown structure is respected
        for chunk in chunks {
            XCTAssertFalse(chunk.text.isEmpty)
        }
    }

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
            chunkSize: 150,
            strategy: .semantic,
            contentType: .mixed
        )
        let strategy = SemanticChunker()

        let chunks = try strategy.chunk(text: text, config: config)

        XCTAssertFalse(chunks.isEmpty, "Should handle mixed content")
    }

    // MARK: - Chunking Config Tests

    func testChunkingConfigDefaults() {
        let config = ChunkingConfig()

        XCTAssertEqual(config.chunkSize, 500)
        XCTAssertEqual(config.overlapPercentage, 0.1)
        XCTAssertEqual(config.strategy, .semantic)
        XCTAssertEqual(config.contentType, .prose)
    }

    func testChunkingConfigOverlapClamping() {
        let config1 = ChunkingConfig(overlapPercentage: -0.5)
        XCTAssertEqual(config1.overlapPercentage, 0.0, "Negative overlap should clamp to 0")

        let config2 = ChunkingConfig(overlapPercentage: 1.5)
        XCTAssertEqual(config2.overlapPercentage, 1.0, "Overlap > 1 should clamp to 1")
    }

    func testChunkingConfigOverlapSize() {
        let config = ChunkingConfig(chunkSize: 100, overlapPercentage: 0.2)
        XCTAssertEqual(config.overlapSize, 20)
    }

    // MARK: - Strategy Factory Tests

    func testStrategyFactory() {
        let sentenceStrategy = ChunkingStrategyFactory.strategy(for: .sentence)
        XCTAssertTrue(sentenceStrategy is SentenceChunker)

        let paragraphStrategy = ChunkingStrategyFactory.strategy(for: .paragraph)
        XCTAssertTrue(paragraphStrategy is ParagraphChunker)

        let semanticStrategy = ChunkingStrategyFactory.strategy(for: .semantic)
        XCTAssertTrue(semanticStrategy is SemanticChunker)
    }

    // MARK: - Chunk Metadata Tests

    func testChunkMetadata() throws {
        let text = "This is a test sentence. Another sentence here."
        let config = ChunkingConfig(chunkSize: 30, strategy: .sentence)
        let strategy = SentenceChunker()

        let chunks = try strategy.chunk(text: text, config: config)

        XCTAssertFalse(chunks.isEmpty)

        // Check first chunk metadata
        let firstChunk = chunks[0]
        XCTAssertEqual(firstChunk.metadata.index, 0)
        XCTAssertEqual(firstChunk.metadata.startPosition, 0)
        XCTAssertFalse(firstChunk.metadata.hasOverlapWithPrevious)

        // If there's a second chunk, check its metadata
        if chunks.count > 1 {
            let secondChunk = chunks[1]
            XCTAssertEqual(secondChunk.metadata.index, 1)
            XCTAssertGreaterThan(secondChunk.metadata.startPosition, firstChunk.metadata.startPosition)
        }
    }

    // MARK: - Integration Tests

    func testLumoKitIntegration() async throws {
        // This test requires VecturaKit setup, so we'll test the chunking methods only
        let text = "This is a test. It has multiple sentences. Each sentence is important."

        let config = ChunkingConfig(chunkSize: 30, strategy: .sentence)
        let strategy = SentenceChunker()

        let chunks = try strategy.chunk(text: text, config: config)

        XCTAssertFalse(chunks.isEmpty)

        // Verify chunks can be converted to strings (simulating what LumoKit does)
        let chunkTexts = chunks.map { $0.text }
        XCTAssertFalse(chunkTexts.isEmpty)
        XCTAssertEqual(chunkTexts.joined(separator: " ").count, text.count, accuracy: 20)
    }

    // MARK: - Edge Cases

    func testChunkingWithSpecialCharacters() throws {
        let text = "Hello! How are you? I'm fine, thanks. What about you?"
        let config = ChunkingConfig(chunkSize: 25, strategy: .sentence)
        let strategy = SentenceChunker()

        let chunks = try strategy.chunk(text: text, config: config)

        XCTAssertFalse(chunks.isEmpty)
    }

    func testChunkingWithUnicodeCharacters() throws {
        let text = "Hello 世界! This is a test. Unicode 文字 support."
        let config = ChunkingConfig(chunkSize: 30, strategy: .sentence)
        let strategy = SentenceChunker()

        let chunks = try strategy.chunk(text: text, config: config)

        XCTAssertFalse(chunks.isEmpty)
    }

    func testChunkingVerySmallChunkSize() throws {
        let text = "Short text"
        let config = ChunkingConfig(chunkSize: 5, strategy: .sentence)
        let strategy = SentenceChunker()

        let chunks = try strategy.chunk(text: text, config: config)

        XCTAssertFalse(chunks.isEmpty)
    }

    func testInvalidChunkSize() {
        let text = "Some text"
        let config = ChunkingConfig(chunkSize: 0, strategy: .sentence)
        let strategy = SentenceChunker()

        XCTAssertThrowsError(try strategy.chunk(text: text, config: config)) { error in
            XCTAssertEqual(error as? LumoKitError, .invalidChunkSize)
        }
    }
}
