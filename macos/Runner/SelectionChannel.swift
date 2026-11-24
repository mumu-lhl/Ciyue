import ApplicationServices
import CoreGraphics
import FlutterMacOS

/// Native side of the `ciyue/selection` method channel: reads the selected
/// text of the focused element in the frontmost application through the
/// Accessibility API, synthesizes Cmd+C, and reports the frontmost app.
///
/// The channel is registered here, from MainFlutterWindow, because the
/// binary messenger lives on the FlutterViewController that window owns —
/// the same place the launch_at_startup channel is created. AppDelegate has
/// no messenger, so it cannot register this channel itself.
///
/// Every method returns nil/false instead of throwing: a lookup hotkey must
/// never crash the app because the focused application would not cooperate.
///
/// Reading another app's UI needs the Accessibility grant: System Settings →
/// Privacy & Security → Accessibility. Until the user grants it, the
/// selected-text call returns nil (see `isTrusted`).
enum SelectionChannel {
  // Retained for the life of the process. The messenger keeps the handler,
  // but the channel itself must not be dropped with the registering call.
  private static var channel: FlutterMethodChannel?

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "ciyue/selection",
      binaryMessenger: messenger
    )
    self.channel = channel
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getSelectedText":
        result(selectedText())
      case "sendCopy":
        result(sendCopy())
      case "getFocusedAppId":
        result(focusedAppId())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func attribute(
    _ element: AXUIElement,
    _ name: CFString
  ) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name, &value) == .success
    else { return nil }
    return value
  }

  /// Silent trust check: never prompts here, so a lookup never pops a
  /// system dialog. The user grants access in System Settings.
  private static func isTrusted() -> Bool {
    let options = [
      kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false
    ] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
  }

  private static func selectedText() -> String? {
    guard isTrusted() else {
      NSLog(
        "[Ciyue] getSelectedText: not a trusted accessibility client; "
          + "grant access in System Settings > Privacy & Security > Accessibility"
      )
      return nil
    }
    let systemWide = AXUIElementCreateSystemWide()
    guard
      let focused = attribute(
        systemWide,
        kAXFocusedUIElementAttribute
      ) as? AXUIElement
    else { return nil }

    // Never force-read a password field. Whether every app marks its
    // password field with the secure subrole is unverified; a secure field
    // also typically exposes no selected text, so the fallbacks below refuse
    // to reconstruct one from the field value.
    if isSecureTextField(focused) { return nil }

    if let selected = attribute(
      focused,
      kAXSelectedTextAttribute
    ) as? String, !selected.isEmpty {
      return selected
    }
    return selectedTextFromRange(focused)
  }

  /// A secure text field reports role AXTextField with subrole
  /// AXSecureTextField.
  private static func isSecureTextField(_ element: AXUIElement) -> Bool {
    guard
      let role = attribute(element, kAXRoleAttribute) as? String,
      role == (kAXTextFieldRole as String)
    else { return false }
    let subrole = attribute(element, kAXSubroleAttribute) as? String
    return subrole == (kAXSecureTextFieldSubrole as String)
  }

  /// Some apps expose no selected-text attribute but do expose the selection
  /// as a range plus the field's full value; slice the value with the range.
  /// Only reached for non-secure fields (see `selectedText`).
  private static func selectedTextFromRange(_ element: AXUIElement) -> String? {
    guard
      let rangeValue = attribute(
        element,
        kAXSelectedTextRangeAttribute
      ) as? AXValue,
      let value = attribute(element, kAXValueAttribute) as? String
    else { return nil }
    var range = CFRange(location: 0, length: 0)
    guard AXValueGetValue(rangeValue, .cfRange, &range), range.length > 0
    else { return nil }
    // AX ranges are in the string's UTF-16 units, matching NSString.
    let nsValue = value as NSString
    guard
      range.location >= 0,
      range.location + range.length <= nsValue.length
    else { return nil }
    let selected = nsValue.substring(
      with: NSRange(location: range.location, length: range.length)
    )
    return selected.isEmpty ? nil : selected
  }

  private static func sendCopy() -> Bool {
    // Posting a synthetic keystroke needs event-posting access, which is
    // granted in the same Accessibility pane as the trust check above.
    // Whether a denied post shows its own prompt is unverified, so check
    // first and report false instead of silently dropping the keystroke.
    guard CGPreflightPostEventAccess() else {
      NSLog(
        "[Ciyue] sendCopy: event posting is not allowed; grant access in "
          + "System Settings > Privacy & Security > Accessibility"
      )
      return false
    }
    guard let source = CGEventSource(stateID: .hidSystemState) else {
      return false
    }
    // kVK_ANSI_C (HIToolbox/Events.h).
    let keyCode: CGKeyCode = 8
    guard
      let keyDown = CGEvent(
        keyboardEventSource: source,
        virtualKey: keyCode,
        keyDown: true
      ),
      let keyUp = CGEvent(
        keyboardEventSource: source,
        virtualKey: keyCode,
        keyDown: false
      )
    else { return false }
    keyDown.flags = .maskCommand
    keyUp.flags = .maskCommand
    CGEventPost(.cghidEventTap, keyDown)
    CGEventPost(.cghidEventTap, keyUp)
    return true
  }

  private static func focusedAppId() -> String? {
    NSWorkspace.shared.frontmostApplication?.bundleIdentifier
  }
}
