import Foundation

/// Represents a segment of content (code or prose) with its range
struct ContentSegment {
    let content: String
    let range: Range<String.Index>
    let isCode: Bool
}

/// Text extraction and processing helpers for semantic chunking
struct SemanticTextHelpers {
    static func splitLinesWithRanges(from text: String) -> [(line: String, range: Range<String.Index>)] {
        var result: [(line: String, range: Range<String.Index>)] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byLines) { line, range, _, _ in
            if let line = line {
                result.append((line, range))
            }
        }
        return result
    }

    static func groupCodeIntoLogicalBlocks(
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

    static func extractMarkdownSections(from text: String) -> [(section: String, range: Range<String.Index>)] {
        let lines = splitLinesWithRanges(from: text)
        var sections: [(section: String, range: Range<String.Index>)] = []
        var currentSection: [(line: String, range: Range<String.Index>)] = []

        for lineData in lines {
            if lineData.line.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                if !currentSection.isEmpty,
                   let firstRange = currentSection.first?.range,
                   let lastRange = currentSection.last?.range {
                    // Build section text without intermediate array
                    var sectionText = ""
                    for (lineIdx, sectionLine) in currentSection.enumerated() {
                        if lineIdx > 0 {
                            sectionText += ChunkingHelper.Constants.lineSeparator
                        }
                        sectionText += sectionLine.line
                    }
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
            // Build section text without intermediate array
            var sectionText = ""
            for (lineIdx, sectionLine) in currentSection.enumerated() {
                if lineIdx > 0 {
                    sectionText += ChunkingHelper.Constants.lineSeparator
                }
                sectionText += sectionLine.line
            }
            sections.append((sectionText, firstRange.lowerBound..<lastRange.upperBound))
        }

        return sections.isEmpty
            ? [(text, text.startIndex..<text.endIndex)]
            : sections
    }

    static func separateCodeAndProse(_ text: String) -> [ContentSegment] {
        var segments: [ContentSegment] = []
        var currentContent: [(line: String, range: Range<String.Index>)] = []
        var inCodeBlock = false
        var unclosedFenceCount = 0

        let lines = splitLinesWithRanges(from: text)

        for lineData in lines {
            let trimmedLine = lineData.line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("```") {
                // Save current segment
                if !currentContent.isEmpty,
                   let firstRange = currentContent.first?.range,
                   let lastRange = currentContent.last?.range {
                    // Build content text without intermediate array
                    var contentText = ""
                    for (lineIdx, contentLine) in currentContent.enumerated() {
                        if lineIdx > 0 {
                            contentText += ChunkingHelper.Constants.lineSeparator
                        }
                        contentText += contentLine.line
                    }
                    segments.append(ContentSegment(
                        content: contentText,
                        range: firstRange.lowerBound..<lastRange.upperBound,
                        isCode: inCodeBlock
                    ))
                    currentContent = []
                }
                // Track fence depth - only toggle on properly matched pairs
                unclosedFenceCount += 1
                if unclosedFenceCount >= 2 {
                    inCodeBlock.toggle()
                    unclosedFenceCount = 0
                }
                // Don't include the fence line in content
            } else {
                currentContent.append(lineData)
            }
        }

        // Handle any remaining content
        if !currentContent.isEmpty,
           let firstRange = currentContent.first?.range,
           let lastRange = currentContent.last?.range {
            // Build content text without intermediate array
            var contentText = ""
            for (lineIdx, contentLine) in currentContent.enumerated() {
                if lineIdx > 0 {
                    contentText += ChunkingHelper.Constants.lineSeparator
                }
                contentText += contentLine.line
            }
            // If there's an unclosed fence, treat remaining as prose (malformed markdown)
            let isCode = inCodeBlock && unclosedFenceCount == 0
            segments.append(ContentSegment(
                content: contentText,
                range: firstRange.lowerBound..<lastRange.upperBound,
                isCode: isCode
            ))
        }

        return segments.isEmpty
            ? [ContentSegment(content: text, range: text.startIndex..<text.endIndex, isCode: false)]
            : segments
    }
}
