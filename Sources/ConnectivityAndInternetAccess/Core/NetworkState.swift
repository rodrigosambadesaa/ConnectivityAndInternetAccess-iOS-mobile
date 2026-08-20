import Foundation
import Network

/// Snapshot of passive network connectivity status delivered by `NetworkObserver`.
public struct NetworkState: Equatable, Codable, Sendable, CustomStringConvertible {
    /// Indicates whether the device currently has a connected, usable network path.
    public let isConnected: Bool

    /// Hardware or transport interface type (Wi-Fi, Cellular, Ethernet, etc.).
    public let interfaceType: NetworkInterfaceType

    /// Indicates whether the current path is marked expensive (e.g., cellular data or hotspot).
    public let isExpensive: Bool

    /// Indicates whether the path is in Low Data Mode or constrained mode.
    public let isConstrained: Bool

    /// Indicates whether the OS reported valid Internet capability on this path.
    public let isInternetValidated: Bool

    /// Indicates whether the OS detected a captive portal on this path.
    public let isCaptivePortalDetected: Bool

    /// Monotonic timestamp when this snapshot was created.
    public let timestamp: Date

    public init(
        isConnected: Bool,
        interfaceType: NetworkInterfaceType = .unknown,
        isExpensive: Bool = false,
        isConstrained: Bool = false,
        isInternetValidated: Bool = false,
        isCaptivePortalDetected: Bool = false,
        timestamp: Date = Date()
    ) {
        self.isConnected = isConnected
        self.interfaceType = interfaceType
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
        self.isInternetValidated = isInternetValidated
        self.isCaptivePortalDetected = isCaptivePortalDetected
        self.timestamp = timestamp
    }

    /// Helper constructor from `NWPath`.
    public static func from(nwPath: NWPath) -> NetworkState {
        let isConnected = (nwPath.status == .satisfied)
        let isExpensive = nwPath.isExpensive
        let isConstrained = nwPath.isConstrained

        var interface: NetworkInterfaceType = .unknown
        if let primaryInterface = nwPath.availableInterfaces.first {
            interface = NetworkInterfaceType.from(nwInterfaceType: primaryInterface.type)
        } else if nwPath.usesInterfaceType(.wifi) {
            interface = .wifi
        } else if nwPath.usesInterfaceType(.cellular) {
            interface = .cellular
        } else if nwPath.usesInterfaceType(.wiredEthernet) {
            interface = .ethernet
        } else if nwPath.usesInterfaceType(.loopback) {
            interface = .loopback
        }

        // On iOS/macOS, satisfied path without constraints generally implies Internet validation.
        let isValidated = isConnected && !isConstrained
        let isCaptivePortal = (nwPath.status == .requiresConnection) || (isConnected && isConstrained)

        return NetworkState(
            isConnected: isConnected,
            interfaceType: interface,
            isExpensive: isExpensive,
            isConstrained: isConstrained,
            isInternetValidated: isValidated,
            isCaptivePortalDetected: isCaptivePortal
        )
    }

    /// Returns an offline state snapshot.
    public static var offline: NetworkState {
        return NetworkState(
            isConnected: false,
            interfaceType: .unknown,
            isExpensive: false,
            isConstrained: false,
            isInternetValidated: false,
            isCaptivePortalDetected: false
        )
    }

    public var description: String {
        return "NetworkState(connected: \(isConnected), interface: \(interfaceType), expensive: \(isExpensive), constrained: \(isConstrained), validated: \(isInternetValidated), captivePortal: \(isCaptivePortalDetected), timestamp: \(timestamp))"
    }
}
