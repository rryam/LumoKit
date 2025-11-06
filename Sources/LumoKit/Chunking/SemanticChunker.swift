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
        // For prose, ParagraphChunker is preferred as it respects paragraph boundaries.
        // It intelligently falls back to SentenceChunker if no paragraphs are found.
        do {
            return try ParagraphChunker().chunk(text: text, config: config)
        } catch {
            throw ChunkingHelper.wrapChunkingError(error, strategyName: "SemanticChunker.prose (via ParagraphChunker)")
        }
    }

    // MARK: - Code Chunking

    private func chunkCode(text: String, config: ChunkingConfig) throws -> [Chunk] {
        // For code, respect logical blocks (functions, classes, etc.)
        let lines = splitLinesWithRanges(from: text)
        let blocks = groupCodeIntoLogicalBlocks(lines)

        var chunks: [Chunk] = []
        var currentBlock: [(line: String, range: Range<String.Index>)] = []
        var currentSize = 0

        for (idx, block) in blocks.enumerated() {
            let blockText = block.map { $0.line }.joined(separator: ChunkingHelper.Constants.lineSeparator)
            let blockSize = blockText.count

            if blockSize > config.chunkSize {
                // Flush current
                if !currentBlock.isEmpty {
                    flushCodeBlock(
                        from: currentBlock,
                        to: &chunks,
                        text: text,
                        config: config,
                        hasNext: true
                    )
                    currentBlock = []
                    currentSize = 0
                }

                // Split large block by lines
                splitOversizedBlock(
                    block: block,
                    text: text,
                    config: config,
                    chunks: &chunks,
                    hasMoreBlocks: idx < blocks.count - 1
                )
                continue
            }

            if currentSize + blockSize > config.chunkSize && !currentBlock.isEmpty {
                flushCodeBlock(
                    from: currentBlock,
                    to: &chunks,
                    text: text,
                    config: config,
                    hasNext: idx < blocks.count - 1
                )

                // Overlap handling for code
                if config.overlapSize > 0 && idx < blocks.count - 1 {
                    let overlapLines = currentBlock.suffix(min(ChunkingHelper.Constants.codeOverlapLineCount, currentBlock.count))
                    currentBlock = Array(overlapLines)
                    currentSize = currentBlock.map { $0.line }.joined(separator: ChunkingHelper.Constants.lineSeparator).count
                } else {
                    currentBlock = []
                    currentSize = 0
                }
            }

            currentBlock.append(contentsOf: block)
            currentSize += blockSize + (currentBlock.count > 1 ? ChunkingHelper.Constants.lineSeparatorSize : 0)
        }

        if !currentBlock.isEmpty {
            flushCodeBlock(
                from: currentBlock,
                to: &chunks,
                text: text,
                config: config,
                hasNext: false
            )
        }

        return chunks
    }

    // MARK: - Markdown Chunking

    private func chunkMarkdown(text: String, config: ChunkingConfig) throws -> [Chunk] {
        let sections = extractMarkdownSections(from: text)

        var chunks: [Chunk] = []
        var currentSections: [(section: String, range: Range<String.Index>)] = []
        var currentSize = 0

        for (idx, sectionData) in sections.enumerated() {
            let sectionSize = sectionData.section.count

            if sectionSize > config.chunkSize {
                // Flush current
                if !currentSections.isEmpty {
                    flushMarkdownSections(
                        from: currentSections,
                        to: &chunks,
                        text: text,
                        config: config,
                        hasNext: true
                    )
                    currentSections = []
                    currentSize = 0
                }

                // Use sentence chunking for large sections
                do {
                    let sentenceChunks = try SentenceChunker().chunk(text: sectionData.section, config: config)
                    let baseOffset = text.distance(from: text.startIndex, to: sectionData.range.lowerBound)
                    for (sentenceIdx, sentenceChunk) in sentenceChunks.enumerated() {
                        chunks.append(Chunk(
                            text: sentenceChunk.text,
                            metadata: ChunkMetadata(
                                index: chunks.count,
                                startPosition: baseOffset + sentenceChunk.metadata.startPosition,
                                endPosition: baseOffset + sentenceChunk.metadata.endPosition,
                                hasOverlapWithPrevious: chunks.count > 0,
                                hasOverlapWithNext: sentenceIdx < sentenceChunks.count - 1 || idx < sections.count - 1,
                                contentType: .markdown,
                                source: nil
                            )
                        ))
                    }
                } catch {
                    throw ChunkingHelper.wrapChunkingError(
                        error,
                        strategyName: "SemanticChunker.markdown (fallback to SentenceChunker for oversized section)"
                    )
                }
            }

            if currentSize + sectionSize > config.chunkSize && !currentSections.isEmpty {
                flushMarkdownSections(
                    from: currentSections,
                    to: &chunks,
                    text: text,
                    config: config,
                    hasNext: idx < sections.count - 1
                )

                if config.overlapSize > 0 && idx < sections.count - 1 {
                    let sectionTexts = currentSections.map { $0.section }
                    let overlap = ChunkingHelper.calculateOverlap(
                        sectionTexts,
                        targetSize: config.overlapSize,
                        separator: ChunkingHelper.Constants.paragraphSeparatorSize
                    )

                    if !overlap.segments.isEmpty {
                        currentSections = Array(currentSections.suffix(overlap.segments.count))
                        currentSize = overlap.size
                    } else {
                        currentSections = []
                        currentSize = 0
                    }
                } else {
                    currentSections = []
                    currentSize = 0
                }
            }

            currentSections.append(sectionData)
            currentSize += sectionSize + (currentSections.count > 1 ? ChunkingHelper.Constants.paragraphSeparatorSize : 0)
        }

        if !currentSections.isEmpty {
            flushMarkdownSections(
                from: currentSections,
                to: &chunks,
                text: text,
                config: config,
                hasNext: false
            )
        }

        return chunks
    }

    // MARK: - Mixed Content Chunking

    private func chunkMixed(text: String, config: ChunkingConfig) throws -> [Chunk] {
        // Detect code blocks and split accordingly
        let segments = separateCodeAndProse(text)

        var chunks: [Chunk] = []

        for (segmentIdx, segment) in segments.enumerated() {
            let segmentConfig = ChunkingConfig(
                chunkSize: config.chunkSize,
                overlapPercentage: config.overlapPercentage,
                strategy: config.strategy,
                contentType: segment.isCode ? .code : .prose
            )

            let segmentChunks: [Chunk]
            do {
                segmentChunks = try chunk(text: segment.content, config: segmentConfig)
            } catch {
                throw ChunkingHelper.wrapChunkingError(
                    error,
                    strategyName: "SemanticChunker.mixed (segment: \(segment.isCode ? "code" : "prose"))"
                )
            }
            let baseOffset = text.distance(from: text.startIndex, to: segment.range.lowerBound)

            for (chunkIdx, segmentChunk) in segmentChunks.enumerated() {
                let isLastChunkOfLastSegment = segmentIdx == segments.count - 1 && chunkIdx == segmentChunks.count - 1
                let adjustedMetadata = ChunkMetadata(
                    index: chunks.count,
                    startPosition: baseOffset + segmentChunk.metadata.startPosition,
                    endPosition: baseOffset + segmentChunk.metadata.endPosition,
                    hasOverlapWithPrevious: segmentChunk.metadata.hasOverlapWithPrevious,
                    hasOverlapWithNext: !isLastChunkOfLastSegment,
                    contentType: segment.isCode ? .code : .prose,
                    source: nil
                )
                chunks.append(Chunk(text: segmentChunk.text, metadata: adjustedMetadata))
            }
        }

        return chunks
    }

    // MARK: - Helper Methods

    private func flushCodeBlock(
        from lines: [(line: String, range: Range<String.Index>)],
        to chunks: inout [Chunk],
        text: String,
        config: ChunkingConfig,
        hasNext: Bool
    ) {
        guard let chunk = ChunkingHelper.createChunkFromSegments(
            segments: lines,
            separator: ChunkingHelper.Constants.lineSeparator,
            textExtractor: { $0.line },
            rangeExtractor: { $0.range },
            text: text,
            chunks: chunks,
            config: config,
            hasNext: hasNext
        ) else {
            return
        }
        chunks.append(chunk)
    }

    private func flushMarkdownSections(
        from sections: [(section: String, range: Range<String.Index>)],
        to chunks: inout [Chunk],
        text: String,
        config: ChunkingConfig,
        hasNext: Bool
    ) {
        guard let chunk = ChunkingHelper.createChunkFromSegments(
            segments: sections,
            separator: ChunkingHelper.Constants.paragraphSeparator,
            textExtractor: { $0.section },
            rangeExtractor: { $0.range },
            text: text,
            chunks: chunks,
            config: config,
            hasNext: hasNext
        ) else {
            return
        }
        chunks.append(chunk)
    }

    private func splitOversizedBlock(
        block: [(line: String, range: Range<String.Index>)],
        text: String,
        config: ChunkingConfig,
        chunks: inout [Chunk],
        hasMoreBlocks: Bool
    ) {
        var lineChunk: [(line: String, range: Range<String.Index>)] = []
        var lineChunkSize = 0

        for (lineIdx, line) in block.enumerated() {
            let lineSize = line.line.count
            if lineChunkSize + lineSize > config.chunkSize && !lineChunk.isEmpty {
                // Flush accumulated lines
                if let chunk = ChunkingHelper.createChunkFromSegments(
                    segments: lineChunk,
                    separator: ChunkingHelper.Constants.lineSeparator,
                    textExtractor: { $0.line },
                    rangeExtractor: { $0.range },
                    text: text,
                    chunks: chunks,
                    config: config,
                    hasNext: lineIdx < block.count - 1 || hasMoreBlocks
                ) {
                    chunks.append(chunk)
                }
                lineChunk = []
                lineChunkSize = 0
            }
            lineChunk.append(line)
            lineChunkSize += lineSize + (lineChunk.count > 1 ? ChunkingHelper.Constants.lineSeparatorSize : 0)
        }

        // Flush remaining lines
        if !lineChunk.isEmpty,
           let chunk = ChunkingHelper.createChunkFromSegments(
               segments: lineChunk,
               separator: ChunkingHelper.Constants.lineSeparator,
               textExtractor: { $0.line },
               rangeExtractor: { $0.range },
               text: text,
               chunks: chunks,
               config: config,
               hasNext: hasMoreBlocks
           ) {
            chunks.append(chunk)
        }
    }

    private func createChunk(
        text: String,
        index: Int,
        position: ChunkPosition,
        config: ChunkingConfig,
        hasNext: Bool
    ) -> Chunk {
        return ChunkingHelper.createChunk(
            text: text,
            index: index,
            startPosition: position.start,
            endPosition: position.end,
            config: config,
            hasNext: hasNext
        )
    }
}

