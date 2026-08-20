import Foundation

/// Configuration container for active connectivity diagnostics.
public struct ConnectivityConfiguration: Sendable {
    /// List of HTTP/HTTPS probe URLs.
    public var hosts: [String]

    /// List of public DNS resolver IP addresses for direct UDP DNS queries.
    public var dnsResolvers: [String]

    /// Domain hostname used for System DNS preflight lookup.
    public var systemDNSHost: String

    /// Total global timeout deadline in seconds for the complete diagnostic check.
    public var globalTimeout: TimeInterval

    /// Budget timeout in seconds for Stage 1 System DNS preflight.
    public var dnsPreflightTimeout: TimeInterval

    /// Total budget timeout in seconds for Stage 1 + Stage 2 DNS phase.
    public var dnsStageBudget: TimeInterval

    /// If true, skips DNS phase and strictly checks generate_204 endpoint without following redirects.
    public var isStrictCaptivePortalMode: Bool

    /// Optional custom closure override for DNS probing.
    public var dnsProbeStrategy: DNSProbeStrategyClosure?

    /// Optional custom closure override for HTTP probing.
    public var httpProbeStrategy: HTTPProbeStrategyClosure?

    public init(
        hosts: [String] = ConnectivityConfiguration.defaultHosts,
        dnsResolvers: [String] = ConnectivityConfiguration.defaultDNSResolvers,
        systemDNSHost: String = "example.com",
        globalTimeout: TimeInterval = 2.0,
        dnsPreflightTimeout: TimeInterval = 0.35,
        dnsStageBudget: TimeInterval = 0.70,
        isStrictCaptivePortalMode: Bool = false,
        dnsProbeStrategy: DNSProbeStrategyClosure? = nil,
        httpProbeStrategy: HTTPProbeStrategyClosure? = nil
    ) {
        self.hosts = hosts
        self.dnsResolvers = dnsResolvers
        self.systemDNSHost = systemDNSHost
        self.globalTimeout = globalTimeout
        self.dnsPreflightTimeout = dnsPreflightTimeout
        self.dnsStageBudget = dnsStageBudget
        self.isStrictCaptivePortalMode = isStrictCaptivePortalMode
        self.dnsProbeStrategy = dnsProbeStrategy
        self.httpProbeStrategy = httpProbeStrategy
    }

    /// Default HTTP probe URLs.
    public static var defaultHosts: [String] {
        return [
            "https://www.google.com/generate_204",
            "https://www.apple.com/library/test/success.html",
            "https://www.cloudflare.com/cdn-cgi/trace",
            "https://www.amazon.com",
            "https://www.facebook.com"
        ]
    }

    /// Default public DNS resolvers.
    public static var defaultDNSResolvers: [String] {
        return [
            "1.1.1.1",       // Cloudflare
            "8.8.8.8",       // Google
            "9.9.9.9",       // Quad9
            "208.67.222.222" // OpenDNS
        ]
    }

    /// Preconfigured configuration for strict Captive Portal detection mode.
    public static var strictCaptivePortalConfiguration: ConnectivityConfiguration {
        return ConnectivityConfiguration(
            hosts: ["http://connectivitycheck.gstatic.com/generate_204", "https://www.apple.com/library/test/success.html"],
            dnsResolvers: [], // Disable DNS phase in strict captive portal mode
            systemDNSHost: "",
            globalTimeout: 2.0,
            isStrictCaptivePortalMode: true
        )
    }
}
