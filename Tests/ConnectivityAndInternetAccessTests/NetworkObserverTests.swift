import XCTest
@testable import ConnectivityAndInternetAccess

final class NetworkObserverTests: XCTestCase {

    func testSnapshotNetworkStateReturnsValidObject() {
        let observer = NetworkObserver()
        let snapshot = observer.snapshotNetworkState()
        XCTAssertNotNil(snapshot)
    }

    func testObserveNetworkDeliversInitialState() {
        let observer = NetworkObserver()
        let expectation = XCTestExpectation(description: "Initial passive state delivered")

        var receivedState: NetworkState? = nil
        let token = observer.observeNetwork { state in
            receivedState = state
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(receivedState)

        token.close()
        XCTAssertTrue(token.isCancelled)
    }

    func testTokenCancellationIdempotency() {
        var cancelCount = 0
        let token = NetworkObserverToken {
            cancelCount += 1
        }

        XCTAssertFalse(token.isCancelled)
        token.cancel()
        XCTAssertTrue(token.isCancelled)

        // Multiple calls to cancel should be idempotent
        token.cancel()
        token.close()
        XCTAssertEqual(cancelCount, 1)
    }
}
