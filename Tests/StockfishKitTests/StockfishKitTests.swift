import XCTest
@testable import StockfishKit

final class StockfishKitTests: XCTestCase {
    func testSearchReturnsMoveFromStartingPosition() async throws {
        let engine = try StockfishEngine()
        let result = try await engine.bestMove(in: .startpos, limits: .depth(1))

        XCTAssertFalse(result.bestMove.isEmpty)
    }
}
