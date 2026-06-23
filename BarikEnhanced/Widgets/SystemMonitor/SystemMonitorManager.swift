import Combine
import Foundation
import Darwin
import IOKit
import os

/// This class monitors system performance metrics: CPU, RAM, Temperature, and Network Activity.
///
/// Architecture: Uses a dual-timer approach for efficiency:
/// - CPU/RAM: Fixed 2s interval via DispatchSourceTimer (Mach syscalls cost ~0.01ms)
/// - Network: Mode-dependent interval (controlled by PerformanceModeManager)
///
/// UI updates are gated behind change thresholds to avoid unnecessary SwiftUI re-renders
/// when values haven't visually changed (CPU ≥2%, RAM ≥1%).
class SystemMonitorManager: ObservableObject, ConditionallyActivatableWidget {
    static let shared = SystemMonitorManager()
    @Published var cpuLoad: Double = 0.0
    @Published var ramUsage: Double = 0.0

    @Published var uploadSpeed: Double = 0.0
    @Published var downloadSpeed: Double = 0.0
    
    // Internal CPU breakdown for popup
    @Published var userLoad: Double = 0.0
    @Published var systemLoad: Double = 0.0
    @Published var idleLoad: Double = 0.0
    
    // Internal RAM details for popup
    @Published var totalRAM: Double = 0.0
    @Published var activeRAM: Double = 0.0
    @Published var wiredRAM: Double = 0.0
    @Published var compressedRAM: Double = 0.0
    
    // MARK: - Dual-timer architecture
    
    /// Background queue for all system metric collection (Mach syscalls + getifaddrs)
    private let backgroundQueue = DispatchQueue(label: "com.barik-enhanced.sysmon", qos: .utility)
    
    /// Fast timer for CPU/RAM — fixed 2s interval regardless of performance mode.
    /// Mach kernel calls are essentially free (~0.01ms total), so this has negligible CPU impact.
    private var cpuRamTimer: DispatchSourceTimer?
    
    /// Slower timer for network stats — interval varies with performance mode.
    private var networkTimer: DispatchSourceTimer?
    
    /// Fixed polling interval for CPU/RAM (2 seconds)
    private static let cpuRamInterval: TimeInterval = 1.5
    
    /// Leeway for timer coalescing — lets macOS batch our timer with other system timers
    private static let timerLeeway: DispatchTimeInterval = .milliseconds(500)
    
    // MARK: - Change-threshold gating
    
    /// Only update @Published cpuLoad when it changes by this much (avoids SwiftUI re-renders)
    private static let cpuChangeThreshold: Double = 2.0
    
    /// Only update @Published ramUsage when it changes by this much
    private static let ramChangeThreshold: Double = 1.0
    
    /// Only update @Published CPU breakdown when it changes by this much
    private static let cpuDetailThreshold: Double = 2.0
    
    /// Only update @Published RAM detail when it changes by this much
    private static let ramDetailThreshold: Double = 0.1  // GB — ~100MB
    
    // MARK: - Internal state
    
    private var previousCpuInfo: processor_info_array_t?
    private var previousCpuInfoCount: mach_msg_type_number_t = 0
    private var previousNetworkData: [String: (ibytes: UInt64, obytes: UInt64)] = [:]
    private var lastNetworkUpdate: Date = Date()
    
    private var currentNetworkInterval: TimeInterval = 10.0
    let widgetId = "system-monitor" // This covers both cpuram and networkactivity
    
    private var isActive = false
    
    /// Performance logger
    private static let perfLogger = Logger(subsystem: "com.barik-enhanced.perf", category: "sysmon")
    
    private init() {
        setupNotifications()
        // For now, always activate to ensure widgets work
        activate()
    }
    
