import XCTest
@testable import ConnectivityAndInternetAccess

final class NetworkStateTests: XCTestCase {

    func testNetworkStateInitialization() {
        let state = NetworkState(
            isConnected: true,
            interfaceType: .wifi,
            isExpensive: false,
            isConstrained: false,
            isInternetValidated: true,
            isCaptivePortalDetected: false
        )

        XCTAssertTrue(state.isConnected)
        XCTAssertEqual(state.interfaceType, .wifi)
        XCTAssertFalse(state.isExpensive)
        XCTAssertFalse(state.isConstrained)
        XCTAssertTrue(state.isInternetValidated)
        XCTAssertFalse(state.isCaptivePortalDetected)
    }

    func testOfflineStateHelper() {
        let offline = NetworkState.offline
        XCTAssertFalse(offline.isConnected)
        XCTAssertEqual(offline.interfaceType, .unknown)
        XCTAssertFalse(offline.isInternetValidated)
        XCTAssertFalse(offline.isCaptivePortalDetected)
    }

    func testNetworkStateEquatable() {
        let now = Date()
        let state1 = NetworkState(isConnected: true, interfaceType: .wifi, timestamp: now)
        let state2 = NetworkState(isConnected: true, interfaceType: .wifi, timestamp: now)
        let state3 = NetworkState(isConnected: false, interfaceType: .cellular, timestamp: now)

        XCTAssertEqual(state1, state2)
        XCTAssertNotEqual(state1, state3)
    }

    func testCodableConformity() throws {
        let originalState = NetworkState(
            isConnected: true,
            interfaceType: .cellular,
            isExpensive: true,
            isConstrained: true,
            isInternetValidated: false,
            isCaptivePortalDetected: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalState)

        let decoder = JSONDecoder()
        let decodedState = try decoder.decode(NetworkState.self, from: data)

        XCTAssertEqual(originalState.isConnected, decodedState.isConnected)
        XCTAssertEqual(originalState.interfaceType, decodedState.interfaceType)
        XCTAssertEqual(originalState.isExpensive, decodedState.isExpensive)
        XCTAssertEqual(originalState.isConstrained, decodedState.isConstrained)
        XCTAssertEqual(originalState.isInternetValidated, decodedState.isInternetValidated)
        XCTAssertEqual(originalState.isCaptivePortalDetected, decodedState.isCaptivePortalDetected)
    }
}
