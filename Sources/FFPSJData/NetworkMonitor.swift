import Combine
import Foundation
import Network

@MainActor
public final class NetworkMonitor: ObservableObject {
    @Published public private(set) var isConnected = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "org.ffpsj.actas.network")

    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in self?.isConnected = path.status == .satisfied }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
