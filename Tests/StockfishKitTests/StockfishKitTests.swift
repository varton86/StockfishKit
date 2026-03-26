import XCTest
@testable import StockfishKit

final class StockfishKitTests: XCTestCase {
    func testSearchReturnsMoveFromStartingPosition() async throws {
        let engine = try StockfishEngine()
        let result = try await engine.bestMove(in: .startpos, limits: .depth(1))

        XCTAssertFalse(result.bestMove.isEmpty)
    }

    func testSearchReturnsMoveFromCustomFENPosition() async throws {
        let engine = try StockfishEngine()
        let result = try await engine.bestMove(
            fen: "r1bqkbnr/pppp1ppp/2n5/4p3/3P4/5N2/PPP1PPPP/RNBQKB1R b KQkq - 1 3",
            limits: .depth(1)
        )

        XCTAssertFalse(result.bestMove.isEmpty)
    }
}