    deinit {
        stopMonitoring()
        NotificationCenter.default.removeObserver(self)
        if let previousCpuInfo = previousCpuInfo, previousCpuInfoCount > 0 {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: previousCpuInfo), vm_size_t(previousCpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.size))
        }
    }
    
    private func setupNotifications() {
        // Listen for performance mode changes — only affects network timer
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PerformanceModeChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let intervals = notification.object as? [String: TimeInterval],
               let newInterval = intervals["system"] {
                self?.updateNetworkTimerInterval(newInterval)
            }
        }
        
        // Listen for widget activation changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WidgetActivationChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let activeWidgets = notification.object as? Set<String> {
                // Activate if any system monitoring widget is active
                let systemWidgets = ["default.cpuram", "default.networkactivity"]
                let shouldBeActive = systemWidgets.contains { activeWidgets.contains($0) }
                
                if shouldBeActive {
                    self?.activate()
                } else {
                    self?.deactivate()
                }
            }
        }
    }
    
    private func activateIfNeeded() {
        let activationManager = WidgetActivationManager.shared
        let systemWidgets = ["default.cpuram", "default.networkactivity"]
        let shouldBeActive = systemWidgets.contains { activationManager.isWidgetActive($0) }
        
        if shouldBeActive {
            activate()
        }
    }
    
    func activate() {
        guard !isActive else { 
            return 
        }
        
        isActive = true
        
        // Get current performance mode interval for network timer only
        let performanceManager = PerformanceModeManager.shared
        let intervals = performanceManager.getTimerIntervals(for: performanceManager.currentMode)
        currentNetworkInterval = intervals["system"] ?? 10.0
        
        startMonitoring()
    }
    
    func deactivate() {
        guard isActive else { return }
        isActive = false
        stopMonitoring()
    }
    
    /// Only restarts the network timer — CPU/RAM timer runs at a fixed interval
    private func updateNetworkTimerInterval(_ newInterval: TimeInterval) {
        guard isActive else { return }
        currentNetworkInterval = newInterval
        
        // Only restart the network timer
        stopNetworkTimer()
        startNetworkTimer()
        
        Self.perfLogger.notice("Network timer interval changed to \(newInterval, privacy: .public)s")
    }

    // MARK: - Timer management
    
    private func startMonitoring() {
        startCPURamTimer()
        startNetworkTimer()
        
        // Initial update immediately
        backgroundQueue.async { [weak self] in
            self?.updateCPURAM()
            self?.updateNetworkActivity()
        }
    }
    
    private func stopMonitoring() {
        stopCPURamTimer()
        stopNetworkTimer()
    }
    
    /// Starts the fixed-interval CPU/RAM timer (2s, with 500ms leeway for coalescing)
    private func startCPURamTimer() {
        let timer = DispatchSource.makeTimerSource(queue: backgroundQueue)
        timer.schedule(
            deadline: .now() + Self.cpuRamInterval,
            repeating: Self.cpuRamInterval,
            leeway: Self.timerLeeway
        )
        timer.setEventHandler { [weak self] in
            autoreleasepool {
                self?.updateCPURAM()
            }
        }
        timer.resume()
        cpuRamTimer = timer
    }
    
    private func stopCPURamTimer() {
        cpuRamTimer?.cancel()
        cpuRamTimer = nil
    }
    
    /// Starts the mode-dependent network timer
    private func startNetworkTimer() {
        let timer = DispatchSource.makeTimerSource(queue: backgroundQueue)
        timer.schedule(
            deadline: .now() + currentNetworkInterval,
            repeating: currentNetworkInterval,
            leeway: Self.timerLeeway
        )
        timer.setEventHandler { [weak self] in
            autoreleasepool {
                self?.updateNetworkActivity()
            }
        }
        timer.resume()
        networkTimer = timer
    }
    
    private func stopNetworkTimer() {
        networkTimer?.cancel()
        networkTimer = nil
    }
    
    // MARK: - CPU + RAM collection (runs every 2s)
    
    private func updateCPURAM() {
        updateCPUUsage()
        updateRAMUsage()
    }
    
    // MARK: - CPU Usage (via host_processor_info)
    private func updateCPUUsage() {
        var cpuInfoArray: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCpus,
            &cpuInfoArray,
            &cpuInfoCount
        )

        guard result == KERN_SUCCESS, let cpuInfo = cpuInfoArray, numCpus > 0 else {
            // If CPU info fails, reset to safe values
            DispatchQueue.main.async {
                self.cpuLoad = 0.0
                self.userLoad = 0.0
                self.systemLoad = 0.0
                self.idleLoad = 100.0
            }
            return
        }

        // NOTE: Do NOT use defer to free cpuInfo here — we store it in
        // previousCpuInfo for delta calculation on the next tick.
        // The old previousCpuInfo is freed below before being replaced.

        let cpuLoadInfo = cpuInfo.withMemoryRebound(to: processor_cpu_load_info.self, capacity: Int(numCpus)) { $0 }
        
        var totalUser: UInt32 = 0
        var totalSystem: UInt32 = 0
        var totalIdle: UInt32 = 0
        var totalNice: UInt32 = 0
        
        for i in 0..<Int(numCpus) {
            let info = cpuLoadInfo[i]
            totalUser += info.cpu_ticks.0     // CPU_STATE_USER
            totalSystem += info.cpu_ticks.1   // CPU_STATE_SYSTEM
            totalIdle += info.cpu_ticks.2     // CPU_STATE_IDLE
            totalNice += info.cpu_ticks.3     // CPU_STATE_NICE
        }
        
        if let previousCpuInfo = previousCpuInfo {
            let previousCpuLoadInfo = previousCpuInfo.withMemoryRebound(to: processor_cpu_load_info.self, capacity: Int(numCpus)) { $0 }
            
            var prevTotalUser: UInt32 = 0
            var prevTotalSystem: UInt32 = 0
            var prevTotalIdle: UInt32 = 0
            var prevTotalNice: UInt32 = 0
            
            for i in 0..<Int(numCpus) {
                let info = previousCpuLoadInfo[i]
                prevTotalUser += info.cpu_ticks.0
                prevTotalSystem += info.cpu_ticks.1
                prevTotalIdle += info.cpu_ticks.2
                prevTotalNice += info.cpu_ticks.3
            }
            
            // Safely calculate deltas to avoid overflow
            let userDelta = totalUser >= prevTotalUser ? totalUser - prevTotalUser : 0
            let systemDelta = totalSystem >= prevTotalSystem ? totalSystem - prevTotalSystem : 0
            let idleDelta = totalIdle >= prevTotalIdle ? totalIdle - prevTotalIdle : 0
            let niceDelta = totalNice >= prevTotalNice ? totalNice - prevTotalNice : 0
            
            let totalDelta = userDelta + systemDelta + idleDelta + niceDelta
            
            if totalDelta > 0 {
                let newUserPercent = min(100.0, max(0.0, Double(userDelta + niceDelta) / Double(totalDelta) * 100.0))
                let newSystemPercent = min(100.0, max(0.0, Double(systemDelta) / Double(totalDelta) * 100.0))
                let newIdlePercent = min(100.0, max(0.0, Double(idleDelta) / Double(totalDelta) * 100.0))
                let newCpuLoad = min(100.0, max(0.0, newUserPercent + newSystemPercent))
                
                // Threshold-gated UI update — only push to @Published if values changed visibly
                let cpuChanged = abs(newCpuLoad - self.cpuLoad) >= Self.cpuChangeThreshold
                let detailChanged = abs(newUserPercent - self.userLoad) >= Self.cpuDetailThreshold
                    || abs(newSystemPercent - self.systemLoad) >= Self.cpuDetailThreshold
                    || abs(newIdlePercent - self.idleLoad) >= Self.cpuDetailThreshold
                
                if cpuChanged || detailChanged {
                    DispatchQueue.main.async {
                        self.userLoad = newUserPercent
                        self.systemLoad = newSystemPercent
                        self.idleLoad = newIdlePercent
                        self.cpuLoad = newCpuLoad
                    }
                }
            }
        }
        
        // Store current info for next iteration
        if let previousCpuInfo = previousCpuInfo, previousCpuInfoCount > 0 {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: previousCpuInfo), vm_size_t(previousCpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.size))
        }
        
        previousCpuInfo = cpuInfo
        previousCpuInfoCount = cpuInfoCount
    }
    
    // MARK: - RAM Usage
    private func updateRAMUsage() {
        var vmStats = vm_statistics64()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }
        
        guard result == KERN_SUCCESS else { 
            // If RAM info fails, reset to safe values
            DispatchQueue.main.async {
                self.ramUsage = 0.0
                self.totalRAM = 0.0
                self.activeRAM = 0.0
                self.wiredRAM = 0.0
                self.compressedRAM = 0.0
            }
            return 
        }
        
        // Get total physical memory
        var totalMemory: UInt64 = 0
        var totalMemorySize = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalMemory, &totalMemorySize, nil, 0)
        
        let pageSize = UInt64(vm_page_size)
        _ = totalMemory / pageSize
        
        let activePages = UInt64(vmStats.active_count)
        let wiredPages = UInt64(vmStats.wire_count)
        let compressedPages = UInt64(vmStats.compressor_page_count)
        _ = UInt64(vmStats.inactive_count)
        
        let usedPages = activePages + wiredPages + compressedPages
        let usedMemory = usedPages * pageSize
        
        let newTotalMemoryGB = Double(totalMemory) / (1024 * 1024 * 1024)
        let usedMemoryGB = Double(usedMemory) / (1024 * 1024 * 1024)
        let newActiveMemoryGB = Double(activePages * pageSize) / (1024 * 1024 * 1024)
        let newWiredMemoryGB = Double(wiredPages * pageSize) / (1024 * 1024 * 1024)
        let newCompressedMemoryGB = Double(compressedPages * pageSize) / (1024 * 1024 * 1024)
        
        let newRamUsagePercent = newTotalMemoryGB > 0 ? min(100.0, max(0.0, (usedMemoryGB / newTotalMemoryGB) * 100.0)) : 0.0
        
        // Threshold-gated UI update
        let percentChanged = abs(newRamUsagePercent - self.ramUsage) >= Self.ramChangeThreshold
        let detailChanged = abs(newActiveMemoryGB - self.activeRAM) >= Self.ramDetailThreshold
            || abs(newWiredMemoryGB - self.wiredRAM) >= Self.ramDetailThreshold
            || abs(newCompressedMemoryGB - self.compressedRAM) >= Self.ramDetailThreshold
        
        if percentChanged || detailChanged {
            DispatchQueue.main.async {
                self.ramUsage = newRamUsagePercent
                self.totalRAM = newTotalMemoryGB
                self.activeRAM = newActiveMemoryGB
                self.wiredRAM = newWiredMemoryGB
                self.compressedRAM = newCompressedMemoryGB
            }
        }
    }
    

    
    // MARK: - Network Activity
    private func updateNetworkActivity() {
        var ifaddrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrs) == 0, let firstAddr = ifaddrs else {
            return
        }
        
        defer { freeifaddrs(ifaddrs) }
        
        var currentNetworkData: [String: (ibytes: UInt64, obytes: UInt64)] = [:]
        var addr = firstAddr
        
        while true {
            let name = String(cString: addr.pointee.ifa_name)
            
            // Focus on typical active interfaces (Wi-Fi/Ethernet)
            if name.hasPrefix("en") || name.hasPrefix("wi") {
                if let data = addr.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
                    let ibytes = UInt64(data.pointee.ifi_ibytes)
                    let obytes = UInt64(data.pointee.ifi_obytes)
                    currentNetworkData[name] = (ibytes: ibytes, obytes: obytes)
                }
            }
            
            guard let nextAddr = addr.pointee.ifa_next else { break }
            addr = nextAddr
        }
        
        let currentTime = Date()
        let timeDelta = currentTime.timeIntervalSince(lastNetworkUpdate)
        
        if timeDelta > 0 && !previousNetworkData.isEmpty {
            var totalUploadDelta: UInt64 = 0
            var totalDownloadDelta: UInt64 = 0
            
            for (interface, current) in currentNetworkData {
                if let previous = previousNetworkData[interface] {
                    let uploadDelta = current.obytes > previous.obytes ? current.obytes - previous.obytes : 0
                    let downloadDelta = current.ibytes > previous.ibytes ? current.ibytes - previous.ibytes : 0
                    
                    totalUploadDelta = totalUploadDelta.addingReportingOverflow(uploadDelta).partialValue
                    totalDownloadDelta = totalDownloadDelta.addingReportingOverflow(downloadDelta).partialValue
                }
            }
            
            // Convert to MB/s with safety checks
            let uploadSpeedMBps = timeDelta > 0 ? max(0.0, Double(totalUploadDelta) / timeDelta / (1024 * 1024)) : 0.0
            let downloadSpeedMBps = timeDelta > 0 ? max(0.0, Double(totalDownloadDelta) / timeDelta / (1024 * 1024)) : 0.0
            
            DispatchQueue.main.async {
                self.uploadSpeed = uploadSpeedMBps
                self.downloadSpeed = downloadSpeedMBps
            }
        }
        
        previousNetworkData = currentNetworkData
        lastNetworkUpdate = currentTime
    }
} 