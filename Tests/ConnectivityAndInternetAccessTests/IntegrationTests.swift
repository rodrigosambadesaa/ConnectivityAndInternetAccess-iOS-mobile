import XCTest
@testable import ConnectivityAndInternetAccess

final class IntegrationTests: XCTestCase {

    func testStaticSnapshotNetworkState() {
        let state = ConnectivityAndInternetAccess.snapshotNetworkState()
        XCTAssertNotNil(state)
    }

    func testStaticObserveNetwork() {
        let expectation = XCTestExpectation(description: "Passive callback received via static helper")
        let token = ConnectivityAndInternetAccess.observeNetwork { state in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        token.close()
    }

    func testAsyncAwaitConcurrencyAPI() async {
        let config = ConnectivityConfiguration(
            hosts: [],
            dnsResolvers: [],
            systemDNSHost: "example.com",
            globalTimeout: 1.0,
            dnsProbeStrategy: { _ in true }
        )
        let engine = ConnectivityAndInternetAccess(configuration: config)

        let result = await engine.checkInternetAsync()
        XCTAssertTrue(result.isReachable)
        XCTAssertEqual(result.stage, .systemDNS)
    }
}
