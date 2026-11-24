#include "selection_channel.h"

#include <UIAutomation.h>
#include <oleauto.h>
#include <windows.h>
#include <wrl/client.h>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <optional>
#include <string>
#include <vector>

// Native side of the "ciyue/selection" method channel. Every method returns
// null/false instead of throwing: a lookup hotkey must never crash the app
// because the focused application would not cooperate.
//
// UI Automation docs:
// https://learn.microsoft.com/en-us/windows/win32/api/uiautomationclient/nn-uiautomationclient-iuiautomation
// https://learn.microsoft.com/en-us/windows/win32/api/uiautomationclient/nf-uiautomationclient-iuiautomationtextpattern-getselection
// https://learn.microsoft.com/en-us/windows/win32/winauto/uiauto-automation-element-propids
//
// Method-channel registration follows the Flutter Windows pattern of holding
// the channel for the life of the process (see also
// https://github.com/microsoft/winappCli/blob/main/docs/guides/flutter.md):
// the handler is stateless, so leaking the channel is deliberate.

namespace {

void LogFailure(const char* message) {
  std::string text("[Ciyue] selection channel: ");
  text += message;
  text += "\n";
  ::OutputDebugStringA(text.c_str());
}

std::optional<std::string> WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) {
    return std::string();
  }
  const int size = ::WideCharToMultiByte(CP_UTF8, 0, wide.data(),
                                         static_cast<int>(wide.size()),
                                         nullptr, 0, nullptr, nullptr);
  if (size <= 0) {
    return std::nullopt;
  }
  std::string utf8(static_cast<size_t>(size), '\0');
  const int converted = ::WideCharToMultiByte(
      CP_UTF8, 0, wide.data(), static_cast<int>(wide.size()), utf8.data(),
      size, nullptr, nullptr);
  if (converted != size) {
    return std::nullopt;
  }
  return utf8;
}

// main.cpp already calls CoInitializeEx(COINIT_APARTMENTTHREADED) on the UI
// thread, so this is normally a no-op (S_FALSE). It only ever initializes
// COM when the handler runs on a thread without it, and only uninitializes
// in that case (S_OK) — never unbalancing the runner's own initialization.
class ComApartmentScope {
 public:
  ComApartmentScope()
      : hr_(::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED)) {}
  ~ComApartmentScope() {
    if (hr_ == S_OK) {
      ::CoUninitialize();
    }
  }
  ComApartmentScope(const ComApartmentScope&) = delete;
  ComApartmentScope& operator=(const ComApartmentScope&) = delete;

 private:
  HRESULT hr_;
};

// Whether the focused element holds protected content. A failed read is
// treated as a password: a control that will not say whether it is a
// password field must not be read on the chance that it is one.
bool IsPasswordElement(IUIAutomationElement* element) {
  BOOL is_password = FALSE;
  if (FAILED(element->get_CurrentIsPassword(&is_password))) {
    return true;
  }
  return is_password == TRUE;
}

// Whether the focused element is a text control whose whole value may
// stand in for a selection. The value pattern has no notion of a
// selection, so it is only trusted for editable text: any other control
// type (a list item, a button, a combo box) would leak its whole value
// for a selection the user never made. An unreadable type fails closed.
bool IsTextControlForValueFallback(IUIAutomationElement* element) {
  CONTROLTYPEID control_type = UIA_CustomControlTypeId;
  if (FAILED(element->get_CurrentControlType(&control_type))) {
    return false;
  }
  return control_type == UIA_EditControlTypeId ||
         control_type == UIA_DocumentControlTypeId;
}

// The text pattern reports the actual selection, so it is tried first. An
// empty selection is a degenerate range at the caret (see the GetSelection
// remarks), so empty text is null rather than falling through to the value
// pattern — that would return the whole document instead of the selection.
std::optional<std::string> GetSelectedTextFromTextPattern(
    IUIAutomationTextPattern* text_pattern) {
  Microsoft::WRL::ComPtr<IUIAutomationTextRangeArray> ranges;
  if (FAILED(text_pattern->GetSelection(ranges.GetAddressOf())) ||
      !ranges) {
    return std::nullopt;
  }
  int length = 0;
  if (FAILED(ranges->get_Length(&length)) || length <= 0) {
    return std::nullopt;
  }
  Microsoft::WRL::ComPtr<IUIAutomationTextRange> range;
  if (FAILED(ranges->GetElement(0, range.GetAddressOf())) || !range) {
    return std::nullopt;
  }
  // -1 returns the whole range.
  BSTR text = nullptr;
  if (FAILED(range->GetText(-1, &text)) || text == nullptr) {
    return std::nullopt;
  }
  std::wstring selected(text, ::SysStringLen(text));
  ::SysFreeString(text);
  if (selected.empty()) {
    return std::nullopt;
  }
  return WideToUtf8(selected);
}

// Only reached when the element has no text pattern at all (plain text
// fields that do not expose a selection) and is an edit or document
// control (see IsTextControlForValueFallback). The value pattern has no
// notion of a selection, so this returns the field's whole value, not just
// the highlighted part — that is the documented fallback, not a bug.
std::optional<std::string> GetSelectedTextFromValuePattern(
    IUIAutomationElement* element) {
  if (!IsTextControlForValueFallback(element)) {
    return std::nullopt;
  }
  IUnknown* raw_pattern = nullptr;
  HRESULT hr = element->GetCurrentPattern(UIA_ValuePatternId, &raw_pattern);
  if (FAILED(hr) || raw_pattern == nullptr) {
    return std::nullopt;
  }
  Microsoft::WRL::ComPtr<IUnknown> pattern;
  pattern.Attach(raw_pattern);
  Microsoft::WRL::ComPtr<IUIAutomationValuePattern> value_pattern;
  if (FAILED(pattern.As(&value_pattern)) || !value_pattern) {
    return std::nullopt;
  }
  BSTR value = nullptr;
  if (FAILED(value_pattern->get_CurrentValue(&value)) || value == nullptr) {
    return std::nullopt;
  }
  std::wstring text(value, ::SysStringLen(value));
  ::SysFreeString(value);
  if (text.empty()) {
    return std::nullopt;
  }
  return WideToUtf8(text);
}

