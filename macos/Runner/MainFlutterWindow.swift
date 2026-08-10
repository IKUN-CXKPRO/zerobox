import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var rfcommChannel: MacOSRfcommChannel?
  private var miAccountTwoFactorChannel: MacOSMiAccountTwoFactorChannel?
  private var zeppSettingsChannel: MacOSZeppSettingsChannel?

  override func awakeFromNib() {
    let noGui = ProcessInfo.processInfo.arguments.contains("--nogui")
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    rfcommChannel = MacOSRfcommChannel(
      messenger: flutterViewController.engine.binaryMessenger
    )
    miAccountTwoFactorChannel = MacOSMiAccountTwoFactorChannel(
      messenger: flutterViewController.engine.binaryMessenger,
      parentWindow: self
    )
    zeppSettingsChannel = MacOSZeppSettingsChannel(
      messenger: flutterViewController.engine.binaryMessenger,
      parentWindow: self
    )

    let fileChannel = FlutterMethodChannel(
      name: "oronbox/file_open",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    fileChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getInitialFile":
        result(AppDelegate.takePendingOpenPath())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    AppDelegate.fileOpenChannel = fileChannel

    super.awakeFromNib()
    if noGui {
      orderOut(nil)
    }
  }
}
