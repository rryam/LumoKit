import Testing
@testable import LumoKit

// MARK: - Chunking Config Tests

@Test("Chunking config defaults")
func testChunkingConfigDefaults() throws {
    let config = try ChunkingConfig()

    #expect(config.chunkSize == 500)
    #expect(config.overlapPercentage == 0.1)
    #expect(config.strategy == .semantic)
    #expect(config.contentType == .prose)
}

@Test("Chunking config overlap clamping")
func testChunkingConfigOverlapClamping() throws {
    let config1 = try ChunkingConfig(overlapPercentage: -0.5)
    #expect(config1.overlapPercentage == 0.0, "Negative overlap should clamp to 0")

    let config2 = try ChunkingConfig(overlapPercentage: 1.5)
    #expect(config2.overlapPercentage == 1.0, "Overlap > 1 should clamp to 1")
}

@Test("Chunking config overlap size")
func testChunkingConfigOverlapSize() throws {
    let config = try ChunkingConfig(chunkSize: 100, overlapPercentage: 0.2)
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
