import Cocoa
import FlutterMacOS
import IOBluetooth

@main
class AppDelegate: FlutterAppDelegate {
  private var rfcommChannel: MacOSRfcommChannel?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      rfcommChannel = MacOSRfcommChannel(messenger: controller.engine.binaryMessenger)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

final class MacOSRfcommChannel: NSObject, FlutterStreamHandler, IOBluetoothRFCOMMChannelDelegate, IOBluetoothDeviceInquiryDelegate {
  private let methodChannel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private let scanEventChannel: FlutterEventChannel
  private var eventSink: FlutterEventSink?
  private var scanEventSink: FlutterEventSink?
  private var rfcommChannel: IOBluetoothRFCOMMChannel?
  private var inquiry: IOBluetoothDeviceInquiry?
  private var scanResults: [String: [String: Any]] = [:]
  private var connectGeneration: UInt64 = 0
  private let stateQueue = DispatchQueue(label: "org.zxor.zerobox.rfcomm.state")
  private var readClosed = false

  init(messenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(
      name: "zerobox/classic_spp",
      binaryMessenger: messenger
    )
    eventChannel = FlutterEventChannel(
      name: "zerobox/classic_spp/events",
      binaryMessenger: messenger
    )
    scanEventChannel = FlutterEventChannel(
      name: "zerobox/classic_spp/scan_events",
      binaryMessenger: messenger
    )
    super.init()

    methodChannel.setMethodCallHandler(handle)
    eventChannel.setStreamHandler(self)
    scanEventChannel.setStreamHandler(MacOSScanStreamHandler(owner: self))
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  fileprivate func onScanListen(_ events: @escaping FlutterEventSink) {
    scanEventSink = events
  }

  fileprivate func onScanCancel() {
    scanEventSink = nil
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestPermissions":
      result(nil)
    case "startScan":
      startScan(result: result)
    case "stopScan":
      stopScan(result: result)
    case "connect":
      connect(call, result: result)
    case "send":
      send(call, result: result)
    case "disconnect":
      disconnect()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startScan(result: @escaping FlutterResult) {
    stopInquiry()
    scanResults.removeAll()

    for item in pairedDevices() {
      rememberScanDevice(item)
    }

    let inquiry = IOBluetoothDeviceInquiry(delegate: self)
    inquiry?.updateNewDeviceNames = true
    self.inquiry = inquiry
    let status = inquiry?.start() ?? kIOReturnError
    if status == kIOReturnSuccess {
      result(nil)
    } else {
      self.inquiry = nil
      result(FlutterError(code: "SCAN_FAILED", message: "Bluetooth inquiry failed: \(status)", details: nil))
    }
  }

  private func stopScan(result: @escaping FlutterResult) {
    stopInquiry()
    result(Array(scanResults.values))
  }

  private func stopInquiry() {
    inquiry?.stop()
    inquiry = nil
  }

  private func pairedDevices() -> [[String: Any]] {
    let devices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
    return devices.compactMap(scanDeviceMap)
  }

  private func scanDeviceMap(_ device: IOBluetoothDevice) -> [String: Any]? {
    guard let address = device.addressString, !address.isEmpty else {
      return nil
    }
    return [
      "addr": address,
      "name": device.nameOrAddress ?? "Unknown device",
      "connectType": "spp",
    ]
  }

  private func rememberScanDevice(_ item: [String: Any]) {
    guard let address = item["addr"] as? String, !address.isEmpty else {
      return
    }
    scanResults[address] = item
    DispatchQueue.main.async {
      self.scanEventSink?(item)
    }
  }

  private func connect(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let address = args["addr"] as? String,
      !address.isEmpty
    else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "addr is required", details: nil))
      return
    }
    let fallbackChannels = (args["fallbackChannels"] as? [Int]) ?? [5, 1]
    guard let device = IOBluetoothDevice(addressString: address) else {
      result(FlutterError(code: "CONNECT_FAILED", message: "Bluetooth device not found", details: nil))
      return
    }

    let generation = stateQueue.sync { () -> UInt64 in
      connectGeneration += 1
      return connectGeneration
    }
    disconnect(cancelConnect: false, emitEvent: false)

    DispatchQueue.global(qos: .userInitiated).async {
      var lastError = "No RFCOMM channel available"
      for channelNumber in fallbackChannels where (1...30).contains(channelNumber) {
        if !self.isCurrentGeneration(generation) {
          DispatchQueue.main.async {
            result(FlutterError(code: "CONNECT_CANCELLED", message: "SPP connect was cancelled", details: nil))
          }
          return
        }

        var channel: IOBluetoothRFCOMMChannel?
        let status = self.openRfcommChannel(
          device: device,
          channelNumber: channelNumber,
          generation: generation,
          channel: &channel
        )
        if status == kIOReturnSuccess, let channel {
          let accepted = self.stateQueue.sync { () -> Bool in
            guard self.connectGeneration == generation else {
              return false
            }
            self.rfcommChannel = channel
            self.readClosed = false
            return true
          }
          if !accepted {
            channel.close()
            DispatchQueue.main.async {
              result(FlutterError(code: "CONNECT_CANCELLED", message: "SPP connect was cancelled", details: nil))
            }
            return
          }
          DispatchQueue.main.async {
            result(["channel": channelNumber])
          }
          return
        }
        lastError = "connect failed on channel \(channelNumber): \(status)"
      }

      DispatchQueue.main.async {
        result(FlutterError(code: "CONNECT_FAILED", message: lastError, details: nil))
      }
    }
  }

