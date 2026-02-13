import Flutter
import UIKit
import Darwin
import Foundation
#if canImport(Libproc)
import Libproc
#endif

public class RuntimeInsightPlugin: NSObject, FlutterPlugin {
  private var metricsEventSink: FlutterEventSink?
  private var metricsTimer: Timer?
  private var metricsConfig = AppMetricsConfig()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let deviceChannel = FlutterMethodChannel(
      name: "runtime_insight/device_specs",
      binaryMessenger: registrar.messenger()
    )
    let metricsChannel = FlutterMethodChannel(
      name: "runtime_insight/app_metrics",
      binaryMessenger: registrar.messenger()
    )
    let metricsEventChannel = FlutterEventChannel(
      name: "runtime_insight/app_metrics_stream",
      binaryMessenger: registrar.messenger()
    )

    let instance = RuntimeInsightPlugin()
    registrar.addMethodCallDelegate(instance, channel: deviceChannel)
    registrar.addMethodCallDelegate(instance, channel: metricsChannel)
    metricsEventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "collect":
      result(collectSpecs())
    case "startMonitoring":
      let args = call.arguments as? [String: Any]
      metricsConfig = AppMetricsConfig(from: args)
      startMetrics()
      result(nil)
    case "updateMonitoring":
      let args = call.arguments as? [String: Any]
      metricsConfig = AppMetricsConfig(from: args)
      startMetrics()
      result(nil)
    case "pauseMonitoring":
      stopMetrics()
      result(nil)
    case "resumeMonitoring":
      startMetrics()
      result(nil)
    case "stopMonitoring":
      stopMetrics()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func collectSpecs() -> [String: Any] {
    let cpuCores = ProcessInfo.processInfo.processorCount
    let ramMb = Int(ProcessInfo.processInfo.physicalMemory / 1024 / 1024)
    let osVersion = UIDevice.current.systemVersion
    let osVersionMajor = osVersion.split(separator: ".").first.map(String.init) ?? osVersion

#if targetEnvironment(simulator)
    let isEmulator = true
#else
    let isEmulator = false
#endif

    return [
      "cpuCores": cpuCores,
      "ramMb": ramMb,
      "osVersion": osVersionMajor,
      "performanceClass": NSNull(),
      "isEmulator": isEmulator
    ]
  }

  private func startMetrics() {
    guard metricsEventSink != nil else { return }
    metricsTimer?.invalidate()
    let interval = Double(metricsConfig.intervalMs) / 1000.0
    metricsTimer = Timer.scheduledTimer(
      withTimeInterval: interval,
      repeats: true
    ) { [weak self] _ in
      guard let self = self else { return }
      self.metricsEventSink?(self.collectAppMetrics())
    }
  }

  private func stopMetrics() {
    metricsTimer?.invalidate()
    metricsTimer = nil
  }

  private func collectAppMetrics() -> [String: Any] {
    var payload: [String: Any] = [
      "timestampMs": Int(Date().timeIntervalSince1970 * 1000)
    ]

    if metricsConfig.cpu {
      if let cpu = cpuUsagePercent() {
        payload["cpuPercent"] = cpu
      }
    }

    if metricsConfig.memory {
      payload["memoryMb"] = memoryUsageMb()
    }

    if metricsConfig.network {
      if let network = networkBytes() {
        payload["networkRxBytes"] = Int64(network.rx)
        payload["networkTxBytes"] = Int64(network.tx)
      }
    }

    if metricsConfig.disk {
      if let disk = diskBytes() {
        payload["diskReadBytes"] = Int64(disk.read)
        payload["diskWriteBytes"] = Int64(disk.write)
      }
    }

    return payload
  }

  private func memoryUsageMb() -> Double {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    let kerr = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
      }
    }
    if kerr != KERN_SUCCESS {
      return 0
    }
    return Double(info.resident_size) / 1024.0 / 1024.0
  }

  private func cpuUsagePercent() -> Double? {
    var threadList: thread_act_array_t?
    var threadCount: mach_msg_type_number_t = 0
    let kr = task_threads(mach_task_self_, &threadList, &threadCount)
    if kr != KERN_SUCCESS {
      return nil
    }

    var totalUsage: Double = 0
    if let threadList = threadList {
      for i in 0..<Int(threadCount) {
        var threadInfo = thread_basic_info()
        var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
        let kr = withUnsafeMutablePointer(to: &threadInfo) {
          $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            thread_info(threadList[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
          }
        }
        if kr == KERN_SUCCESS && (threadInfo.flags & TH_FLAGS_IDLE) == 0 {
          totalUsage += Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
        }
      }
      vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threadList), vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.size))
    }

    return totalUsage
  }

  private func diskBytes() -> (read: UInt64, write: UInt64)? {
#if canImport(Libproc)
    var info = rusage_info_v2()
    let result = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: rusage_info_t.self, capacity: 1) { rebound in
        proc_pid_rusage(getpid(), RUSAGE_INFO_V2, rebound)
      }
    }

    if result != 0 {
      return nil
    }

    return (read: info.ri_diskio_bytesread, write: info.ri_diskio_byteswritten)
#else
    return nil
#endif
  }

  private func networkBytes() -> (rx: UInt64, tx: UInt64)? {
    var addrs: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&addrs) == 0, let firstAddr = addrs else {
      return nil
    }
    defer { freeifaddrs(addrs) }

    var rx: UInt64 = 0
    var tx: UInt64 = 0
    var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr

    while let current = cursor {
      let interface = current.pointee
      let family = interface.ifa_addr.pointee.sa_family

      if family == UInt8(AF_LINK), let data = interface.ifa_data {
        let info = data.assumingMemoryBound(to: if_data.self).pointee
        rx += UInt64(info.ifi_ibytes)
        tx += UInt64(info.ifi_obytes)
      }

      cursor = interface.ifa_next
    }

    return (rx: rx, tx: tx)
  }
}

extension RuntimeInsightPlugin: FlutterStreamHandler {
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    metricsEventSink = events
    startMetrics()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    metricsEventSink = nil
    stopMetrics()
    return nil
  }
}

private struct AppMetricsConfig {
  let cpu: Bool
  let memory: Bool
  let network: Bool
  let disk: Bool
  let intervalMs: Int

  init(cpu: Bool = true, memory: Bool = true, network: Bool = true, disk: Bool = true, intervalMs: Int = 1000) {
    self.cpu = cpu
    self.memory = memory
    self.network = network
    self.disk = disk
    self.intervalMs = intervalMs
  }

  init(from map: [String: Any]?) {
    self.cpu = map?["cpu"] as? Bool ?? true
    self.memory = map?["memory"] as? Bool ?? true
    self.network = map?["network"] as? Bool ?? true
    self.disk = map?["disk"] as? Bool ?? true
    self.intervalMs = map?["intervalMs"] as? Int ?? 1000
  }
}
