import Foundation

/// Closure type representing a custom DNS probe strategy.
/// Receives a resolver IP / target host string, returns `true` if DNS resolution succeeded.
public typealias DNSProbeStrategyClosure = @Sendable (String) -> Bool

/// Interface and default implementation for DNS diagnostic probes.
public struct DNSProbeStrategy: Sendable {
    public let customStrategy: DNSProbeStrategyClosure?

    public init(customStrategy: DNSProbeStrategyClosure? = nil) {
        self.customStrategy = customStrategy
    }

    /// Performs effective System DNS resolution for `hostname` using system APIs (`getaddrinfo`).
    /// Budgeted for short preflight execution (~350ms).
    public static func resolveSystemDNS(hostname: String) -> Bool {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM

        var res: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(hostname, nil, &hints, &res)
        if status == 0 {
            freeaddrinfo(res)
            return true
        }
        return false
    }

    /// Performs direct UDP DNS probe to `resolverIP` for `hostname`.
    public static func probeDirectUDP(resolverIP: String, hostname: String, timeoutMs: Int = 400) -> Bool {
        return UDPResolver.probe(resolverIP: resolverIP, hostname: hostname, timeoutMs: timeoutMs)
    }
}
