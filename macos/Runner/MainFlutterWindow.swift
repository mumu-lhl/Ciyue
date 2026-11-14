import Cocoa
import FlutterMacOS
import LaunchAtLogin

class MainFlutterWindow: NSWindow {
  // window_manager 0.5.x supplied hiddenWindowAtLaunch() from its macOS
  // Swift module. 0.6+ has no macOS plugin code left (no macos/ dir, no
  // Swift module), so `import window_manager` no longer resolves and the
  // call is undefined -- that is why `flutter build macos` fails while
  // Android/Linux/Windows stay green. Hide the window at launch directly
  // instead; the old helper was just a once-only setIsVisible(false).
  // Dart shows the window once init finishes
  // (WindowManager.instance.getCurrent()?.show() in app_initialization.dart).
  private var didHideAtLaunch = false

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // launch_at_startup requires this channel to be wired up manually on
    // macOS; see the plugin's "macOS Support" setup documentation.
    FlutterMethodChannel(
      name: "launch_at_startup", binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    .setMethodCallHandler { (_ call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "launchAtStartupIsEnabled":
        result(LaunchAtLogin.isEnabled)
      case "launchAtStartupSetEnabled":
        if let arguments = call.arguments as? [String: Any] {
          LaunchAtLogin.isEnabled = arguments["setEnabledValue"] as! Bool
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Bridge command line arguments and ciyue:// URLs to Dart. The native
    // side caches them until Dart asks for them, so early launches are not
    // lost.
    let commandLineChannel = FlutterMethodChannel(
      name: "org.eu.mumulhl.ciyue/command_line",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    (NSApp.delegate as? AppDelegate)?.attachCommandLineChannel(commandLineChannel)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    if !didHideAtLaunch {
      setIsVisible(false)
      didHideAtLaunch = true
    }
  }
}