  private func send(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let data = args["data"] as? FlutterStandardTypedData
    else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "data is required", details: nil))
      return
    }
    guard let channel = stateQueue.sync(execute: { rfcommChannel }) else {
      result(FlutterError(code: "NOT_CONNECTED", message: "SPP socket is not connected", details: nil))
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      let bytes = [UInt8](data.data)
      let status = bytes.withUnsafeBytes { buffer -> IOReturn in
        guard let base = buffer.baseAddress else {
          return kIOReturnBadArgument
        }
        return channel.writeSync(
          UnsafeMutableRawPointer(mutating: base),
          length: UInt16(bytes.count)
        )
      }
      DispatchQueue.main.async {
        if status == kIOReturnSuccess {
          result(nil)
        } else {
          result(FlutterError(code: "SEND_FAILED", message: "RFCOMM write failed: \(status)", details: nil))
        }
      }
    }
  }

  private func disconnect(cancelConnect: Bool = true, emitEvent: Bool = true) {
    let channel = stateQueue.sync { () -> IOBluetoothRFCOMMChannel? in
      if cancelConnect {
        connectGeneration += 1
      }
      let channel = rfcommChannel
      rfcommChannel = nil
      readClosed = true
      return channel
    }
    channel?.close()
    if emitEvent {
      emitDisconnected()
    }
  }

  private func isCurrentGeneration(_ generation: UInt64) -> Bool {
    stateQueue.sync { connectGeneration == generation }
  }

  private func openRfcommChannel(
    device: IOBluetoothDevice,
    channelNumber: Int,
    generation: UInt64,
    channel: inout IOBluetoothRFCOMMChannel?
  ) -> IOReturn {
    let semaphore = DispatchSemaphore(value: 0)
    let state = RfcommOpenState()
    let deadline = Date().addingTimeInterval(10)

    DispatchQueue.global(qos: .userInitiated).async {
      var localChannel: IOBluetoothRFCOMMChannel?
      let status = device.openRFCOMMChannelSync(
        &localChannel,
        withChannelID: BluetoothRFCOMMChannelID(channelNumber),
        delegate: self
      )
      state.finish(status: status, channel: localChannel)
      semaphore.signal()
    }

    while semaphore.wait(timeout: .now() + 0.25) == .timedOut {
      if !isCurrentGeneration(generation) {
        state.cancel()?.close()
        return kIOReturnAborted
      }
      if Date() >= deadline {
        state.cancel()?.close()
        return kIOReturnTimeout
      }
    }

    let snapshot = state.snapshot()
    if !isCurrentGeneration(generation) {
      snapshot.channel?.close()
      return kIOReturnAborted
    }
    channel = snapshot.channel
    return snapshot.status
  }

  private func emitDisconnected() {
    DispatchQueue.main.async {
      self.eventSink?(["event": "disconnected"])
    }
  }

  func rfcommChannelData(
    _ rfcommChannel: IOBluetoothRFCOMMChannel!,
    data dataPointer: UnsafeMutableRawPointer!,
    length dataLength: Int
  ) {
    guard dataLength > 0, let dataPointer else {
      return
    }
    let data = Data(bytes: dataPointer, count: dataLength)
    DispatchQueue.main.async {
      self.eventSink?(FlutterStandardTypedData(bytes: data))
    }
  }

  func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
    let shouldEmit = stateQueue.sync { () -> Bool in
      guard self.rfcommChannel === rfcommChannel else {
        return false
      }
      readClosed = true
      self.rfcommChannel = nil
      return true
    }
    if shouldEmit {
      emitDisconnected()
    }
  }

  func deviceInquiryDeviceFound(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!) {
    guard sender === inquiry, let item = scanDeviceMap(device) else {
      return
    }
    rememberScanDevice(item)
  }

  func deviceInquiryComplete(_ sender: IOBluetoothDeviceInquiry!, error: IOReturn, aborted: Bool) {
    guard sender === inquiry else {
      return
    }
    inquiry = nil
  }
}

private final class RfcommOpenState {
  private let lock = NSLock()
  private var status: IOReturn = kIOReturnTimeout
  private var channel: IOBluetoothRFCOMMChannel?
  private var cancelled = false

  func finish(status: IOReturn, channel: IOBluetoothRFCOMMChannel?) {
    lock.lock()
    defer { lock.unlock() }
    if cancelled {
      channel?.close()
      return
    }
    self.status = status
    self.channel = channel
  }

  func cancel() -> IOBluetoothRFCOMMChannel? {
    lock.lock()
    defer { lock.unlock() }
    cancelled = true
    let channel = self.channel
    self.channel = nil
    return channel
  }

  func snapshot() -> (status: IOReturn, channel: IOBluetoothRFCOMMChannel?) {
    lock.lock()
    defer { lock.unlock() }
    return (status, channel)
  }
}

private final class MacOSScanStreamHandler: NSObject, FlutterStreamHandler {
  private weak var owner: MacOSRfcommChannel?

  init(owner: MacOSRfcommChannel) {
    self.owner = owner
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    owner?.onScanListen(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    owner?.onScanCancel()
    return nil
  }
}
