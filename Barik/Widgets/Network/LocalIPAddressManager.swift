import Combine
import Darwin
import Foundation

final class LocalIPAddressManager: ObservableObject {
    static let shared = LocalIPAddressManager()

    @Published private(set) var ipAddress: String = "No IP"
    @Published private(set) var interfaceName: String = ""
    @Published private(set) var isConnected: Bool = false

    private var timer: Timer?
    private let preferredInterfaces = ["en0", "en1", "en2", "en3"]
    private let ignoredPrefixes = ["lo", "awdl", "llw", "utun", "gif", "stf", "bridge"]

    private init() {
        startMonitoring()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(forceRefresh),
            name: Notification.Name("ManualReloadTriggered"),
            object: nil
        )
    }

    deinit {
        stopMonitoring()
        NotificationCenter.default.removeObserver(self)
    }

    private func startMonitoring() {
        updateAddress()
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.updateAddress()
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func forceRefresh() {
        updateAddress()
    }

    private func updateAddress() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let address = self.resolveLocalAddress()

            DispatchQueue.main.async {
                let newIPAddress = address?.ipAddress ?? "No IP"
                let newInterfaceName = address?.interfaceName ?? ""
                let newIsConnected = address != nil

                if self.ipAddress != newIPAddress { self.ipAddress = newIPAddress }
                if self.interfaceName != newInterfaceName { self.interfaceName = newInterfaceName }
                if self.isConnected != newIsConnected { self.isConnected = newIsConnected }
            }
        }
    }

    private func resolveLocalAddress() -> InterfaceAddress? {
        var interfacesPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfacesPointer) == 0, let firstInterface = interfacesPointer else {
            return nil
        }
        defer { freeifaddrs(interfacesPointer) }

        let addresses = sequence(first: firstInterface, next: { $0.pointee.ifa_next })
            .compactMap { pointer -> InterfaceAddress? in
                let interface = pointer.pointee
                let flags = Int32(interface.ifa_flags)

                guard
                    flags & IFF_UP != 0,
                    flags & IFF_LOOPBACK == 0,
                    let addressPointer = interface.ifa_addr,
                    addressPointer.pointee.sa_family == UInt8(AF_INET)
                else {
                    return nil
                }

                let interfaceName = String(cString: interface.ifa_name)
                guard !ignoredPrefixes.contains(where: { interfaceName.hasPrefix($0) }) else {
                    return nil
                }

                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = getnameinfo(
                    addressPointer,
                    socklen_t(addressPointer.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )

                guard result == 0 else { return nil }

                let ipAddress = String(cString: hostname)
                guard !ipAddress.hasPrefix("169.254.") else { return nil }

                return InterfaceAddress(interfaceName: interfaceName, ipAddress: ipAddress)
            }

        return addresses.sorted { lhs, rhs in
            priority(for: lhs.interfaceName) < priority(for: rhs.interfaceName)
        }.first
    }

    private func priority(for interfaceName: String) -> Int {
        if let index = preferredInterfaces.firstIndex(of: interfaceName) {
            return index
        }
        if interfaceName.hasPrefix("en") {
            return preferredInterfaces.count
        }
        return preferredInterfaces.count + 1
    }
}

private struct InterfaceAddress {
    let interfaceName: String
    let ipAddress: String
}
