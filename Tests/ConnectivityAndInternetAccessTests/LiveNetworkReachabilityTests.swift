import XCTest
@testable import ConnectivityAndInternetAccess

final class LiveNetworkReachabilityTests: XCTestCase {

    /// Tests live System DNS resolution using system getaddrinfo resolver against real domains.
    func testLiveSystemDNSPreflightResolution() {
        let hostsToTest = ["apple.com", "google.com", "cloudflare.com", "example.com"]
        var atLeastOneResolved = false

        for host in hostsToTest {
            if DNSProbeStrategy.resolveSystemDNS(hostname: host) {
                atLeastOneResolved = true
                break
            }
        }

        XCTAssertTrue(atLeastOneResolved, "Expected live System DNS preflight resolution to succeed for at least one public domain")
    }

    /// Tests live raw UDP DNS A-record queries sent over POSIX sockets to public DNS resolvers (1.1.1.1, 8.8.8.8, 9.9.9.9).
    func testLiveDirectUDPDNSProbes() {
        let resolversToTest = ["1.1.1.1", "8.8.8.8", "9.9.9.9"]
        var atLeastOneResolverResponded = false

        for resolver in resolversToTest {
            let success = UDPResolver.probe(resolverIP: resolver, hostname: "example.com", timeoutMs: 1500)
            if success {
                atLeastOneResolverResponded = true
                break
            }
        }

        XCTAssertTrue(atLeastOneResolverResponded, "Expected at least one public UDP DNS resolver (1.1.1.1, 8.8.8.8, 9.9.9.9) to respond to a live query")
    }

    /// Tests live HTTP/HTTPS reachability probing to real public endpoints.
    func testLiveHTTPProbeHostConnectivity() {
        let testURLs = [
            "https://www.apple.com/library/test/success.html",
            "https://www.cloudflare.com/cdn-cgi/trace",
            "https://www.google.com/generate_204"
        ]

        var atLeastOneHTTPSucceeded = false

        for urlString in testURLs {
            guard let url = URL(string: urlString) else { continue }
            let probeResult = HTTPProbeStrategy.probeURL(targetURL: url, timeout: 3.0, isStrictCaptivePortal: false)
            if probeResult.success {
                atLeastOneHTTPSucceeded = true
                XCTAssertNotNil(probeResult.statusCode)
                break
            }
        }

        XCTAssertTrue(atLeastOneHTTPSucceeded, "Expected at least one live HTTP/HTTPS probe endpoint to respond with a valid status code")
    }

    /// Tests live full multi-stage diagnostic pipeline execution using default ConnectivityAndInternetAccess settings.
    func testLiveFullDiagnosticPipelineExecution() {
        let connectivity = ConnectivityAndInternetAccess()
        let result = connectivity.checkInternetBlocking(timeout: 4.0)

        XCTAssertTrue(result.isReachable, "Expected live full diagnostic check to report internet reachable")
        XCTAssertNotNil(result.reachedHost, "Expected reachedHost to contain the endpoint or DNS host that responded first")
        XCTAssertNotEqual(result.stage, .none, "Expected diagnostic stage to indicate successful stage (systemDNS, directDNS, or httpProbe)")
        XCTAssertGreaterThan(result.durationMs, 0, "Expected positive diagnostic execution duration in milliseconds")
        XCTAssertFalse(result.attemptedHosts.isEmpty, "Expected attemptedHosts array to list probes executed")
    }
}
