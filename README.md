# LumoKit

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
  - [1. Configure VecturaKit and initialize LumoKit](#1-configure-vectorakit-and-initialize-lumokit)
  - [2. Parse a file and index its contents](#2-parse-a-file-and-index-its-contents)
  - [3. Run semantic search queries](#3-run-semantic-search-queries)
  - [4. Reset the database when needed](#4-reset-the-database-when-needed)
- [Examples](#examples)
  - [Index a single file](#index-a-single-file)
  - [Index multiple files in a folder](#index-multiple-files-in-a-folder)
  - [Parse without indexing](#parse-without-indexing)
  - [Custom storage location](#custom-storage-location)
  - [Handling errors](#handling-errors)
- [Error Handling](#error-handling)
- [Tips](#tips)
- [Contributing](#contributing)
- [License](#license)

## Features

- **Document Parsing:** Uses PicoDocs to fetch and convert local files (PDF, Markdown, HTML, and more) into structured text.
- **Chunking Pipeline:** Splits parsed text into configurable segments ideal for retrieval.
- **Semantic Search:** Leverages VecturaKit’s vector database to score and rank relevant passages.
- **Async-First API:** All indexing and search operations are async, ready for Swift concurrency.
- **Database Management:** Reset or re-index data stores without leaving the app.

## API Overview

```swift
public final class LumoKit {
    public init(config: VecturaConfig) throws

    public func parseAndIndex(url: URL, chunkSize: Int = 500) async throws
    public func parseDocument(from url: URL, chunkSize: Int = 500) async throws -> [String]
    public func chunkText(_ text: String, size: Int) throws -> [String]

    public func semanticSearch(
        query: String,
        numResults: Int = 5,
        threshold: Float = 0.7
    ) async throws -> [VecturaSearchResult]

    public func resetDB() async throws
}

public enum LumoKitError: Error {
    case emptyDocument
    case invalidChunkSize
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
    .package(url: "https://github.com/rryam/LumoKit.git", from: "0.1.0")
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

### 1. Configure VecturaKit and initialize LumoKit

```swift
import LumoKit
import VecturaKit

let config = VecturaConfig(
    name: "knowledge-base",
    searchOptions: .init(
        defaultNumResults: 10,
        minThreshold: 0.7
    )
)

let lumoKit = try await LumoKit(config: config)
```

### 2. Parse a file and index its contents

```swift
let url = URL(fileURLWithPath: "/path/to/document.pdf")
try await lumoKit.parseAndIndex(url: url, chunkSize: 600)
```

### 3. Run semantic search queries

```swift
let results = try await lumoKit.semanticSearch(
    query: "Explain vector databases",
    numResults: 5,
    threshold: 0.65
)

for result in results {
    print(result.text)
}
```

### 4. Reset the database when needed

```swift
try await lumoKit.resetDB()
```

## Examples

### Index a single file

```swift
let url = URL(fileURLWithPath: "/path/to/notes.md")
try await lumoKit.parseAndIndex(url: url, chunkSize: 500)
```

### Index multiple files in a folder

```swift
let folder = URL(fileURLWithPath: "/path/to/docs")
let fileManager = FileManager.default
let exts: Set<String> = ["pdf", "md", "markdown", "html", "txt"]

if let urls = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
    for url in urls where exts.contains(url.pathExtension.lowercased()) {
        try await lumoKit.parseAndIndex(url: url, chunkSize: 600)
    }
}
```

### Parse without indexing

```swift
let url = URL(fileURLWithPath: "/path/to/paper.pdf")
let chunks = try await lumoKit.parseDocument(from: url, chunkSize: 400)
print("chunks: \(chunks.count)")
```

### Custom storage location

```swift
import VecturaKit

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

### Handling errors

```swift
do {
    _ = try await lumoKit.parseDocument(from: URL(fileURLWithPath: "/empty.pdf"), chunkSize: 0)
} catch LumoKitError.invalidChunkSize {
    print("invalid chunk size")
} catch LumoKitError.emptyDocument {
    print("no content to parse")
} catch {
    print("unexpected error: \(error)")
}
```

## Error Handling

`LumoKitError` reports invalid states:
- `.emptyDocument` – parsing produced no text content.
- `.invalidChunkSize` – chunk size must be greater than zero.

Handle these cases to surface actionable messages to users or diagnostics.

## Tips

- Adjust `chunkSize` depending on the model’s context window; larger chunks improve coherence, smaller chunks improve specificity.
- Provide a custom `directoryURL` in `VecturaConfig` to store the vector database in a shared app container.
- Combine LumoKit with a language model to build a full RAG stack for summaries, answering questions, or chat experiences.

## Contributing

Contributions are welcome! Open an issue or submit a pull request with improvements.

## License

LumoKit is available under the MIT license. See the [LICENSE](LICENSE) file for details.
