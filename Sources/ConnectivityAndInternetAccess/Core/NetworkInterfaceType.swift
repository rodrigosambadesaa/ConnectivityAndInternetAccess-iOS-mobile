import Foundation
import Network

/// Represents the primary hardware interface type of a network path.
public enum NetworkInterfaceType: String, Codable, Sendable, CustomStringConvertible, Hashable {
    case wifi = "Wi-Fi"
    case cellular = "Cellular"
    case ethernet = "Ethernet"
    case loopback = "Loopback"
    case vpn = "VPN / Other"
    case unknown = "Unknown"

    public var description: String {
        return self.rawValue
    }

    /// Maps standard `NWInterface.InterfaceType` to `NetworkInterfaceType`.
    public static func from(nwInterfaceType: NWInterface.InterfaceType) -> NetworkInterfaceType {
        switch nwInterfaceType {
        case .wifi:
            return .wifi
        case .cellular:
            return .cellular
        case .wiredEthernet:
            return .ethernet
        case .loopback:
            return .loopback
        case .other:
            return .vpn
        @unknown default:
            return .unknown
        }
    }
}
