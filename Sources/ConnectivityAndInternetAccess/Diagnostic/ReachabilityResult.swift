import Foundation

/// Detailed result of an active internet reachability diagnostic check.
public struct ReachabilityResult: Equatable, Codable, Sendable, CustomStringConvertible {
    /// True if any probe in the diagnostic pipeline succeeded in reaching the Internet.
    public let isReachable: Bool

    /// Host or URL endpoint that successfully responded first.
    public let reachedHost: String?

    /// Array of hosts or endpoints actually attempted during the diagnostic check.
    public let attemptedHosts: [String]

    /// Total duration in milliseconds for the reachability probe execution.
    public let durationMs: Int64

    /// The diagnostic stage that returned a successful result (`systemDNS`, `directDNS`, `httpProbe`, or `none`).
    public let stage: DiagnosticStage

    /// Optional error string if the reachability check failed.
    public let error: String?

    public init(
        isReachable: Bool,
        reachedHost: String? = nil,
        attemptedHosts: [String] = [],
        durationMs: Int64 = 0,
        stage: DiagnosticStage = .none,
        error: String? = nil
    ) {
        self.isReachable = isReachable
        self.reachedHost = reachedHost
        self.attemptedHosts = attemptedHosts
        self.durationMs = durationMs
        self.stage = stage
        self.error = error
    }

    public var description: String {
        if isReachable {
            return "ReachabilityResult(reachable: true, via: \(reachedHost ?? "unknown"), stage: \(stage), duration: \(durationMs)ms)"
        } else {
            return "ReachabilityResult(reachable: false, error: \(error ?? "none"), duration: \(durationMs)ms)"
        }
    }
}
