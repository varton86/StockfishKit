## StockfishKit v0.1.0

Initial public release of `StockfishKit`, a Swift Package that vendors the official Stockfish engine and exposes a Swift-friendly async API for Apple platforms.

### Highlights

- Vendored official Stockfish source bundled directly in the package
- Swift actor-based API for configuring the engine and searching for the best move
- Streaming search updates during analysis
- Included official NNUE networks required for out-of-the-box use
- SwiftPM-ready package for iOS and macOS projects

### Installation

```swift
dependencies: [
    .package(url: "https://github.com/YOUR_ORG/StockfishKit.git", from: "0.1.0")
]
```

### Notes

- This package includes Stockfish and is distributed under `GPL-3.0-or-later`.
- Applications shipping this package must comply with the GPL license terms.
- Vendored Stockfish commit: `d173a0655d04b95497eefb75b400baa3eff56f93`

### Verification

- `swift build`
- `swift test`