// MARK: - Private Types
private extension SemanticChunker {
    struct ContentSegment {
        let content: String
        let range: Range<String.Index>
        let isCode: Bool
    }

    struct ChunkPosition {
        let start: Int
        let end: Int
    }
}

// MARK: - Text Extraction Helpers
private extension SemanticChunker {
    func splitLinesWithRanges(from text: String) -> [(line: String, range: Range<String.Index>)] {
        var result: [(line: String, range: Range<String.Index>)] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byLines) { line, range, _, _ in
            if let line = line {
                result.append((line, range))
            }
        }
        return result
    }

    func groupCodeIntoLogicalBlocks(
        _ lines: [(line: String, range: Range<String.Index>)]
    ) -> [[(line: String, range: Range<String.Index>)]] {
        var blocks: [[(line: String, range: Range<String.Index>)]] = []
        var currentBlock: [(line: String, range: Range<String.Index>)] = []

        for lineData in lines {
            if lineData.line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !currentBlock.isEmpty {
                    blocks.append(currentBlock)
                    currentBlock = []
                }
            } else {
                currentBlock.append(lineData)
            }
        }

        if !currentBlock.isEmpty {
            blocks.append(currentBlock)
        }

        return blocks.isEmpty ? [lines] : blocks
    }

    func extractMarkdownSections(from text: String) -> [(section: String, range: Range<String.Index>)] {
        let lines = splitLinesWithRanges(from: text)
        var sections: [(section: String, range: Range<String.Index>)] = []
        var currentSection: [(line: String, range: Range<String.Index>)] = []

        for lineData in lines {
            if lineData.line.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                if !currentSection.isEmpty,
                   let firstRange = currentSection.first?.range,
                   let lastRange = currentSection.last?.range {
                    let sectionText = currentSection.map { $0.line }.joined(separator: ChunkingHelper.Constants.lineSeparator)
                    sections.append((sectionText, firstRange.lowerBound..<lastRange.upperBound))
                }
                currentSection = [lineData]
            } else {
                currentSection.append(lineData)
            }
        }

        if !currentSection.isEmpty,
           let firstRange = currentSection.first?.range,
           let lastRange = currentSection.last?.range {
            let sectionText = currentSection.map { $0.line }.joined(separator: "\n")
            sections.append((sectionText, firstRange.lowerBound..<lastRange.upperBound))
        }

        return sections.isEmpty
            ? [(text, text.startIndex..<text.endIndex)]
            : sections
    }

    func separateCodeAndProse(_ text: String) -> [ContentSegment] {
        var segments: [ContentSegment] = []
        var currentContent: [(line: String, range: Range<String.Index>)] = []
        var inCodeBlock = false

        let lines = splitLinesWithRanges(from: text)

        for lineData in lines {
            if lineData.line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                // Save current segment
                if !currentContent.isEmpty,
                   let firstRange = currentContent.first?.range,
                   let lastRange = currentContent.last?.range {
                    segments.append(ContentSegment(
                        content: currentContent.map { $0.line }.joined(separator: ChunkingHelper.Constants.lineSeparator),
                        range: firstRange.lowerBound..<lastRange.upperBound,
                        isCode: inCodeBlock
                    ))
                    currentContent = []
                }
                inCodeBlock.toggle()
                // Don't include the fence line in content
            } else {
                currentContent.append(lineData)
            }
        }

        if !currentContent.isEmpty,
           let firstRange = currentContent.first?.range,
           let lastRange = currentContent.last?.range {
            segments.append(ContentSegment(
                content: currentContent.map { $0.line }.joined(separator: "\n"),
                range: firstRange.lowerBound..<lastRange.upperBound,
                isCode: inCodeBlock
            ))
        }

        return segments.isEmpty
            ? [ContentSegment(content: text, range: text.startIndex..<text.endIndex, isCode: false)]
            : segments
    }
}
