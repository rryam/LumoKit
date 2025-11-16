import Foundation

/// Helper for code chunking logic
struct SemanticCodeChunker {
    func chunk(text: String, config: ChunkingConfig) throws -> [Chunk] {
        let lines = SemanticTextHelpers.splitLinesWithRanges(from: text)
        let blocks = SemanticTextHelpers.groupCodeIntoLogicalBlocks(lines)

        var chunks: [Chunk] = []
        var currentBlock: [(line: String, range: Range<String.Index>)] = []
        var currentSize = 0

        for (idx, block) in blocks.enumerated() {
            // Calculate block size without creating intermediate string
            var blockSize = 0
            for (lineIdx, lineData) in block.enumerated() {
                if lineIdx > 0 {
                    blockSize += ChunkingHelper.Constants.lineSeparatorSize
                }
                blockSize += lineData.line.count
            }

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
                    let overlapCount = min(ChunkingHelper.Constants.codeOverlapLineCount, currentBlock.count)
                    let overlapLines = currentBlock.suffix(overlapCount)
                    currentBlock = Array(overlapLines)
                    // Calculate size without creating intermediate string
                    currentSize = 0
                    for (lineIdx, lineData) in currentBlock.enumerated() {
                        if lineIdx > 0 {
                            currentSize += ChunkingHelper.Constants.lineSeparatorSize
                        }
                        currentSize += lineData.line.count
                    }
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

    private func flushCodeBlock(
        from lines: [(line: String, range: Range<String.Index>)],
        to chunks: inout [Chunk],
        text: String,
        config: ChunkingConfig,
        hasNext: Bool
    ) {
        let context = ChunkContext(config: config, chunks: chunks, hasNext: hasNext)
        let segmentParams = SegmentChunkParameters(
            segments: lines,
            separator: ChunkingHelper.Constants.lineSeparator,
            textExtractor: { $0.line },
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
                let hasMoreLines = lineIdx < block.count - 1 || hasMoreBlocks
                let context = ChunkContext(config: config, chunks: chunks, hasNext: hasMoreLines)
                let segmentParams = SegmentChunkParameters(
                    segments: lineChunk,
                    separator: ChunkingHelper.Constants.lineSeparator,
                    textExtractor: { $0.line },
                    rangeExtractor: { $0.range }
                )
                if let chunk = ChunkingHelper.createChunkFromSegments(
                    parameters: segmentParams,
                    text: text,
                    context: context
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
        if !lineChunk.isEmpty {
            let context = ChunkContext(config: config, chunks: chunks, hasNext: hasMoreBlocks)
            let segmentParams = SegmentChunkParameters(
                segments: lineChunk,
                separator: ChunkingHelper.Constants.lineSeparator,
                textExtractor: { $0.line },
                rangeExtractor: { $0.range }
            )
            if let chunk = ChunkingHelper.createChunkFromSegments(
                parameters: segmentParams,
                text: text,
                context: context
            ) {
                chunks.append(chunk)
            }
        }
    }
}
