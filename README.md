# LumoKit
[![Star History Chart](https://api.star-history.com/svg?repos=rryam/LumoKit&type=Date)](https://star-history.com/#rryam/LumoKit&Date)


LumoKit is a Swift package for building on-device **Retrieval-Augmented Generation (RAG)** workflows. It combines **PicoDocs** for document ingestion with **VecturaKit** for vector storage and semantic search, giving you an end-to-end pipeline for creating searchable knowledge bases.

The name **Lumo** blends the Mandarin characters **流** (*liú*, “flow”) and **模** (*mó*, “model”), representing the flow of knowledge into machine learning models.

## Learn More

Deepen your understanding of AI and iOS development with these books:
- [Exploring AI for iOS Development](https://academy.rudrank.com/product/ai)
- [Exploring AI-Assisted Coding for iOS Development](https://academy.rudrank.com/product/ai-assisted-coding)

## Table of Contents

- [Features](#features)
- [API Overview](#api-overview)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Installation](#installation)
- [Getting Started](#getting-started)
- [Chunking Strategies](#chunking-strategies)
- [Examples](#examples)
- [Error Handling](#error-handling)
- [Contributing](#contributing)
- [License](#license)

## Features

- **Document Parsing:** Parse PDFs, Markdown, HTML, and text files using PicoDocs
- **Multiple Chunking Strategies:** Sentence-based, paragraph-based, or semantic chunking with configurable overlap
- **Content-Aware:** Different handling for prose, code, markdown, and mixed content
- **Semantic Search:** Vector search powered by VecturaKit
- **Async API:** Built with Swift concurrency
- **Database Management:** Reset or re-index on demand

## API Overview

```swift
public final class LumoKit {
    public init(config: VecturaConfig, chunkingConfig: ChunkingConfig = ChunkingConfig()) async throws

    public func parseAndIndex(url: URL, chunkingConfig: ChunkingConfig? = nil) async throws
    public func parseDocument(from url: URL, chunkingConfig: ChunkingConfig? = nil) async throws -> [Chunk]

    public func chunkText(_ text: String, config: ChunkingConfig) throws -> [Chunk]

    public func semanticSearch(
        query: String,
        numResults: Int = 5,
        threshold: Float = 0.7
    ) async throws -> [VecturaSearchResult]

    public func resetDB() async throws
}

public struct ChunkingConfig {
    public let chunkSize: Int
    public let overlapPercentage: Double
    public let strategy: ChunkingStrategyType // .sentence, .paragraph, .semantic
    public let contentType: ContentType // .prose, .code, .markdown, .mixed
}

public enum LumoKitError: Error {
    case emptyDocument
    case invalidChunkSize
    case invalidURL
    case fileNotFound
    case unsupportedFileType
    case invalidSearchParameters
    case chunkingFailed(strategy: String, underlyingError: Error)
}
```

## Architecture

```
Source Document ──► PicoDocs parsing ──► LumoKit chunking ──► VecturaKit indexing ──► Semantic search
```

## Requirements

- Swift 6.2+
- iOS 18.0+, macOS 15.0+

## Installation

Add LumoKit to your `Package.swift` using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/rryam/LumoKit.git", from: "1.1.1")
]
```

Then attach the dependency to your target:

```swift
.target(
    name: "AppModule",
    dependencies: [
        .product(name: "LumoKit", package: "LumoKit")
    ]
)
```

## Getting Started

```swift
import LumoKit
import VecturaKit

// Configure vector database
let vecturaConfig = VecturaConfig(
    name: "knowledge-base",
    searchOptions: .init(
        defaultNumResults: 10,
        minThreshold: 0.7
    )
)

// Configure chunking strategy
let chunkingConfig = ChunkingConfig(
    chunkSize: 500,
    overlapPercentage: 0.15,  // 15% overlap between chunks
    strategy: .semantic,  // Content-aware chunking
    contentType: .prose  // For prose text
)

// Initialize LumoKit
let lumoKit = try await LumoKit(
    config: vecturaConfig,
    chunkingConfig: chunkingConfig
)

// Parse and index a document
let url = URL(fileURLWithPath: "/path/to/document.pdf")
try await lumoKit.parseAndIndex(url: url)

// Search
let results = try await lumoKit.semanticSearch(
    query: "Explain vector databases",
    numResults: 5,
    threshold: 0.65
)

for result in results {
    print(result.text)
}
```

## Chunking Strategies

LumoKit provides three strategies for splitting text into chunks:

### Sentence Chunking (`.sentence`)

Respects sentence boundaries using NLTokenizer. Best for general prose and question-answering systems.

```swift
let config = ChunkingConfig(
    chunkSize: 500,
    overlapPercentage: 0.15,
    strategy: .sentence,
    contentType: .prose
)
```

### Paragraph Chunking (`.paragraph`)

Keeps paragraphs together when possible. Best for documents with clear paragraph structure.

```swift
let config = ChunkingConfig(
    chunkSize: 800,
    overlapPercentage: 0.1,
    strategy: .paragraph,
    contentType: .prose
)
```

### Semantic Chunking (`.semantic`) - Recommended

Adapts to content type with specialized handling for different text types:

**For Prose:**
```swift
let config = ChunkingConfig(
    chunkSize: 600,
    strategy: .semantic,
    contentType: .prose
)
```

**For Code:**
```swift
let config = ChunkingConfig(
    chunkSize: 600,
    strategy: .semantic,
    contentType: .code  // Preserves logical code blocks
)
```

**For Markdown:**
```swift
let config = ChunkingConfig(
    chunkSize: 700,
    strategy: .semantic,
    contentType: .markdown  // Respects headers and structure
)
```

**For Mixed Content:**
```swift
let config = ChunkingConfig(
    chunkSize: 500,
    strategy: .semantic,
    contentType: .mixed  // Handles prose + code blocks
)
```

### Chunk Overlap

Configure overlap between chunks to maintain context continuity:

```swift
// High overlap (20%) - better for Q&A and semantic search
ChunkingConfig(chunkSize: 500, overlapPercentage: 0.2)

// Medium overlap (10-15%) - balanced approach
ChunkingConfig(chunkSize: 500, overlapPercentage: 0.15)

// No overlap (0%) - maximum chunk count
ChunkingConfig(chunkSize: 500, overlapPercentage: 0.0)
```

## Examples

### Index Multiple Files with Different Strategies

```swift
let urls = [
    ("paper.pdf", ContentType.prose),
    ("README.md", ContentType.markdown),
    ("main.swift", ContentType.code)
]

for (filename, contentType) in urls {
    let config = ChunkingConfig(
        chunkSize: 500,
        overlapPercentage: 0.15,
        strategy: .semantic,
        contentType: contentType
    )

    let url = URL(fileURLWithPath: filename)
    try await lumoKit.parseAndIndex(url: url, chunkingConfig: config)
}
```

### Parse Without Indexing

```swift
let url = URL(fileURLWithPath: "/path/to/paper.pdf")
let chunks = try await lumoKit.parseDocument(from: url)
print("Created \(chunks.count) chunks")

// Access chunk metadata
for chunk in chunks {
    print("Chunk \(chunk.metadata.index)")
    print("Position: \(chunk.metadata.startPosition)-\(chunk.metadata.endPosition)")
    print("Has overlap: \(chunk.metadata.hasOverlapWithPrevious)")
    print("Source: \(chunk.metadata.source ?? "unknown")")
    print("Content type: \(chunk.metadata.contentType)")
    print("Content: \(chunk.text)")
}
```

### Custom Storage Location

```swift
let supportDir = try FileManager.default.url(
    for: .applicationSupportDirectory,
    in: .userDomainMask,
    appropriateFor: nil,
    create: true
)

let config = VecturaConfig(
    name: "kb-shared",
    directoryURL: supportDir,
    searchOptions: .init(defaultNumResults: 8, minThreshold: 0.7)
)

let lumoKit = try await LumoKit(config: config)
```

### Index a Folder of Documents

```swift
let folder = URL(fileURLWithPath: "/path/to/docs")
let fileManager = FileManager.default
let exts: Set<String> = ["pdf", "md", "markdown", "html", "txt"]

do {
    let urls = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
    for url in urls where exts.contains(url.pathExtension.lowercased()) {
        do {
            try await lumoKit.parseAndIndex(url: url)
        } catch {
            print("Failed to index \(url.lastPathComponent): \(error)")
        }
    }
} catch {
    print("Error reading directory: \(error)")
}
```

## Error Handling

```swift
let url = URL(fileURLWithPath: "/path/to/document.pdf")

do {
    try await lumoKit.parseAndIndex(url: url)
} catch LumoKitError.emptyDocument {
    print("Document is empty")
} catch LumoKitError.invalidChunkSize {
    print("Invalid chunk size")
} catch LumoKitError.invalidURL {
    print("Invalid file URL")
} catch LumoKitError.fileNotFound {
    print("File not found")
} catch LumoKitError.unsupportedFileType {
    print("File type not supported")
} catch LumoKitError.invalidSearchParameters {
    print("Invalid search parameters")
} catch {
    print("Error: \(error)")
}
```

`LumoKitError` cases:
- `.emptyDocument` – parsing produced no text content
- `.invalidChunkSize` – chunk size must be greater than zero
- `.invalidURL` – the provided URL is not a valid file URL
- `.fileNotFound` – the file at the provided URL does not exist
- `.unsupportedFileType` – the file type is not supported by PicoDocs
- `.invalidSearchParameters` – search parameters are invalid (numResults <= 0 or threshold outside 0.0-1.0)
- `.chunkingFailed(strategy: String, underlyingError: Error)` – chunking failed with context about which strategy failed

## Contributing

Contributions are welcome! Open an issue or submit a pull request with improvements.

## License

LumoKit is available under the MIT license. See the [LICENSE](LICENSE) file for details.
