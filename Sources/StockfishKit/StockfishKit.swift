import CStockfish
import Foundation

public struct StockfishPosition: Sendable, Equatable {
    public static let startingFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    public static let startpos = StockfishPosition()

    public let fen: String
    public let moves: [String]

    public init(fen: String = Self.startingFEN, moves: [String] = []) {
        self.fen = fen
        self.moves = moves
    }
}

public struct StockfishSearchLimits: Sendable, Equatable {
    public var depth: Int?
    public var mate: Int?
    public var nodes: UInt64?
    public var moveTimeMilliseconds: Int?
    public var whiteTimeMilliseconds: Int?
    public var blackTimeMilliseconds: Int?
    public var whiteIncrementMilliseconds: Int?
    public var blackIncrementMilliseconds: Int?
    public var movesToGo: Int?

    public init(
        depth: Int? = nil,
        mate: Int? = nil,
        nodes: UInt64? = nil,
        moveTimeMilliseconds: Int? = nil,
        whiteTimeMilliseconds: Int? = nil,
        blackTimeMilliseconds: Int? = nil,
        whiteIncrementMilliseconds: Int? = nil,
        blackIncrementMilliseconds: Int? = nil,
        movesToGo: Int? = nil
    ) {
        self.depth = depth
        self.mate = mate
        self.nodes = nodes
        self.moveTimeMilliseconds = moveTimeMilliseconds
        self.whiteTimeMilliseconds = whiteTimeMilliseconds
        self.blackTimeMilliseconds = blackTimeMilliseconds
        self.whiteIncrementMilliseconds = whiteIncrementMilliseconds
        self.blackIncrementMilliseconds = blackIncrementMilliseconds
        self.movesToGo = movesToGo
    }

    public static func depth(_ value: Int) -> Self {
        .init(depth: value)
    }

    public static func moveTime(_ milliseconds: Int) -> Self {
        .init(moveTimeMilliseconds: milliseconds)
    }

    fileprivate func makeBridgeValue() -> stockfish_search_limits_t {
        stockfish_search_limits_t(
            depth: Int32(depth ?? 0),
            mate: Int32(mate ?? 0),
            nodes: nodes ?? 0,
            move_time_ms: Int32(moveTimeMilliseconds ?? 0),
            white_time_ms: Int32(whiteTimeMilliseconds ?? 0),
            black_time_ms: Int32(blackTimeMilliseconds ?? 0),
            white_increment_ms: Int32(whiteIncrementMilliseconds ?? 0),
            black_increment_ms: Int32(blackIncrementMilliseconds ?? 0),
            moves_to_go: Int32(movesToGo ?? 0)
        )
    }
}

public enum StockfishScore: Sendable, Equatable {
    case centipawns(Int)
    case mate(Int)
}

public struct StockfishSearchInfo: Sendable {
    public let depth: Int
    public let selectiveDepth: Int?
    public let multipv: Int?
    public let score: StockfishScore
    public let bound: String?
    public let wdl: (win: Int, draw: Int, loss: Int)?
    public let timeMilliseconds: Int?
    public let nodes: Int?
    public let nodesPerSecond: Int?
    public let tablebaseHits: Int?
    public let hashfull: Int?
    public let principalVariation: String?

    fileprivate init(_ bridgeValue: stockfish_search_info_t) {
        depth = Int(bridgeValue.depth)
        selectiveDepth = bridgeValue.seldepth > 0 ? Int(bridgeValue.seldepth) : nil
        multipv = bridgeValue.multipv > 0 ? Int(bridgeValue.multipv) : nil
        score = bridgeValue.mate != 0 ? .mate(Int(bridgeValue.mate)) : .centipawns(Int(bridgeValue.score_cp))
        bound = bridgeValue.bound.flatMap { String(validatingCString: $0) }.flatMap { $0.isEmpty ? nil : $0 }
        wdl = Self.parseWDL(bridgeValue.wdl.flatMap { String(validatingCString: $0) })
        timeMilliseconds = bridgeValue.time_ms > 0 ? Int(bridgeValue.time_ms) : nil
        nodes = bridgeValue.nodes > 0 ? Int(bridgeValue.nodes) : nil
        nodesPerSecond = bridgeValue.nps > 0 ? Int(bridgeValue.nps) : nil
        tablebaseHits = bridgeValue.tbhits > 0 ? Int(bridgeValue.tbhits) : nil
        hashfull = bridgeValue.hashfull > 0 ? Int(bridgeValue.hashfull) : nil
        principalVariation = bridgeValue.pv.flatMap { String(validatingCString: $0) }.flatMap { $0.isEmpty ? nil : $0 }
    }