std::optional<std::string> GetSelectedText() {
  ComApartmentScope com;
  IUIAutomation* raw_automation = nullptr;
  HRESULT hr = ::CoCreateInstance(CLSID_CUIAutomation, nullptr,
                                  CLSCTX_INPROC_SERVER, IID_IUIAutomation,
                                  reinterpret_cast<void**>(&raw_automation));
  if (FAILED(hr) || raw_automation == nullptr) {
    LogFailure("CoCreateInstance(CUIAutomation) failed");
    return std::nullopt;
  }
  Microsoft::WRL::ComPtr<IUIAutomation> automation;
  automation.Attach(raw_automation);

  Microsoft::WRL::ComPtr<IUIAutomationElement> focused;
  if (FAILED(automation->GetFocusedElement(focused.GetAddressOf())) ||
      !focused) {
    LogFailure("GetFocusedElement failed");
    return std::nullopt;
  }

  // Never force-read a password field. A control that will not report
  // IsPassword is treated as one (see IsPasswordElement), so this only
  // passes controls that positively report they are not password fields.
  if (IsPasswordElement(focused.Get())) {
    LogFailure("focused element is a password field; refusing to read it");
    return std::nullopt;
  }

  // The text pattern is queried once: when it exists, an empty or failed
  // selection is null and must not fall through to the value pattern,
  // which would return the whole field value instead of the selection.
  // Only an element with no text pattern at all reaches the value pattern.
  Microsoft::WRL::ComPtr<IUIAutomationTextPattern> text_pattern;
  IUnknown* raw_pattern = nullptr;
  if (SUCCEEDED(
          focused->GetCurrentPattern(UIA_TextPatternId, &raw_pattern)) &&
      raw_pattern != nullptr) {
    Microsoft::WRL::ComPtr<IUnknown> pattern;
    pattern.Attach(raw_pattern);
    pattern.As(&text_pattern);
  }
  if (text_pattern) {
    return GetSelectedTextFromTextPattern(text_pattern.Get());
  }
  return GetSelectedTextFromValuePattern(focused.Get());
}

bool SendCopyKeystroke() {
  // Ctrl down, C down, C up, Ctrl up. All four events are sent in one
  // SendInput call so a modifier cannot be left held down.
  INPUT inputs[4] = {};
  inputs[0].type = INPUT_KEYBOARD;
  inputs[0].ki.wVk = VK_CONTROL;
  inputs[1].type = INPUT_KEYBOARD;
  inputs[1].ki.wVk = 'C';
  inputs[2].type = INPUT_KEYBOARD;
  inputs[2].ki.wVk = 'C';
  inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;
  inputs[3].type = INPUT_KEYBOARD;
  inputs[3].ki.wVk = VK_CONTROL;
  inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;
  const UINT sent = ::SendInput(4, inputs, sizeof(INPUT));
  if (sent != 4) {
    LogFailure("SendInput delivered fewer than 4 events");
    return false;
  }
  return true;
}

std::optional<std::string> GetFocusedAppId() {
  HWND hwnd = ::GetForegroundWindow();
  if (hwnd == nullptr) {
    return std::nullopt;
  }
  DWORD pid = 0;
  ::GetWindowThreadProcessId(hwnd, &pid);
  if (pid == 0) {
    return std::nullopt;
  }
  HANDLE process =
      ::OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (process == nullptr) {
    LogFailure("OpenProcess for the foreground window failed");
    return std::nullopt;
  }
  std::vector<wchar_t> path(32768, L'\0');
  DWORD size = static_cast<DWORD>(path.size());
  const BOOL ok =
      ::QueryFullProcessImageNameW(process, 0, path.data(), &size);
  ::CloseHandle(process);
  if (!ok || size == 0) {
    return std::nullopt;
  }
  std::wstring full(path.data(), size);
  const size_t slash = full.find_last_of(L"\\/");
  const std::wstring name =
      slash == std::wstring::npos ? full : full.substr(slash + 1);
  if (name.empty()) {
    return std::nullopt;
  }
  return WideToUtf8(name);
}

}  // namespace

void RegisterSelectionChannel(flutter::FlutterEngine* engine) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          engine->messenger(), "ciyue/selection",
          &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() == "getSelectedText") {
          const std::optional<std::string> text = GetSelectedText();
          if (text.has_value()) {
            result->Success(flutter::EncodableValue(text.value()));
          } else {
            result->Success();
          }
        } else if (call.method_name() == "sendCopy") {
          result->Success(flutter::EncodableValue(SendCopyKeystroke()));
        } else if (call.method_name() == "getFocusedAppId") {
          const std::optional<std::string> app_id = GetFocusedAppId();
          if (app_id.has_value()) {
            result->Success(flutter::EncodableValue(app_id.value()));
          } else {
            result->Success();
          }
        } else {
          result->NotImplemented();
        }
      });
  // The channel lives for the life of the process; the handler is
  // stateless, so releasing ownership here is deliberate.
  channel.release();
}
