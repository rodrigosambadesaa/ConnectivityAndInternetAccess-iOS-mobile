import Foundation
import Network
import Combine

/// Passive default-network observer for iOS using `NWPathMonitor`.
/// Generates no active DNS or HTTP network traffic.
public final class NetworkObserver: @unchecked Sendable {
    private let pathMonitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "com.connectivity.observer.queue", qos: .utility)
    private let deliveryQueue: DispatchQueue

    private let lock = NSLock()
    private var lastState: NetworkState?
    private var callbacks: [UUID: @Sendable (NetworkState) -> Void] = [:]
    private var isStarted = false

    /// Initializes a new passive `NetworkObserver`.
    /// - Parameter deliveryQueue: Queue on which state callbacks are dispatched (defaults to `.main`).
    public init(deliveryQueue: DispatchQueue = .main) {
        self.deliveryQueue = deliveryQueue
        self.pathMonitor = NWPathMonitor()
    }

    /// Starts monitoring network state changes passively.
    public func start() {
        lock.lock()
        guard !isStarted else {
            lock.unlock()
            return
        }
        isStarted = true

        pathMonitor.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }
        lock.unlock()

        pathMonitor.start(queue: monitorQueue)
    }

    /// Takes a synchronous snapshot of the current network state.
    public func snapshotNetworkState() -> NetworkState {
        lock.lock()
        if let cached = lastState {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let currentPath = pathMonitor.currentPath
        return NetworkState.from(nwPath: currentPath)
    }

    /// Registers a listener callback that immediately receives the current state and subsequent state updates.
    /// - Parameter callback: Closure to execute when network state changes.
    /// - Returns: A `NetworkObserverToken` used to unregister the listener.
    @discardableResult
    public func observeNetwork(
        callback: @Sendable @escaping (NetworkState) -> Void
    ) -> NetworkObserverToken {
        start()

        let id = UUID()
        let currentState = snapshotNetworkState()

        lock.lock()
        callbacks[id] = callback
        lock.unlock()

        // Deliver initial state immediately on the delivery queue
        deliveryQueue.async {
            callback(currentState)
        }

        return NetworkObserverToken { [weak self] in
            self?.removeCallback(id: id)
        }
    }

    /// Closes and stops the network monitor.
    public func close() {
        lock.lock()
        guard isStarted else {
            lock.unlock()
            return
        }
        isStarted = false
        callbacks.removeAll()
        pathMonitor.cancel()
        lastState = nil
        lock.unlock()
    }

    private func removeCallback(id: UUID) {
        lock.lock()
        callbacks.removeValue(forKey: id)
        lock.unlock()
    }

    private func handlePathUpdate(_ path: NWPath) {
        let newState = NetworkState.from(nwPath: path)

        lock.lock()
        // Duplicate state suppression: Ignore if core state parameters haven't changed
        if let previous = lastState,
           previous.isConnected == newState.isConnected &&
           previous.interfaceType == newState.interfaceType &&
           previous.isExpensive == newState.isExpensive &&
           previous.isConstrained == newState.isConstrained &&
           previous.isInternetValidated == newState.isInternetValidated &&
           previous.isCaptivePortalDetected == newState.isCaptivePortalDetected {
            lock.unlock()
            return
        }

        lastState = newState
        let currentCallbacks = Array(callbacks.values)
        lock.unlock()

        deliveryQueue.async {
            for cb in currentCallbacks {
                cb(newState)
            }
        }
    }

    // MARK: - Combine & AsyncSequence Extensions

    /// Combine Publisher emitting passive network state changes.
    public var publisher: AnyPublisher<NetworkState, Never> {
        let subject = CurrentValueSubject<NetworkState, Never>(snapshotNetworkState())
        let token = observeNetwork { state in
            subject.send(state)
        }
        return subject
            .handleEvents(receiveCancel: {
                token.close()
            })
            .eraseToAnyPublisher()
    }

    /// Swift AsyncSequence emitting passive network state changes.
    public var states: AsyncStream<NetworkState> {
        return AsyncStream { continuation in
            let token = self.observeNetwork { state in
                continuation.yield(state)
            }
            continuation.onTermination = { _ in
                token.close()
            }
        }
    }
}
