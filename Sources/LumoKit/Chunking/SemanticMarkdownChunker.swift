import Foundation

/// Helper for markdown chunking logic
struct SemanticMarkdownChunker {
    func chunk(text: String, config: ChunkingConfig) throws -> [Chunk] {
        let sections = SemanticTextHelpers.extractMarkdownSections(from: text)

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
                continue
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
            let separatorSize = currentSections.count > 1 ? ChunkingHelper.Constants.paragraphSeparatorSize : 0
            currentSize += sectionSize + separatorSize
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

    private func flushMarkdownSections(
        from sections: [(section: String, range: Range<String.Index>)],
        to chunks: inout [Chunk],
        text: String,
        config: ChunkingConfig,
        hasNext: Bool
    ) {
        let context = ChunkContext(config: config, chunks: chunks, hasNext: hasNext)
        let segmentParams = SegmentChunkParameters(
            segments: sections,
            separator: ChunkingHelper.Constants.paragraphSeparator,
            textExtractor: { $0.section },
            rangeExtractor: { $0.range }
        )
        guard let chunk = ChunkingHelper.createChunkFromSegments(
            parameters: segmentParams,
            text: text,
            context: context
        ) else {
            return
        }
        chunks.append(chunk)
    }
}
