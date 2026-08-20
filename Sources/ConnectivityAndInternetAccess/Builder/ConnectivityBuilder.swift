import Foundation

/// Fluent builder for constructing customized `ConnectivityAndInternetAccess` diagnostic instances.
public final class ConnectivityBuilder {
    private var config: ConnectivityConfiguration

    public init() {
        self.config = ConnectivityConfiguration()
    }

    public init(configuration: ConnectivityConfiguration) {
        self.config = configuration
    }

    /// Sets the list of HTTP/HTTPS probe URLs.
    @discardableResult
    public func setHosts(_ hosts: [String]) -> ConnectivityBuilder {
        self.config.hosts = hosts
        return self
    }

    /// Sets the list of public DNS resolver IP addresses.
    @discardableResult
    public func setDnsResolvers(_ resolvers: [String]) -> ConnectivityBuilder {
        self.config.dnsResolvers = resolvers
        return self
    }

    /// Sets the System DNS preflight target host.
    @discardableResult
    public func setSystemDNSHost(_ host: String) -> ConnectivityBuilder {
        self.config.systemDNSHost = host
        return self
    }

    /// Sets the global probe deadline timeout in seconds.
    @discardableResult
    public func setGlobalTimeout(_ timeout: TimeInterval) -> ConnectivityBuilder {
        self.config.globalTimeout = timeout
        return self
    }

    /// Sets a custom DNS probe strategy closure.
    @discardableResult
    public func setDnsProbeStrategy(_ strategy: @escaping DNSProbeStrategyClosure) -> ConnectivityBuilder {
        self.config.dnsProbeStrategy = strategy
        return self
    }

    /// Sets a custom HTTP probe strategy closure.
    @discardableResult
    public func setHttpProbeStrategy(_ strategy: @escaping HTTPProbeStrategyClosure) -> ConnectivityBuilder {
        self.config.httpProbeStrategy = strategy
        return self
    }

    /// Constructs the configured `ConnectivityAndInternetAccess` instance.
    public func build() -> ConnectivityAndInternetAccess {
        return ConnectivityAndInternetAccess(configuration: config)
    }
}
