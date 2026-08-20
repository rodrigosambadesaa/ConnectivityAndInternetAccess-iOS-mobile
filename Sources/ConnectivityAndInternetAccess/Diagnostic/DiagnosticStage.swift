import Foundation

/// Stage of the active reachability diagnostic pipeline that yielded a definitive result.
public enum DiagnosticStage: String, Codable, Sendable, CustomStringConvertible {
    /// Resolved host via system / effective DNS configuration.
    case systemDNS = "System DNS"

    /// Resolved host via direct UDP DNS query to public resolver.
    case directDNS = "Direct UDP DNS"

    /// Verified connectivity via HTTP/HTTPS probe request.
    case httpProbe = "HTTP Probe"

    /// No diagnostic stage succeeded.
    case none = "None"

    public var description: String {
        return self.rawValue
    }
}
