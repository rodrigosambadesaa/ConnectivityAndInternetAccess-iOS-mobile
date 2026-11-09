import Foundation

/// A custom HTTP probe receives a URL and a time budget and returns a typed result.
public typealias HTTPProbeStrategyClosure = @Sendable (URL, TimeInterval) -> (success: Bool, statusCode: Int?, reachedURL: String)

internal final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    let allowRedirects: Bool

    init(allowRedirects: Bool) {
        self.allowRedirects = allowRedirects
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(allowRedirects ? request : nil)
    }
}

/// Ensures timeout callbacks never race the caller reading status and success.
private final class ProbeResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: (success: Bool, statusCode: Int?) = (false, nil)

    func set(_ value: (success: Bool, statusCode: Int?)) {
        lock.lock()
        self.value = value
        lock.unlock()
    }

    func snapshot() -> (success: Bool, statusCode: Int?) {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

public struct HTTPProbeStrategy: Sendable {
    public let customStrategy: HTTPProbeStrategyClosure?

    public init(customStrategy: HTTPProbeStrategyClosure? = nil) {
        self.customStrategy = customStrategy
    }

    /// Never accept arbitrary captive-portal HTML (including HTTP 200) as success.
    /// 200 is only accepted for the *exact* well-known Apple success token.
    static func isValidStrictResponse(
        requestedURL: URL,
        finalURL: URL,
        status: Int,
        data: Data
    ) -> Bool {
        guard requestedURL.scheme == finalURL.scheme,
              requestedURL.host?.lowercased() == finalURL.host?.lowercased(),
              requestedURL.path == finalURL.path,
              requestedURL.query == finalURL.query else {
            return false
        }
        if requestedURL.path.hasSuffix("/generate_204") {
            return status == 204 && data.isEmpty
        }
        if requestedURL.scheme == "https",
           requestedURL.host?.lowercased() == "www.apple.com",
           requestedURL.path == "/library/test/success.html" {
            return status == 200 &&
                String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) == "Success"
        }
        return false
    }

    /// A bounded active probe. Strict mode rejects redirects, HTML interception,
    /// and unexpected 200 responses; general mode only accepts 2xx.
    public static func probeURL(
        targetURL: URL,
        timeout: TimeInterval = 2.0,
        isStrictCaptivePortal: Bool = false
    ) -> (success: Bool, statusCode: Int?, reachedURL: String) {
        let budget = max(0.05, timeout)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = budget
        config.timeoutIntervalForResource = budget
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let delegate = NoRedirectDelegate(allowRedirects: !isStrictCaptivePortal)
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        var request = URLRequest(url: targetURL, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = isStrictCaptivePortal ? "GET" : "HEAD"

        let semaphore = DispatchSemaphore(value: 0)
        let result = ProbeResultBox()
        let task = session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            guard error == nil, let http = response as? HTTPURLResponse else { return }
            let valid: Bool
            if isStrictCaptivePortal {
                valid = isValidStrictResponse(
                    requestedURL: targetURL,
                    finalURL: http.url ?? targetURL,
                    status: http.statusCode,
                    data: data ?? Data()
                )
            } else {
                valid = (200...299).contains(http.statusCode)
            }
            result.set((valid, http.statusCode))
        }
        task.resume()
        let wait = semaphore.wait(timeout: .now() + budget)
        if wait == .timedOut { task.cancel() }
        session.invalidateAndCancel()
        let completed = result.snapshot()
        return (completed.success, completed.statusCode, targetURL.absoluteString)
    }
}
