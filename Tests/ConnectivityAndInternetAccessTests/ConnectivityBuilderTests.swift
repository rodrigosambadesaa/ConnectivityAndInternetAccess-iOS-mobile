import XCTest
@testable import ConnectivityAndInternetAccess

final class ConnectivityBuilderTests: XCTestCase {

    func testBuilderCustomConfiguration() {
        let instance = ConnectivityAndInternetAccess.Builder()
            .setHosts(["https://my-api.com/status"])
            .setDnsResolvers(["1.1.1.1", "8.8.8.8"])
            .setSystemDNSHost("my-api.com")
            .setGlobalTimeout(3.5)
            .build()

        XCTAssertEqual(instance.configuration.hosts, ["https://my-api.com/status"])
        XCTAssertEqual(instance.configuration.dnsResolvers, ["1.1.1.1", "8.8.8.8"])
        XCTAssertEqual(instance.configuration.systemDNSHost, "my-api.com")
        XCTAssertEqual(instance.configuration.globalTimeout, 3.5)
    }

    func testStrictCaptivePortalBuilder() {
        let instance = ConnectivityAndInternetAccess.strictCaptivePortalBuilder().build()

        XCTAssertTrue(instance.configuration.isStrictCaptivePortalMode)
        XCTAssertTrue(instance.configuration.dnsResolvers.isEmpty)
        XCTAssertEqual(instance.configuration.hosts, ["http://connectivitycheck.gstatic.com/generate_204", "https://www.apple.com/library/test/success.html"])
    }
}
