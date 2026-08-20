import XCTest
@testable import ConnectivityAndInternetAccess

final class TestBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T

    init(_ value: T) {
        self._value = value
    }

    var value: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            _value = newValue
            lock.unlock()
        }
    }
}

final class NetworkObserverTests: XCTestCase {

    func testSnapshotNetworkStateReturnsValidObject() {
        let observer = NetworkObserver()
        let snapshot = observer.snapshotNetworkState()
        XCTAssertNotNil(snapshot)
    }

    func testObserveNetworkDeliversInitialState() {
        let observer = NetworkObserver()
        let expectation = XCTestExpectation(description: "Initial passive state delivered")

        let stateBox = TestBox<NetworkState?>(nil)
        let token = observer.observeNetwork { state in
            stateBox.value = state
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(stateBox.value)

        token.close()
        XCTAssertTrue(token.isCancelled)
    }

    func testTokenCancellationIdempotency() {
        let cancelCountBox = TestBox<Int>(0)
        let token = NetworkObserverToken {
            cancelCountBox.value += 1
        }

        XCTAssertFalse(token.isCancelled)
        token.cancel()
        XCTAssertTrue(token.isCancelled)

        // Multiple calls to cancel should be idempotent
        token.cancel()
        token.close()
        XCTAssertEqual(cancelCountBox.value, 1)
    }
}