    private static func parseWDL(_ value: String?) -> (win: Int, draw: Int, loss: Int)? {
        guard let value else { return nil }
        let parts = value.split(separator: " ").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return (parts[0], parts[1], parts[2])
    }
}

public struct StockfishSearchResult: Sendable {
    public let bestMove: String
    public let ponderMove: String?
    public let lastInfo: StockfishSearchInfo?
}

public enum StockfishError: Error, Sendable, LocalizedError, Equatable {
    case initializationFailed
    case engineFailure(String)
    case searchCancelled

    public var errorDescription: String? {
        switch self {
        case .initializationFailed:
            return "Failed to initialize Stockfish."
        case let .engineFailure(message):
            return message
        case .searchCancelled:
            return "The search was cancelled."
        }
    }
}

public actor StockfishEngine {
    public typealias InfoHandler = @Sendable (StockfishSearchInfo) -> Void

    private let engineHandle: EngineHandle

    public init() throws {
        guard let handle = stockfish_engine_create() else {
            throw StockfishError.initializationFailed
        }

        self.engineHandle = EngineHandle(handle)
    }

    deinit {
        stockfish_engine_destroy(engineHandle.rawValue)
    }

    public func setOption(name: String, value: String) throws {
        let success = name.withCString { namePointer in
            value.withCString { valuePointer in
                stockfish_engine_set_option(engineHandle.rawValue, namePointer, valuePointer)
            }
        }

        guard success else {
            throw currentError()
        }
    }

    public func setHashSize(_ megabytes: Int) throws {
        try setOption(name: "Hash", value: String(megabytes))
    }

    public func setThreads(_ count: Int) throws {
        try setOption(name: "Threads", value: String(count))
    }

    public func setPosition(_ position: StockfishPosition) throws {
        let movePointers = position.moves.map { strdup($0) }
        let handle = engineHandle.rawValue
        let success: Bool = position.fen.utf8CString.withUnsafeBufferPointer { fenBuffer in
            defer {
                for pointer in movePointers {
                    free(pointer)
                }
            }

            let constPointers = movePointers.map { pointer in
                pointer.map { UnsafePointer<CChar>($0) }
            }

            return constPointers.withUnsafeBufferPointer { buffer in
                stockfish_engine_set_position(
                    handle,
                    fenBuffer.baseAddress,
                    buffer.baseAddress,
                    buffer.count
                )
            }
        }

        guard success else {
            throw currentError()
        }
    }

    public func setPosition(fen: String, moves: [String] = []) throws {
        try setPosition(StockfishPosition(fen: fen, moves: moves))
    }

    public func search(
        limits: StockfishSearchLimits,
        onInfo: InfoHandler? = nil
    ) async throws -> StockfishSearchResult {
        let stateBox = SearchStateBox()
        let handle = engineHandle

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let searchState = SearchState(continuation: continuation, onInfo: onInfo)
                stateBox.state = searchState

                let opaqueState = Unmanaged.passRetained(searchState).toOpaque()

                Task.detached(priority: .userInitiated) {
                    var bridgeLimits = limits.makeBridgeValue()
                    let succeeded = stockfish_engine_search(
                        handle.rawValue,
                        &bridgeLimits,
                        stockfish_info_callback,
                        stockfish_bestmove_callback,
                        opaqueState
                    )

                    let state = Unmanaged<SearchState>.fromOpaque(opaqueState).takeRetainedValue()

                    if state.isCancelled {
                        state.finish(with: .failure(StockfishError.searchCancelled))
                        return
                    }

                    if succeeded {
                        state.finish(with: .success(state.result))
                    } else {
                        let message = currentErrorMessage(handle.rawValue) ?? "Stockfish search failed."
                        state.finish(with: .failure(StockfishError.engineFailure(message)))
                    }
                }
            }
        } onCancel: {
            stateBox.state?.markCancelled()
            stockfish_engine_stop(handle.rawValue)
        }
    }

    public func bestMove(
        in position: StockfishPosition,
        limits: StockfishSearchLimits = .depth(12),
        onInfo: InfoHandler? = nil
    ) async throws -> StockfishSearchResult {
        try setPosition(position)
        return try await search(limits: limits, onInfo: onInfo)
    }

    public func bestMove(
        fen: String,
        moves: [String] = [],
        limits: StockfishSearchLimits = .depth(12),
        onInfo: InfoHandler? = nil
    ) async throws -> StockfishSearchResult {
        try await bestMove(
            in: StockfishPosition(fen: fen, moves: moves),
            limits: limits,
            onInfo: onInfo
        )
    }

    public func stop() {
        stockfish_engine_stop(engineHandle.rawValue)
    }

    private func currentError() -> StockfishError {
        StockfishError.engineFailure(currentErrorMessage(engineHandle.rawValue) ?? "Stockfish operation failed.")
    }
}

