//
//  SystemStatsMonitor.swift
//  boringNotch
//
//  Lightweight CPU sampler for the Home status chips. Runs only while a client is visible.
//

import Darwin
import Foundation

@MainActor
final class SystemStatsMonitor: ObservableObject {
    static let shared = SystemStatsMonitor()

    /// Total CPU usage, 0...1.
    @Published private(set) var cpuUsage: Double = 0

    private var timer: Timer?
    private var clients = 0
    private var previous: host_cpu_load_info?

    private init() {}

    func start() {
        clients += 1
        guard timer == nil else { return }
        previous = Self.readLoad()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        clients = max(0, clients - 1)
        guard clients == 0 else { return }
        timer?.invalidate()
        timer = nil
        previous = nil
    }

    private func sample() {
        guard let current = Self.readLoad() else { return }
        defer { previous = current }
        guard let previous else { return }

        let user = Double(current.cpu_ticks.0 &- previous.cpu_ticks.0)
        let system = Double(current.cpu_ticks.1 &- previous.cpu_ticks.1)
        let idle = Double(current.cpu_ticks.2 &- previous.cpu_ticks.2)
        let nice = Double(current.cpu_ticks.3 &- previous.cpu_ticks.3)
        let total = user + system + idle + nice
        guard total > 0 else { return }
        cpuUsage = min(1, max(0, (user + system + nice) / total))
    }

    private static func readLoad() -> host_cpu_load_info? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info : nil
    }
}
