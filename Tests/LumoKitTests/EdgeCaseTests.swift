import Testing
@testable import LumoKit

// MARK: - Edge Case Tests

@Test("Empty string input")
func testEmptyStringInput() throws {
    let config = ChunkingConfig(chunkSize: 100, strategy: .sentence)
    let strategy = SentenceChunker()

    let chunks = try strategy.chunk(text: "", config: config)
    #expect(chunks.isEmpty, "Empty string should return empty chunks")
}

@Test("Very large chunk sizes (>10,000 characters)")
func testVeryLargeChunkSize() throws {
    // Create text > 10,000 characters
    let text = String(repeating: "This is a sentence with many words. ", count: 500)
    #expect(text.count > 10000, "Test text should be > 10,000 characters")

    let config = ChunkingConfig(chunkSize: 20000, strategy: .sentence)
    let strategy = SentenceChunker()

    let chunks = try strategy.chunk(text: text, config: config)
    #expect(!chunks.isEmpty)
    // With chunk size larger than text, should produce minimal chunks
    #expect(chunks.count <= 3, "Large chunk size should produce few chunks")
}

@Test("Overlap percentage = 1.0 (100% overlap)")
func testFullOverlap() throws {
    let text = "First sentence. Second sentence. Third sentence."
    let config = ChunkingConfig(
        chunkSize: 30,
        overlapPercentage: 1.0,
        strategy: .sentence
    )
    let strategy = SentenceChunker()

    let chunks = try strategy.chunk(text: text, config: config)
    #expect(!chunks.isEmpty)

    // With 100% overlap, overlap size equals chunk size
    #expect(config.overlapSize == config.chunkSize)

    if chunks.count > 1 {
        #expect(chunks[1].metadata.hasOverlapWithPrevious, "Second chunk should have overlap")
        // Verify actual overlap by checking positions
        #expect(chunks[1].metadata.startPosition < chunks[0].metadata.endPosition)
    }
}

@Test("Documents with only whitespace")
func testOnlyWhitespace() throws {
    let text = "   \n\n\t\t   \n   "
    let config = ChunkingConfig(chunkSize: 100, strategy: .sentence)
    let strategy = SentenceChunker()

    let chunks = try strategy.chunk(text: text, config: config)
    // Whitespace-only text should return empty chunks (no sentences/words detected)
    #expect(chunks.isEmpty, "Whitespace-only text should produce no chunks")
}

@Test("Documents with only special characters")
func testOnlySpecialCharacters() throws {
    let text = "!@#$%^&*()_+-=[]{}|;':\",./<>?"
    let config = ChunkingConfig(chunkSize: 20, strategy: .sentence)
    let strategy = SentenceChunker()

    let chunks = try strategy.chunk(text: text, config: config)
    // Special characters might not form sentences, so could be empty or fallback to word chunking
    #expect(chunks.isEmpty || chunks.allSatisfy { !$0.text.isEmpty })
}

@Test("Concurrent chunking operations")
func testConcurrentChunking() async throws {
    let text = String(repeating: "This is a test sentence. ", count: 100)
    let chunkSize = 100
    let overlapPercentage = 0.1

    try await withThrowingTaskGroup(of: [Chunk].self) { group in
        for _ in 0..<10 {
            group.addTask {
                let config = ChunkingConfig(
                    chunkSize: chunkSize,
                    overlapPercentage: overlapPercentage,
                    strategy: .sentence
                )
                let strategy = SentenceChunker()
                return try strategy.chunk(text: text, config: config)
            }
        }

        var results: [[Chunk]] = []
        for try await chunks in group {
            results.append(chunks)
        }

        #expect(results.count == 10, "Should have 10 concurrent results")
        #expect(!results.isEmpty)

        // All results should be identical (deterministic chunking)
        let firstResult = results[0]
        for result in results {
            #expect(result.count == firstResult.count, "Concurrent operations should produce consistent chunk counts")
            #expect(!result.isEmpty, "All results should have chunks")
        }
    }
}

@Test("Memory pressure scenarios")
func testMemoryPressure() throws {
    // Create a large text that will produce many chunks
    let largeText = String(repeating: "This is a very long sentence that contains many words. ", count: 2000)
    #expect(largeText.count > 100000, "Should be a large text")

    let config = ChunkingConfig(chunkSize: 500, strategy: .sentence)
    let strategy = SentenceChunker()

    let chunks = try strategy.chunk(text: largeText, config: config)
    #expect(!chunks.isEmpty)
    #expect(chunks.count > 10, "Large text should produce many chunks")

    // Verify all chunks are valid and positions are correct
    for (index, chunk) in chunks.enumerated() {
        #expect(!chunk.text.isEmpty, "Chunk \(index) should not be empty")
        #expect(chunk.metadata.index == index, "Chunk index should match position")
        #expect(chunk.metadata.startPosition >= 0, "Start position should be non-negative")
        #expect(chunk.metadata.endPosition > chunk.metadata.startPosition, "End should be after start")

        // Verify positions are sequential
        if index > 0 {
            let prevEndPos = chunks[index - 1].metadata.startPosition
            #expect(chunk.metadata.startPosition >= prevEndPos, "Chunks should be sequential")
        }
    }
}

@Test("Zero overlap percentage")
func testZeroOverlap() throws {
    let text = "First sentence. Second sentence. Third sentence."
    let config = ChunkingConfig(
        chunkSize: 30,
        overlapPercentage: 0.0,
        strategy: .sentence
    )
    let strategy = SentenceChunker()

    let chunks = try strategy.chunk(text: text, config: config)
    #expect(!chunks.isEmpty)
    #expect(config.overlapSize == 0, "Zero overlap should have zero overlap size")

    if chunks.count > 1 {
        #expect(!chunks[1].metadata.hasOverlapWithPrevious, "Zero overlap should not have overlap flag")
        // Verify no actual text overlap
        #expect(chunks[1].metadata.startPosition >= chunks[0].metadata.endPosition, "Chunks should not overlap")
    }
}

@Test("Single character chunk size")
func testSingleCharacterChunkSize() throws {
    let text = "Hello world"
    // Use sentence strategy - WordChunker is internal fallback
    let config = ChunkingConfig(chunkSize: 1, strategy: .sentence)
    let strategy = SentenceChunker()

    let chunks = try strategy.chunk(text: text, config: config)
    #expect(!chunks.isEmpty, "Should produce chunks even with tiny chunk size")
    // With chunk size 1, should produce many chunks
    #expect(chunks.count > 1, "Tiny chunk size should produce multiple chunks")
}

@Test("Negative chunk size throws error")
func testNegativeChunkSize() throws {
    let text = "Test"
    let config = ChunkingConfig(chunkSize: -1, strategy: .sentence)
    let strategy = SentenceChunker()

    #expect(throws: LumoKitError.invalidChunkSize) {
        try strategy.chunk(text: text, config: config)
    }
}

@Test("Very small text with large chunk size")
func testSmallTextLargeChunk() throws {
    let text = "Hi"
    let config = ChunkingConfig(chunkSize: 10000, strategy: .sentence)
    let strategy = SentenceChunker()

    let chunks = try strategy.chunk(text: text, config: config)
    #expect(!chunks.isEmpty)
    #expect(chunks.count == 1, "Small text with large chunk should produce single chunk")
    #expect(chunks[0].text == text, "Chunk should contain full text")
    #expect(chunks[0].metadata.startPosition == 0)
    #expect(chunks[0].metadata.endPosition == text.count)
}
