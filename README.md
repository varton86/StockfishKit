# StockfishKit

[![CI](https://github.com/varton86/StockfishKit/actions/workflows/ci.yml/badge.svg)](https://github.com/varton86/StockfishKit/actions/workflows/ci.yml)
[![Version](https://img.shields.io/github/v/tag/varton86/StockfishKit?label=version)](https://github.com/varton86/StockfishKit/releases)
[![License](https://img.shields.io/badge/license-GPL--3.0--or--later-blue.svg)](https://github.com/varton86/StockfishKit/blob/main/LICENSE)

`StockfishKit` is a Swift Package for iOS apps that vendors the official Stockfish engine and exposes an async Swift API on top of it.

## Installation

### Xcode

In Xcode, open `File` -> `Add Package Dependencies...` and paste your repository URL:

```text
https://github.com/varton86/StockfishKit.git
```

Choose the dependency rule `Up to Next Major Version` and set the version to:

```text
0.1.1
```

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/varton86/StockfishKit.git", from: "0.1.1")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "StockfishKit", package: "StockfishKit")
        ]
    )
]
```

## What You Get

- A single SPM dependency you can add to your app.
- A Swift-facing `StockfishEngine` actor instead of raw UCI process management.
- Vendored Stockfish sources, so consumers do not need a post-install build step.
- Streaming search updates via `onInfo`.

## Usage

```swift
import StockfishKit

let engine = try StockfishEngine()
try engine.setThreads(2)
try engine.setHashSize(64)

let result = try await engine.bestMove(
    in: .startpos,
    limits: .depth(12)
) { info in
    print(info.depth, info.score)
}

print(result.bestMove)
```

### Custom FEN Position

```swift
import StockfishKit

let engine = try StockfishEngine()

let result = try await engine.bestMove(
    fen: "r1bqkbnr/pppp1ppp/2n5/4p3/3P4/5N2/PPP1PPPP/RNBQKB1R b KQkq - 1 3",
    limits: .depth(12)
)

print(result.bestMove)
```

You can also pass a FEN plus a move list:

```swift
try await engine.bestMove(
    fen: StockfishPosition.startingFEN,
    moves: ["e2e4", "c7c5", "g1f3"],
    limits: .depth(12)
)
```

## Notes

- This package vendors Stockfish from the official repository.
- Stockfish is licensed under GPL-3.0-or-later, so applications distributing this package need to comply with that license.
- The vendored source in this repository was taken from `official-stockfish/Stockfish` at commit `d173a0655d04b95497eefb75b400baa3eff56f93`.
