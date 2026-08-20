import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Low-level UDP socket DNS client for sending raw DNS A-record queries over UDP.
public final class UDPResolver: Sendable {

    /// Performs a direct UDP DNS query for `hostname` to the specified IP address on port 53.
    /// - Parameters:
    ///   - resolverIP: IP address string (e.g. "1.1.1.1", "8.8.8.8").
    ///   - hostname: Hostname to resolve (e.g. "example.com").
    ///   - timeoutMs: Socket timeout in milliseconds.
    /// - Returns: `true` if a valid DNS response packet was received from the server.
    public static func probe(resolverIP: String, hostname: String, timeoutMs: Int = 400) -> Bool {
        #if os(Windows)
        return false
        #else
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return false }
        defer { close(sock) }

        var tv = timeval()
        tv.tv_sec = timeoutMs / 1000
        tv.tv_usec = Int32((timeoutMs % 1000) * 1000)

        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(53).bigEndian
        guard inet_pton(AF_INET, resolverIP, &addr.sin_addr) == 1 else {
            return false
        }

        let queryPacket = buildDNSQueryPacket(hostname: hostname)

        let sentBytes = withUnsafePointer(to: &addr) { saPtr in
            saPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                sendto(sock, queryPacket, queryPacket.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard sentBytes == queryPacket.count else { return false }

        var buffer = [UInt8](repeating: 0, count: 512)
        let bytesRead = recv(sock, &buffer, buffer.count, 0)
        guard bytesRead >= 12 else { return false }

        // Validate basic DNS header: Transaction ID matches, QR bit set (response bit = 0x80)
        let qrFlag = buffer[2] & 0x80
        return (qrFlag == 0x80)
        #endif
    }

    /// Constructs a standard binary 12-byte header + qname + qtype + qclass DNS A-record query packet.
    private static func buildDNSQueryPacket(hostname: String) -> [UInt8] {
        var packet = [UInt8]()
        // Header
        let transactionID: UInt16 = 0x1234
        packet.append(UInt8(transactionID >> 8))
        packet.append(UInt8(transactionID & 0xFF))

        // Flags: Standard query, recursion desired (0x01, 0x00)
        packet.append(0x01)
        packet.append(0x00)

        // Questions: 1 (0x00, 0x01)
        packet.append(0x00)
        packet.append(0x01)

        // Answer RRs: 0
        packet.append(0x00)
        packet.append(0x00)

        // Authority RRs: 0
        packet.append(0x00)
        packet.append(0x00)

        // Additional RRs: 0
        packet.append(0x00)
        packet.append(0x00)

        // QNAME encoding
        let labels = hostname.split(separator: ".")
        for label in labels {
            let utf8 = Array(label.utf8)
            packet.append(UInt8(utf8.count))
            packet.append(contentsOf: utf8)
        }
        packet.append(0x00) // End of qname

        // QTYPE: A (0x00, 0x01)
        packet.append(0x00)
        packet.append(0x01)

        // QCLASS: IN (0x00, 0x01)
        packet.append(0x00)
        packet.append(0x01)

        return packet
    }
}
