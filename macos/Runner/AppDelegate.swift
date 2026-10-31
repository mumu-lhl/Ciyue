import Carbon
import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private static var commandLineChannel: FlutterMethodChannel?

  /// Arguments that have not been handed to Dart yet. Starts with the process
  /// arguments so a terminal launch such as
  /// `Ciyue.app/Contents/MacOS/Ciyue hello` reaches the app; LaunchServices
  /// also adds `-psn_...` when the bundle is opened, which is filtered out.
  private var pendingCommandLine: [String] = ProcessInfo.processInfo.arguments
    .dropFirst()
    .filter { !$0.hasPrefix("-psn_") }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // `kInternetEventClass` / `kAEGetURL` are both FourCC 'GURL'. Listening
    // for the Apple event is equivalent to NSApplicationDelegate's
    // `application(_:open:)` but does not depend on that optional method
    // being implemented (or overridable) by FlutterAppDelegate.
    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleGetURL(_:withReply:)),
      forEventClass: AEEventClass(0x4755524C), // 'GURL'
      andEventID: AEEventID(0x4755524C) // kAEGetURL
    )
    super.applicationDidFinishLaunching(notification)
  }

  func attachCommandLineChannel(_ channel: FlutterMethodChannel) {
    AppDelegate.commandLineChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "consumePendingCommandLine":
        let arguments = self.pendingCommandLine
        self.pendingCommandLine.removeAll()
        result(arguments)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @objc private func handleGetURL(
    _ event: NSAppleEventDescriptor,
    withReply reply: NSAppleEventDescriptor
  ) {
    guard
      let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
      !urlString.isEmpty
    else {
      return
    }
    pendingCommandLine.append(urlString)
    flushCommandLine()
  }

  private func flushCommandLine() {
    guard let channel = AppDelegate.commandLineChannel, !pendingCommandLine.isEmpty else {
      return
    }
    let arguments = pendingCommandLine
    pendingCommandLine.removeAll()
    channel.invokeMethod("commandLine", arguments: arguments)
  }
}
