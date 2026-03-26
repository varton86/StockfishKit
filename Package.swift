// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StockfishKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "StockfishKit",
            targets: ["StockfishKit"]
        )
    ],
    targets: [
        .target(
            name: "CStockfish",
            path: "vendor/Stockfish/src",
            exclude: [
                "Makefile",
                "main.cpp"
            ],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("."),
                .headerSearchPath("include"),
                .define("USE_PTHREADS"),
                .define("IS_64BIT"),
                .define("USE_NEON", to: "8"),
                .define("USE_NEON_DOTPROD"),
                .define("ARCH", to: "apple_silicon"),
                .unsafeFlags([
                    "-std=c++17",
                    "-fno-exceptions",
                    "-O3",
                    "-funroll-loops"
                ])
            ]
        ),
        .target(
            name: "StockfishKit",
            dependencies: ["CStockfish"],
            path: "Sources/StockfishKit"
        ),
        .testTarget(
            name: "StockfishKitTests",
            dependencies: ["StockfishKit"],
            path: "Tests/StockfishKitTests"
        )
    ],
    cxxLanguageStandard: .cxx17
)
