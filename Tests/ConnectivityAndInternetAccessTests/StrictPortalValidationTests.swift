import XCTest
@testable import ConnectivityAndInternetAccess

final class StrictPortalValidationTests: XCTestCase {
    func testRejectsCaptiveHTMLAndRedirects() {
        let google = URL(string: "http://connectivitycheck.gstatic.com/generate_204")!
        XCTAssertFalse(HTTPProbeStrategy.isValidStrictResponse(
            requestedURL: google, finalURL: google, status: 200,
            data: Data("<html>Login to network</html>".utf8)))
        XCTAssertFalse(HTTPProbeStrategy.isValidStrictResponse(
            requestedURL: google, finalURL: URL(string: "http://portal.local/")!,
            status: 204, data: Data()))
        XCTAssertFalse(HTTPProbeStrategy.isValidStrictResponse(
            requestedURL: google, finalURL: google, status: 302, data: Data()))
        XCTAssertTrue(HTTPProbeStrategy.isValidStrictResponse(
            requestedURL: google, finalURL: google, status: 204, data: Data()))
    }

    func testAppleProbeMustReturnExpectedToken() {
        let apple = URL(string: "https://www.apple.com/library/test/success.html")!
        XCTAssertFalse(HTTPProbeStrategy.isValidStrictResponse(
            requestedURL: apple, finalURL: apple, status: 200,
            data: Data("<html>Captive Portal</html>".utf8)))
        XCTAssertTrue(HTTPProbeStrategy.isValidStrictResponse(
            requestedURL: apple, finalURL: apple, status: 200,
            data: Data("Success".utf8)))
        XCTAssertFalse(HTTPProbeStrategy.isValidStrictResponse(
            requestedURL: apple, finalURL: apple, status: 204, data: Data()))
    }

    func testDNSPreflightHonorsBudgetAndAllowsHTTPFallback() {
        let config = ConnectivityConfiguration(
            hosts: ["https://example.com/generate_204"],
            dnsResolvers: [],
            systemDNSHost: "example.com",
            globalTimeout: 0.6,
            dnsPreflightTimeout: 0.05,
            dnsProbeStrategy: { _ in
                Thread.sleep(forTimeInterval: 0.35)
                return true
            },
            httpProbeStrategy: { url, _ in (true, 204, url.absoluteString) }
        )
        let result = ConnectivityAndInternetAccess(configuration: config).checkInternetBlocking()
        XCTAssertEqual(result.stage, .httpProbe)
        XCTAssertLessThan(result.durationMs, 500)
    }
}
