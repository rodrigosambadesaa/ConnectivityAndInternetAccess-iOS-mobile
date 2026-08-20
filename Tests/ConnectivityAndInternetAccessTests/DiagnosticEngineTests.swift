import XCTest
@testable import ConnectivityAndInternetAccess

final class DiagnosticEngineTests: XCTestCase {

    func testSystemDNSSuccess() {
        let config = ConnectivityConfiguration(
            hosts: [],
            dnsResolvers: [],
            systemDNSHost: "mock.example.com",
            globalTimeout: 1.0,
            dnsProbeStrategy: { host in
                return host.contains("mock.example.com")
            }
        )

        let engine = ConnectivityAndInternetAccess(configuration: config)
        let result = engine.checkInternetBlocking()

        XCTAssertTrue(result.isReachable)
        XCTAssertEqual(result.stage, .systemDNS)
        XCTAssertEqual(result.reachedHost, "dns://system/mock.example.com")
    }

    func testDirectUDPProbeFallbackWhenSystemDNSFails() {
        let config = ConnectivityConfiguration(
            hosts: [],
            dnsResolvers: ["1.1.1.1"],
            systemDNSHost: "fail.example.com",
            globalTimeout: 1.0,
            dnsProbeStrategy: { host in
                if host.contains("dns://1.1.1.1") {
                    return true
                }
                return false
            }
        )

        let engine = ConnectivityAndInternetAccess(configuration: config)
        let result = engine.checkInternetBlocking()

        XCTAssertTrue(result.isReachable)
        XCTAssertEqual(result.stage, .directDNS)
        XCTAssertEqual(result.reachedHost, "dns://1.1.1.1/fail.example.com")
    }

    func testHTTPProbeFallbackWhenDNSStageFails() {
        let config = ConnectivityConfiguration(
            hosts: ["https://mock-backend.com/health"],
            dnsResolvers: [],
            systemDNSHost: "",
            globalTimeout: 1.0,
            httpProbeStrategy: { url, timeout in
                if url.absoluteString == "https://mock-backend.com/health" {
                    return (true, 200, url.absoluteString)
                }
                return (false, 500, url.absoluteString)
            }
        )

        let engine = ConnectivityAndInternetAccess(configuration: config)
        let result = engine.checkInternetBlocking()

        XCTAssertTrue(result.isReachable)
        XCTAssertEqual(result.stage, .httpProbe)
        XCTAssertEqual(result.reachedHost, "https://mock-backend.com/health")
    }

    func testAllStagesFailureReturnsUnreachable() {
        let config = ConnectivityConfiguration(
            hosts: ["https://unreachable.local"],
            dnsResolvers: ["9.9.9.9"],
            systemDNSHost: "unreachable.local",
            globalTimeout: 0.5,
            dnsProbeStrategy: { _ in false },
            httpProbeStrategy: { url, _ in (false, nil, url.absoluteString) }
        )

        let engine = ConnectivityAndInternetAccess(configuration: config)
        let result = engine.checkInternetBlocking()

        XCTAssertFalse(result.isReachable)
        XCTAssertEqual(result.stage, .none)
        XCTAssertNotNil(result.error)
    }

    func testAsyncDiagnosticWithCancellation() {
        let config = ConnectivityConfiguration(
            hosts: ["https://slow-response.com"],
            dnsResolvers: [],
            systemDNSHost: "",
            globalTimeout: 3.0,
            httpProbeStrategy: { url, _ in
                Thread.sleep(forTimeInterval: 1.5)
                return (true, 200, url.absoluteString)
            }
        )

        let engine = ConnectivityAndInternetAccess(configuration: config)
        let request = engine.checkInternetAsync { _ in
            XCTFail("Callback should not be called if request was cancelled")
        }

        request.cancel()
        XCTAssertTrue(request.isCancelled)
    }
}
