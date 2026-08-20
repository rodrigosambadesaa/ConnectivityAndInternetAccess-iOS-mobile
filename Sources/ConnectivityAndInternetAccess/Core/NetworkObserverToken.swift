import Foundation

/// Token returned when subscribing to passive network changes.
/// Calling `close()` or `cancel()` unregisters the listener idempotently.
public final class NetworkObserverToken: Sendable {
    private let onCancel: @Sendable () -> Void
    private let isCancelledAtomic = NSLock()
    private var _isCancelled = false

    public init(onCancel: @Sendable @escaping () -> Void) {
        self.onCancel = onCancel
    }

    /// Idempotently closes and unregisters this network observer.
    public func close() {
        cancel()
    }

    /// Idempotently closes and unregisters this network observer.
    public func cancel() {
        isCancelledAtomic.lock()
        guard !_isCancelled else {
            isCancelledAtomic.unlock()
            return
        }
        _isCancelled = true
        isCancelledAtomic.unlock()

        onCancel()
    }

    /// Returns `true` if this token has already been cancelled.
    public var isCancelled: Bool {
        isCancelledAtomic.lock()
        defer { isCancelledAtomic.unlock() }
        return _isCancelled
    }

    deinit {
        close()
    }
}
