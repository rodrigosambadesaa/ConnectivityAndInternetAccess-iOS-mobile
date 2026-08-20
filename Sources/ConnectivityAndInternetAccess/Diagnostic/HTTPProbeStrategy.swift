import Foundation

/// Closure type representing a custom HTTP probe strategy.
/// Receives URL and timeout, returns success boolean, optional status code, and reached URL description.
public typealias HTTPProbeStrategyClosure = @Sendable (URL, TimeInterval) -> (success: Bool, statusCode: Int?, reachedURL: String)

/// Custom URLSession delegate to handle redirect policies (e.g., disallowing redirects for strict captive portal checks).
internal class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
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
        if allowRedirects {
            completionHandler(request)
        } else {
            completionHandler(nil) // Disallow redirect
        }
    }
}

/// Interface and default implementation for HTTP reachability probes.
public struct HTTPProbeStrategy: Sendable {
    public let customStrategy: HTTPProbeStrategyClosure?

    public init(customStrategy: HTTPProbeStrategyClosure? = nil) {
        self.customStrategy = customStrategy
    }

    /// Performs an active HTTP/HTTPS probe to `targetURL`.
    /// - Parameters:
    ///   - targetURL: The endpoint URL to probe.
    ///   - timeout: Timeout in seconds for the probe.
    ///   - isStrictCaptivePortal: If `true`, redirects are rejected and status code 204 is required.
    /// - Returns: Tuple containing success state, HTTP status code, and URL description.
    public static func probeURL(
        targetURL: URL,
        timeout: TimeInterval = 2.0,
        isStrictCaptivePortal: Bool = false
    ) -> (success: Bool, statusCode: Int?, reachedURL: String) {

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let delegate = NoRedirectDelegate(allowRedirects: !isStrictCaptivePortal)
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)

        var request = URLRequest(url: targetURL)
        request.httpMethod = isStrictCaptivePortal ? "GET" : "HEAD"
        request.setValue("close", forHTTPHeaderField: "Connection")

        let semaphore = DispatchSemaphore(value: 0)
        var resultSuccess = false
        var resultStatusCode: Int? = nil

        let task = session.dataTask(with: request) { _, response, error in
            defer { semaphore.signal() }
            guard error == nil, let httpResponse = response as? HTTPURLResponse else {
                return
            }
            resultStatusCode = httpResponse.statusCode

            if isStrictCaptivePortal {
                // Strict captive portal mode requires HTTP 204 No Content (or 200 for specific test URLs)
                resultSuccess = (httpResponse.statusCode == 204 || httpResponse.statusCode == 200)
            } else {
                // Standard reachability accepts 200...399
                resultSuccess = (200...399).contains(httpResponse.statusCode)
            }
        }

        task.resume()
        _ = semaphore.wait(timeout: .now() + timeout + 0.5)
        session.finishTasksAndInvalidate()

        return (resultSuccess, resultStatusCode, targetURL.absoluteString)
    }
}
