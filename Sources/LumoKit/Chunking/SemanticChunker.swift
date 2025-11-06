import Foundation
import NaturalLanguage

/// Semantic chunking strategy with intelligent boundary detection
/// This strategy adapts to content type and uses natural language boundaries
struct SemanticChunker: ChunkingStrategy {
    func chunk(text: String, config: ChunkingConfig) throws -> [Chunk] {
        try ChunkingHelper.validateChunkSize(config.chunkSize)

        guard !text.isEmpty else { return [] }

        // Route to specialized handlers based on content type
        switch config.contentType {
        case .code:
            return try chunkCode(text: text, config: config)
        case .markdown:
            return try chunkMarkdown(text: text, config: config)
        case .mixed:
            return try chunkMixed(text: text, config: config)
        case .prose:
            return try chunkProse(text: text, config: config)
        }
    }

    // MARK: - Prose Chunking

    private func chunkProse(text: String, config: ChunkingConfig) throws -> [Chunk] {
        // For prose, prefer paragraph boundaries, then sentences
        let paragraphs = extractParagraphs(from: text)

        if paragraphs.count > 1 {
            return try ParagraphChunker().chunk(text: text, config: config)
        } else {
            return try SentenceChunker().chunk(text: text, config: config)
        }
    }

    // MARK: - Code Chunking

    private func chunkCode(text: String, config: ChunkingConfig) throws -> [Chunk] {
        // For code, respect logical blocks (functions, classes, etc.)
        let lines = text.components(separatedBy: .newlines)
        let blocks = groupCodeIntoLogicalBlocks(lines)

        var chunks: [Chunk] = []
        var currentBlock: [String] = []
        var currentSize = 0
        var chunkStartPosition = 0

        for (idx, block) in blocks.enumerated() {
            let blockText = block.joined(separator: "\n")
            let blockSize = blockText.count

            if blockSize > config.chunkSize {
                // Flush current
                if !currentBlock.isEmpty {
                    let chunkText = currentBlock.joined(separator: "\n")
                    chunks.append(createChunk(
                        text: chunkText,
                        index: chunks.count,
                        startPosition: chunkStartPosition,
                        endPosition: chunkStartPosition + chunkText.count,
                        config: config
                    ))
                    chunkStartPosition += chunkText.count + 1
                    currentBlock = []
                    currentSize = 0
                }

                // Split large block by lines
                chunks.append(createChunk(
                    text: blockText,
                    index: chunks.count,
                    startPosition: chunkStartPosition,
                    endPosition: chunkStartPosition + blockSize,
                    config: config
                ))
                chunkStartPosition += blockSize + 1
                continue
            }

            if currentSize + blockSize > config.chunkSize && !currentBlock.isEmpty {
                let chunkText = currentBlock.joined(separator: "\n")
                chunks.append(createChunk(
                    text: chunkText,
                    index: chunks.count,
                    startPosition: chunkStartPosition,
                    endPosition: chunkStartPosition + chunkText.count,
                    config: config
                ))
                chunkStartPosition += chunkText.count + 1

                // Overlap handling for code
                if config.overlapSize > 0 && idx < blocks.count - 1 {
                    let overlapLines = currentBlock.suffix(min(3, currentBlock.count))
                    currentBlock = Array(overlapLines)
                    currentSize = currentBlock.joined(separator: "\n").count
                } else {
                    currentBlock = []
                    currentSize = 0
                }
            }

            currentBlock.append(contentsOf: block)
            currentSize += blockSize + (currentBlock.count > 1 ? 1 : 0)
        }

        if !currentBlock.isEmpty {
            let chunkText = currentBlock.joined(separator: "\n")
            chunks.append(createChunk(
                text: chunkText,
                index: chunks.count,
                startPosition: chunkStartPosition,
                endPosition: chunkStartPosition + chunkText.count,
                config: config
            ))
        }

        return chunks
    }

    // MARK: - Markdown Chunking

    private func chunkMarkdown(text: String, config: ChunkingConfig) throws -> [Chunk] {
        let sections = extractMarkdownSections(from: text)

        var chunks: [Chunk] = []
        var currentSections: [String] = []
        var currentSize = 0
        var chunkStartPosition = 0

        for (idx, section) in sections.enumerated() {
            let sectionSize = section.count

            if sectionSize > config.chunkSize {
                // Flush current
                if !currentSections.isEmpty {
                    let chunkText = currentSections.joined(separator: "\n\n")
                    chunks.append(createChunk(
                        text: chunkText,
                        index: chunks.count,
                        startPosition: chunkStartPosition,
                        endPosition: chunkStartPosition + chunkText.count,
                        config: config
                    ))
                    chunkStartPosition += chunkText.count + 2
                    currentSections = []
                    currentSize = 0
                }

                // Use sentence chunking for large sections
                let sentenceChunks = try SentenceChunker().chunk(text: section, config: config)
                for sentenceChunk in sentenceChunks {
                    chunks.append(Chunk(
                        text: sentenceChunk.text,
                        metadata: ChunkMetadata(
                            index: chunks.count,
                            startPosition: chunkStartPosition,
                            endPosition: chunkStartPosition + sentenceChunk.text.count,
                            hasOverlapWithPrevious: chunks.count > 0,
                            hasOverlapWithNext: true,
                            contentType: .markdown,
                            source: nil
                        )
                    ))
                    chunkStartPosition += sentenceChunk.text.count + 2
                }
                continue
            }

            if currentSize + sectionSize > config.chunkSize && !currentSections.isEmpty {
                let chunkText = currentSections.joined(separator: "\n\n")
                chunks.append(createChunk(
                    text: chunkText,
                    index: chunks.count,
                    startPosition: chunkStartPosition,
                    endPosition: chunkStartPosition + chunkText.count,
                    config: config
                ))
                chunkStartPosition += chunkText.count + 2

                if config.overlapSize > 0 && idx < sections.count - 1 {
                    let overlap = currentSections.suffix(1)
                    currentSections = Array(overlap)
                    currentSize = currentSections.joined(separator: "\n\n").count
                } else {
                    currentSections = []
                    currentSize = 0
                }
            }

            currentSections.append(section)
            currentSize += sectionSize + (currentSections.count > 1 ? 2 : 0)
        }

        if !currentSections.isEmpty {
            let chunkText = currentSections.joined(separator: "\n\n")
            chunks.append(createChunk(
                text: chunkText,
                index: chunks.count,
                startPosition: chunkStartPosition,
                endPosition: chunkStartPosition + chunkText.count,
                config: config
            ))
        }

        return chunks
    }

