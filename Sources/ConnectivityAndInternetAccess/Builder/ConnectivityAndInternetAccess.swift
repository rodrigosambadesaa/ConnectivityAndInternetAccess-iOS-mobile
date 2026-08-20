import Foundation
import Network

/// Cancellable request handle returned by `checkInternetAsync`.
public final class ConnectivityRequest: Sendable {
    private let isCancelledAtomic = NSLock()
    private var _isCancelled = false

    public init() {}

    /// Cancels the in-flight internet reachability diagnostic check.
    public func cancel() {
        isCancelledAtomic.lock()
        _isCancelled = true
        isCancelledAtomic.unlock()
    }

    /// Returns `true` if the request was cancelled before completion.
    public var isCancelled: Bool {
        isCancelledAtomic.lock()
        defer { isCancelledAtomic.unlock() }
        return _isCancelled
    }
}

/// Main entry point for passive network state observation and active multi-stage Internet reachability diagnostics.
public final class ConnectivityAndInternetAccess: Sendable {
    public let configuration: ConnectivityConfiguration
    private static let sharedObserver = NetworkObserver()

    public init(configuration: ConnectivityConfiguration = ConnectivityConfiguration()) {
        self.configuration = configuration
    }

    // MARK: - Factory & Builder Methods

    /// Returns a new fluent `ConnectivityBuilder` instance.
    public static func Builder() -> ConnectivityBuilder {
        return ConnectivityBuilder()
    }

    /// Returns a preconfigured builder for strict Captive Portal detection mode.
    public static func strictCaptivePortalBuilder() -> ConnectivityBuilder {
        return ConnectivityBuilder(configuration: ConnectivityConfiguration.strictCaptivePortalConfiguration)
    }

    // MARK: - Static Passive Observation Convenience APIs

    /// Takes a cheap point-in-time snapshot of the current default network state without network probes.
    public static func snapshotNetworkState() -> NetworkState {
        return sharedObserver.snapshotNetworkState()
    }

    /// Registers a passive network state observer.
    /// Immediately delivers the current snapshot to `callback`, then posts updates when network capabilities change.
    /// - Parameter callback: Closure called on the main thread when network state changes.
    /// - Returns: A `NetworkObserverToken` to unregister the listener.
    @discardableResult
    public static func observeNetwork(
        callback: @Sendable @escaping (NetworkState) -> Void
    ) -> NetworkObserverToken {
        return sharedObserver.observeNetwork(callback: callback)
    }

    // MARK: - Static Active Diagnostic Convenience APIs

    /// Performs an active Internet reachability diagnostic check using default configuration asynchronously.
    @discardableResult
    public static func checkInternetAsyncDefault(
        completion: @Sendable @escaping (ReachabilityResult) -> Void
    ) -> ConnectivityRequest {
        let instance = ConnectivityAndInternetAccess()
        return instance.checkInternetAsync(completion: completion)
    }

    /// Performs a synchronous blocking Internet reachability diagnostic check using default configuration.
    public static func checkInternetBlockingDefault(timeout: TimeInterval = 2.0) -> ReachabilityResult {
        let instance = ConnectivityAndInternetAccess()
        return instance.checkInternetBlocking(timeout: timeout)
    }

    /// Quick boolean check returning `true` if Internet is currently reachable.
    public static func isInternetReachable() -> Bool {
        return checkInternetBlockingDefault().isReachable
    }

    // MARK: - Instance Active Reachability Engine

    /// Performs an active multi-stage Internet reachability check asynchronously.
    /// - Parameter completion: Completion handler delivered on main thread with `ReachabilityResult`.
    /// - Returns: A `ConnectivityRequest` handle that can cancel the request.
    @discardableResult
    public func checkInternetAsync(
        completion: @Sendable @escaping (ReachabilityResult) -> Void
    ) -> ConnectivityRequest {
        let request = ConnectivityRequest()

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let result = self.executeDiagnosticPipeline(request: request)
            guard !request.isCancelled else { return }
            DispatchQueue.main.async {
                completion(result)
            }
        }