private final class EngineHandle: @unchecked Sendable {
    let rawValue: OpaquePointer

    init(_ rawValue: OpaquePointer) {
        self.rawValue = rawValue
    }
}

private final class SearchStateBox: @unchecked Sendable {
    var state: SearchState?
}

private final class SearchState: @unchecked Sendable {
    private let lock = NSLock()
    private let continuation: CheckedContinuation<StockfishSearchResult, Error>
    private let onInfo: StockfishEngine.InfoHandler?

    private(set) var isCancelled = false
    private var hasFinished = false
    private var latestInfo: StockfishSearchInfo?
    private var bestMove: String?
    private var ponderMove: String?

    init(
        continuation: CheckedContinuation<StockfishSearchResult, Error>,
        onInfo: StockfishEngine.InfoHandler?
    ) {
        self.continuation = continuation
        self.onInfo = onInfo
    }

    var result: StockfishSearchResult {
        lock.lock()
        defer { lock.unlock() }

        return StockfishSearchResult(
            bestMove: bestMove ?? "",
            ponderMove: ponderMove,
            lastInfo: latestInfo
        )
    }

    func updateInfo(_ info: StockfishSearchInfo) {
        lock.lock()
        latestInfo = info
        let callback = onInfo
        lock.unlock()

        callback?(info)
    }

    func updateBestMove(bestMove: String, ponderMove: String?) {
        lock.lock()
        self.bestMove = bestMove
        self.ponderMove = ponderMove
        lock.unlock()
    }

    func markCancelled() {
        lock.lock()
        isCancelled = true
        lock.unlock()
    }

    func finish(with result: Result<StockfishSearchResult, Error>) {
        lock.lock()
        if hasFinished {
            lock.unlock()
            return
        }

        hasFinished = true
        lock.unlock()

        continuation.resume(with: result)
    }
}

private func currentErrorMessage(_ handle: OpaquePointer) -> String? {
    guard let pointer = stockfish_engine_last_error(handle) else {
        return nil
    }

    return String(validatingCString: pointer)
}

private let stockfish_info_callback: stockfish_info_callback_t = { context, bridgeInfo in
    guard let context, let bridgeInfo else { return }

    let state = Unmanaged<SearchState>.fromOpaque(context).takeUnretainedValue()
    state.updateInfo(StockfishSearchInfo(bridgeInfo.pointee))
}

private let stockfish_bestmove_callback: stockfish_bestmove_callback_t = { context, bestMove, ponderMove in
    guard let context, let bestMove else { return }

    let state = Unmanaged<SearchState>.fromOpaque(context).takeUnretainedValue()
    state.updateBestMove(
        bestMove: String(cString: bestMove),
        ponderMove: ponderMove.flatMap { String(validatingCString: $0) }.flatMap { $0.isEmpty ? nil : $0 }
    )
}
