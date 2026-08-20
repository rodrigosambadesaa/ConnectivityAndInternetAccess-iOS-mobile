import Foundation
import SwiftUI
import Combine

/// SwiftUI ObservableObject that publishes live `NetworkState` changes for view bindings.
public final class ConnectivityObserver: ObservableObject {
    @Published public private(set) var networkState: NetworkState
    @Published public private(set) var lastDiagnosticResult: ReachabilityResult?
    @Published public private(set) var isDiagnosing: Bool = false

    private var token: NetworkObserverToken?
    private let connectivityEngine: ConnectivityAndInternetAccess

    public init(connectivityEngine: ConnectivityAndInternetAccess = ConnectivityAndInternetAccess()) {
        self.connectivityEngine = connectivityEngine
        self.networkState = ConnectivityAndInternetAccess.snapshotNetworkState()

        // Start passive observation
        self.token = ConnectivityAndInternetAccess.observeNetwork { [weak self] state in
            DispatchQueue.main.async {
                self?.networkState = state
            }
        }
    }

    /// Triggers an explicit active diagnostic reachability check (e.g. when the user taps the status view).
    public func runActiveDiagnostic() {
        guard !isDiagnosing else { return }
        isDiagnosing = true

        connectivityEngine.checkInternetAsync { [weak self] result in
            self?.lastDiagnosticResult = result
            self?.isDiagnosing = false
        }
    }

    deinit {
        token?.close()
    }
}