        return request
    }

    /// Async/Await (Swift Concurrency) API for active reachability check.
    public func checkInternetAsync() async -> ReachabilityResult {
        return await withCheckedContinuation { continuation in
            checkInternetAsync { result in
                continuation.resume(returning: result)
            }
        }
    }

    /// Performs a synchronous blocking reachability check on the current thread.
    public func checkInternetBlocking(timeout: TimeInterval? = nil) -> ReachabilityResult {
        let effectiveTimeout = timeout ?? configuration.globalTimeout
        let semaphore = DispatchSemaphore(value: 0)
        var capturedResult: ReachabilityResult? = nil

        let request = ConnectivityRequest()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            capturedResult = self.executeDiagnosticPipeline(request: request)
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + effectiveTimeout + 0.2)
        return capturedResult ?? ReachabilityResult(
            isReachable: false,
            durationMs: Int64(effectiveTimeout * 1000),
            stage: .none,
            error: "Diagnostic execution timed out"
        )
    }

    // MARK: - Private Pipeline Execution

    private func executeDiagnosticPipeline(request: ConnectivityRequest) -> ReachabilityResult {
        let startTime = DispatchTime.now()
        var attemptedHosts: [String] = []

        let deadline = startTime + configuration.globalTimeout

        // Check if strict captive portal mode is active
        if configuration.isStrictCaptivePortalMode {
            return executeStrictCaptivePortalCheck(request: request, startTime: startTime, deadline: deadline)
        }

        // Stage 1: System / Effective DNS Preflight
        if !configuration.systemDNSHost.isEmpty {
            let targetHost = configuration.systemDNSHost
            let hostDescriptor = "dns://system/\(targetHost)"
            attemptedHosts.append(hostDescriptor)

            if let customDNS = configuration.dnsProbeStrategy {
                if customDNS(hostDescriptor) {
                    let elapsed = elapsedTimeMs(since: startTime)
                    return ReachabilityResult(
                        isReachable: true,
                        reachedHost: hostDescriptor,
                        attemptedHosts: attemptedHosts,
                        durationMs: elapsed,
                        stage: .systemDNS
                    )
                }
            } else {
                if DNSProbeStrategy.resolveSystemDNS(hostname: targetHost) {
                    let elapsed = elapsedTimeMs(since: startTime)
                    return ReachabilityResult(
                        isReachable: true,
                        reachedHost: hostDescriptor,
                        attemptedHosts: attemptedHosts,
                        durationMs: elapsed,
                        stage: .systemDNS
                    )
                }
            }
        }

        guard !request.isCancelled, DispatchTime.now() < deadline else {
            return ReachabilityResult(isReachable: false, attemptedHosts: attemptedHosts, durationMs: elapsedTimeMs(since: startTime), stage: .none, error: "Cancelled or timed out")
        }

        // Stage 2: Direct Parallel UDP DNS Queries to Public Resolvers
        if !configuration.dnsResolvers.isEmpty {
            let targetHost = configuration.systemDNSHost.isEmpty ? "example.com" : configuration.systemDNSHost
            let dnsGroup = DispatchGroup()
            let lock = NSLock()
            var directDNSSucceededHost: String? = nil

            for resolver in configuration.dnsResolvers {
                let descriptor = "dns://\(resolver)/\(targetHost)"
                lock.lock()
                attemptedHosts.append(descriptor)
                lock.unlock()

                dnsGroup.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    defer { dnsGroup.leave() }
                    let success = DNSProbeStrategy.probeDirectUDP(resolverIP: resolver, hostname: targetHost, timeoutMs: Int(self.configuration.dnsStageBudget * 1000))
                    if success {
                        lock.lock()
                        if directDNSSucceededHost == nil {
                            directDNSSucceededHost = descriptor
                        }
                        lock.unlock()
                    }
                }
            }

            _ = dnsGroup.wait(timeout: .now() + configuration.dnsStageBudget)

            if let succeededHost = directDNSSucceededHost {
                let elapsed = elapsedTimeMs(since: startTime)
                return ReachabilityResult(
                    isReachable: true,
                    reachedHost: succeededHost,
                    attemptedHosts: attemptedHosts,
                    durationMs: elapsed,
                    stage: .directDNS
                )
            }
        }

        guard !request.isCancelled, DispatchTime.now() < deadline else {
            return ReachabilityResult(isReachable: false, attemptedHosts: attemptedHosts, durationMs: elapsedTimeMs(since: startTime), stage: .none, error: "DNS stage failed or timed out")
        }

        // Stage 3: HTTP/HTTPS Parallel Reachability Probes
        if !configuration.hosts.isEmpty {
            let httpGroup = DispatchGroup()
            let lock = NSLock()
            var httpSucceededHost: String? = nil

            let remainingTime = max(0.5, Double(deadline.uptimeNanoseconds - DispatchTime.now().uptimeNanoseconds) / 1_000_000_000.0)

            for hostString in configuration.hosts {
                lock.lock()
                attemptedHosts.append(hostString)
                lock.unlock()

                guard let url = URL(string: hostString) else { continue }

                httpGroup.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    defer { httpGroup.leave() }

                    let probeResult: (success: Bool, statusCode: Int?, reachedURL: String)
                    if let customHTTP = self.configuration.httpProbeStrategy {
                        probeResult = customHTTP(url, remainingTime)
                    } else {
                        probeResult = HTTPProbeStrategy.probeURL(targetURL: url, timeout: remainingTime, isStrictCaptivePortal: false)
                    }

                    if probeResult.success {
                        lock.lock()
                        if httpSucceededHost == nil {
                            httpSucceededHost = probeResult.reachedURL
                        }
                        lock.unlock()
                    }
                }
            }

            _ = httpGroup.wait(timeout: .now() + remainingTime)

            if let succeededHost = httpSucceededHost {
                let elapsed = elapsedTimeMs(since: startTime)
                return ReachabilityResult(
                    isReachable: true,
                    reachedHost: succeededHost,
                    attemptedHosts: attemptedHosts,
                    durationMs: elapsed,
                    stage: .httpProbe
                )
            }
        }

        let elapsed = elapsedTimeMs(since: startTime)
        return ReachabilityResult(
            isReachable: false,
            attemptedHosts: attemptedHosts,
            durationMs: elapsed,
            stage: .none,
            error: "All reachability diagnostic stages failed"
        )
    }

    private func executeStrictCaptivePortalCheck(
        request: ConnectivityRequest,
        startTime: DispatchTime,
        deadline: DispatchTime
    ) -> ReachabilityResult {
        var attemptedHosts: [String] = []
        let httpGroup = DispatchGroup()
        let lock = NSLock()
        var succeededHost: String? = nil

        let remainingTime = configuration.globalTimeout

        for hostString in configuration.hosts {
            lock.lock()
            attemptedHosts.append(hostString)
            lock.unlock()

            guard let url = URL(string: hostString) else { continue }

            httpGroup.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                defer { httpGroup.leave() }
                let probeResult = HTTPProbeStrategy.probeURL(targetURL: url, timeout: remainingTime, isStrictCaptivePortal: true)

                if probeResult.success {
                    lock.lock()
                    if succeededHost == nil {
                        succeededHost = probeResult.reachedURL
                    }
                    lock.unlock()
                }
            }
        }

        _ = httpGroup.wait(timeout: .now() + remainingTime)

        let elapsed = elapsedTimeMs(since: startTime)
        if let host = succeededHost {
            return ReachabilityResult(
                isReachable: true,
                reachedHost: host,
                attemptedHosts: attemptedHosts,
                durationMs: elapsed,
                stage: .httpProbe
            )
        } else {
            return ReachabilityResult(
                isReachable: false,
                attemptedHosts: attemptedHosts,
                durationMs: elapsed,
                stage: .none,
                error: "Strict captive portal validation failed (offline or captive portal detected)"
            )
        }
    }

    private func elapsedTimeMs(since startTime: DispatchTime) -> Int64 {
        let now = DispatchTime.now()
        let nano = now.uptimeNanoseconds - startTime.uptimeNanoseconds
        return Int64(nano / 1_000_000)
    }
}
