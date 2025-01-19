# LumoKit

LumoKit is a lightweight Swift library for **Retrieval-Augmented Generation (RAG)** systems. It integrates with **PicoDocs** for document parsing and **VecturaKit** for semantic search and vector storage.

The name **LumoKit** is derived from the Chinese characters **流** (*liú*) meaning "flow" and **模** (*mó*) meaning "model." It symbolizes the idea of **flowing information through a model**, reflecting data retrieval for a large language model.

## Key Features

- **Parse and Chunk Documents**: Use `PicoDocs` to extract content from files and split them into manageable chunks for efficient indexing.
- **Semantic Search**: Perform similarity-based searches using `VecturaKit`'s vector database.
- **Configurable Document Indexing**: Set custom chunk sizes to control how documents are segmented for retrieval.
- **Reset Database**: Quickly reset the vector database to start fresh with new data.

---

## Installation

Add the following dependencies to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/rryam/LumoKit.git", from: "0.1.0"),
],
```

Then import the package in your project:

```swift
import LumoKit
```

## Usage

1. Initialize LumoKit

First, set up the configuration for VecturaKit and initialize LumoKit:

```swift
import LumoKit
import VecturaKit

let config = VecturaConfig(
    name: "my-vector-db",
    dimension: 384,
    searchOptions: VecturaConfig.SearchOptions(
        defaultNumResults: 10,
        minThreshold: 0.7
    )
)

let lumoKit = try LumoKit(config: config)
```

2. Parse and Index Documents

Parse a file and index its content into the vector database:

```swift
let fileURL = URL(fileURLWithPath: "/path/to/your/document.pdf")
try await lumoKit.parseAndIndex(url: fileURL, chunkSize: 500)
```

3. Perform Semantic Search

Search for relevant documents by querying the indexed database:

```swift
let results = try await lumoKit.semanticSearch(query: "What is Swift?", numResults: 5, threshold: 0.7)

for result in results {
    print("Document ID: \(result.id)")
    print("Text: \(result.text)")
    print("Score: \(result.score)")
}
```

## How It Works
- Document Parsing: Leverages PicoDocs to parse various file formats (e.g., PDF, Markdown).
- Chunking: Splits the content into smaller chunks for efficient indexing.
- Vector Storage: Uses VecturaKit to store embeddings and perform similarity searches.
- Semantic Search: Retrieves the most relevant chunks for a given query.

## Example Workflow

```swift
let fileURL = URL(fileURLWithPath: "/path/to/document.pdf")

// Parse and index document
try await lumoKit.parseAndIndex(url: fileURL, chunkSize: 500)

// Perform semantic search
let query = "Explain the importance of vector databases."
let results = try await lumoKit.semanticSearch(query: query)

for result in results {
    print("Relevant Text: \(result.text)")
}

// Reset the database
try await lumoKit.resetDB()
```

## Contributing
Contributions are welcome! Please fork the repository and submit a pull request with your improvements or suggestions.

## License 
LumoKit is licensed under the MIT License. See the LICENSE file for more details.

## Acknowledgments
- PicoDocs: For powerful document parsing.
- VecturaKit: For robust vector database functionality.