    // MARK: - Mixed Content Chunking

    private func chunkMixed(text: String, config: ChunkingConfig) throws -> [Chunk] {
        // Detect code blocks and split accordingly
        let segments = separateCodeAndProse(text)

        var chunks: [Chunk] = []
        var chunkStartPosition = 0

        for segment in segments {
            let segmentConfig = ChunkingConfig(
                chunkSize: config.chunkSize,
                overlapPercentage: config.overlapPercentage,
                strategy: config.strategy,
                contentType: segment.isCode ? .code : .prose
            )

            let segmentChunks = try chunk(text: segment.content, config: segmentConfig)

            for segmentChunk in segmentChunks {
                let adjustedMetadata = ChunkMetadata(
                    index: chunks.count,
                    startPosition: chunkStartPosition,
                    endPosition: chunkStartPosition + segmentChunk.text.count,
                    hasOverlapWithPrevious: chunks.count > 0,
                    hasOverlapWithNext: true,
                    contentType: segment.isCode ? .code : .prose,
                    source: nil
                )
                chunks.append(Chunk(text: segmentChunk.text, metadata: adjustedMetadata))
                chunkStartPosition += segmentChunk.text.count + 1
            }
        }

        return chunks
    }

    // MARK: - Helper Methods

    private func extractParagraphs(from text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .paragraph)
        tokenizer.string = text

        var paragraphs: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let paragraph = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !paragraph.isEmpty {
                paragraphs.append(paragraph)
            }
            return true
        }
        return paragraphs
    }

    private func groupCodeIntoLogicalBlocks(_ lines: [String]) -> [[String]] {
        var blocks: [[String]] = []
        var currentBlock: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Start new block on function/class definitions or empty lines
            if trimmed.isEmpty && !currentBlock.isEmpty {
                blocks.append(currentBlock)
                currentBlock = []
            } else {
                currentBlock.append(line)
            }
        }

        if !currentBlock.isEmpty {
            blocks.append(currentBlock)
        }

        return blocks.isEmpty ? [lines] : blocks
    }

    private func extractMarkdownSections(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var sections: [String] = []
        var currentSection: [String] = []

        for line in lines {
            // New section starts with a header
            if line.hasPrefix("#") && !currentSection.isEmpty {
                sections.append(currentSection.joined(separator: "\n"))
                currentSection = [line]
            } else {
                currentSection.append(line)
            }
        }

        if !currentSection.isEmpty {
            sections.append(currentSection.joined(separator: "\n"))
        }

        return sections.isEmpty ? [text] : sections
    }

    private struct ContentSegment {
        let content: String
        let isCode: Bool
    }

    private func separateCodeAndProse(_ text: String) -> [ContentSegment] {
        var segments: [ContentSegment] = []
        var currentContent: [String] = []
        var inCodeBlock = false

        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                // Save current segment
                if !currentContent.isEmpty {
                    segments.append(ContentSegment(
                        content: currentContent.joined(separator: "\n"),
                        isCode: inCodeBlock
                    ))
                    currentContent = []
                }
                inCodeBlock.toggle()
                currentContent.append(line)
            } else {
                currentContent.append(line)
            }
        }

        if !currentContent.isEmpty {
            segments.append(ContentSegment(
                content: currentContent.joined(separator: "\n"),
                isCode: inCodeBlock
            ))
        }

        return segments.isEmpty ? [ContentSegment(content: text, isCode: false)] : segments
    }

    private func createChunk(
        text: String,
        index: Int,
        startPosition: Int,
        endPosition: Int,
        config: ChunkingConfig
    ) -> Chunk {
        let metadata = ChunkMetadata(
            index: index,
            startPosition: startPosition,
            endPosition: endPosition,
            hasOverlapWithPrevious: index > 0 && config.overlapSize > 0,
            hasOverlapWithNext: false,
            contentType: config.contentType,
            source: nil
        )
        return Chunk(text: text, metadata: metadata)
    }
}
