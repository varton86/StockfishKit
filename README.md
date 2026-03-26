# StockfishKit

[![CI](https://github.com/YOUR_ORG/StockfishKit/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_ORG/StockfishKit/actions/workflows/ci.yml)
[![Version](https://img.shields.io/github/v/tag/YOUR_ORG/StockfishKit?label=version)](https://github.com/YOUR_ORG/StockfishKit/releases)
[![License](https://img.shields.io/badge/license-GPL--3.0--or--later-blue.svg)](https://github.com/YOUR_ORG/StockfishKit/blob/main/LICENSE)

`StockfishKit` is a Swift Package for iOS apps that vendors the official Stockfish engine and exposes an async Swift API on top of it.

## Installation

### Xcode

In Xcode, open `File` -> `Add Package Dependencies...` and paste your repository URL:

```text
https://github.com/YOUR_ORG/StockfishKit.git
```

Choose the dependency rule `Up to Next Major Version` and set the version to:

```text
0.1.0
```

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/YOUR_ORG/StockfishKit.git", from: "0.1.0")
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

## Notes

- This package vendors Stockfish from the official repository.
- Stockfish is licensed under GPL-3.0-or-later, so applications distributing this package need to comply with that license.
- The vendored source in this repository was taken from `official-stockfish/Stockfish` at commit `d173a0655d04b95497eefb75b400baa3eff56f93`.
- Suggested first release tag: `v0.1.0`.

## Publishing Checklist

1. Replace every `YOUR_ORG` placeholder in this README with your GitHub owner or organization.
2. Push `main` and the `v0.1.0` tag to GitHub.
3. Open GitHub Releases and create the first release from tag `v0.1.0`.
4. Paste the template from `.github/release-template.md` into the release notes and adjust the repository URL examples if needed.
