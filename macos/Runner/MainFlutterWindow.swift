import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var rfcommChannel: MacOSRfcommChannel?
  private var miAccountTwoFactorChannel: MacOSMiAccountTwoFactorChannel?
  private var zeppSettingsChannel: MacOSZeppSettingsChannel?
  private var logWindowChannel: MacOSLogWindowChannel?

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
    logWindowChannel = MacOSLogWindowChannel(
      messenger: flutterViewController.engine.binaryMessenger
    )

    super.awakeFromNib()
    if noGui {
      orderOut(nil)
    }
  }
}
