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

    /// Internet validation is unknown from NWPathMonitor alone (false for passive snapshots).
    public let isInternetValidated: Bool

    /// Captive portal cannot be detected passively by NWPathMonitor (false for passive snapshots).
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
        let connected = nwPath.status == .satisfied

        // availableInterfaces is NOT the selected route. Query usesInterfaceType.
        let interface: NetworkInterfaceType
        if nwPath.usesInterfaceType(.wifi) {
            interface = .wifi
        } else if nwPath.usesInterfaceType(.cellular) {
            interface = .cellular
        } else if nwPath.usesInterfaceType(.wiredEthernet) {
            interface = .ethernet
        } else if nwPath.usesInterfaceType(.loopback) {
            interface = .loopback
        } else {
            interface = .unknown
        }

        // NWPathMonitor does not validate Internet, detect captive portals, or
        // distinguish VPNs reliably. A constrained (Low Data Mode) path is NOT
        // evidence of a captive portal; a satisfied path is NOT HTTPS proof.
        return NetworkState(
            isConnected: connected,
            interfaceType: interface,
            isExpensive: nwPath.isExpensive,
            isConstrained: nwPath.isConstrained,
            isInternetValidated: false,
            isCaptivePortalDetected: false
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
