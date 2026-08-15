#include "mi_account_2fa_channel.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include "utils.h"

#include <memory>
#include <sstream>
#include <string>
#include <utility>
#include <variant>

#if defined(ORONBOX_HAVE_WEBVIEW2)
#include <WebView2.h>
#include <wrl.h>
#endif

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodResult;

constexpr char kChannelName[] = "oronbox/mi_account_2fa";

#if defined(ORONBOX_HAVE_WEBVIEW2)

constexpr wchar_t kWindowClassName[] = L"OronBoxMiAccount2FAWindow";
constexpr UINT_PTR kPollTimerId = 1;
constexpr UINT kPollIntervalMs = 750;
constexpr UINT kFinalizeMessage = WM_APP + 0x2FA;

std::wstring Utf8ToWide(const std::string& text) {
  if (text.empty()) {
    return L"";
  }
  const int size = MultiByteToWideChar(
      CP_UTF8, 0, text.data(), static_cast<int>(text.size()), nullptr, 0);
  if (size <= 0) {
    return L"";
  }
  std::wstring result(static_cast<size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()),
                      result.data(), size);
  return result;
}

std::string WideToUtf8(const wchar_t* text) {
  if (text == nullptr || text[0] == L'\0') {
    return "";
  }
  const int size =
      WideCharToMultiByte(CP_UTF8, 0, text, -1, nullptr, 0, nullptr, nullptr);
  if (size <= 1) {
    return "";
  }
  std::string result(static_cast<size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, 0, text, -1, result.data(), size, nullptr,
                      nullptr);
  result.pop_back();
  return result;
}

bool HasSessionCookie(const std::string& header) {
  return header.find("passToken=") != std::string::npos ||
         header.find("cUserId=") != std::string::npos ||
         header.find("userId=") != std::string::npos;
}

std::string HResultMessage(HRESULT hr) {
  std::ostringstream out;
  out << "WebView2 failed with HRESULT 0x" << std::hex
      << static_cast<unsigned long>(hr);
  return out.str();
}

using Microsoft::WRL::Callback;
using Microsoft::WRL::ComPtr;

class WinMiAccountTwoFactorSession
    : public std::enable_shared_from_this<WinMiAccountTwoFactorSession> {
 public:
  WinMiAccountTwoFactorSession(
      HWND parent_window, std::unique_ptr<MethodResult<EncodableValue>> result)
      : parent_window_(parent_window), result_(std::move(result)) {}

  ~WinMiAccountTwoFactorSession() {
    if (window_ != nullptr) {
      KillTimer(window_, kPollTimerId);
    }
    if (controller_) {
      controller_->Close();
    }
    webview_.Reset();
    controller_.Reset();
    if (window_ != nullptr) {
      SetWindowLongPtr(window_, GWLP_USERDATA, 0);
      DestroyWindow(window_);
      window_ = nullptr;
    }
  }

  void Start(const std::string& url);

 private:
  static LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam,
                                     LPARAM lparam) {
    auto* session = reinterpret_cast<WinMiAccountTwoFactorSession*>(
        GetWindowLongPtr(window, GWLP_USERDATA));
    if (message == WM_NCCREATE) {
      const auto* create_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
      session = static_cast<WinMiAccountTwoFactorSession*>(
          create_struct->lpCreateParams);
      SetWindowLongPtr(window, GWLP_USERDATA,
                       reinterpret_cast<LONG_PTR>(session));
    }
    if (session != nullptr) {
      return session->HandleMessage(window, message, wparam, lparam);
    }
    return DefWindowProc(window, message, wparam, lparam);
  }

  static void EnsureWindowClass() {
    static bool registered = false;
    if (registered) {
      return;
    }
    WNDCLASSW window_class = {};
    window_class.lpfnWndProc = WindowProc;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.lpszClassName = kWindowClassName;
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
    RegisterClassW(&window_class);
    registered = true;
  }

  LRESULT HandleMessage(HWND window, UINT message, WPARAM wparam,
                        LPARAM lparam) {
    // Finish/Fail may release the global owner while processing this message.
    // Keep the session alive until WindowProc returns.
    [[maybe_unused]] const auto keep_alive = shared_from_this();
    switch (message) {
      case WM_SIZE:
        ResizeWebView();
        return 0;
      case WM_TIMER:
        if (wparam == kPollTimerId) {
          CompleteIfReady();
          return 0;
        }
        break;
      case kFinalizeMessage:
        Finalize();
        return 0;
      case WM_CLOSE:
        Cancel();
        return 0;
      case WM_DESTROY:
        window_ = nullptr;
        return 0;
    }
    return DefWindowProc(window, message, wparam, lparam);
  }

  void CreateWebView();

  void ResizeWebView() {
    if (!controller_ || window_ == nullptr) {
      return;
    }
    RECT bounds{};
    GetClientRect(window_, &bounds);
    controller_->put_Bounds(bounds);
  }

  void CompleteIfReady();
  void FinishSuccess(const std::string& cookie_header);
  void Fail(const std::string& code, const std::string& message);
  void Finalize();
  void ScheduleFinalize();
  void Cancel() { Fail("CANCELLED", "Xiaomi 2FA WebView was closed"); }

  HWND parent_window_ = nullptr;
  HWND window_ = nullptr;
  std::string url_;
  std::unique_ptr<MethodResult<EncodableValue>> result_;
  ComPtr<ICoreWebView2Controller> controller_;
  ComPtr<ICoreWebView2> webview_;
  bool completed_ = false;
  bool checking_cookies_ = false;
  bool finalize_posted_ = false;
  bool pending_success_ = false;
  std::string pending_value_;
  std::string pending_error_code_;
  std::string pending_error_message_;
};

std::shared_ptr<WinMiAccountTwoFactorSession> g_session;

void WinMiAccountTwoFactorSession::Start(const std::string& url) {
  [[maybe_unused]] const auto keep_alive = shared_from_this();
  url_ = url;
  EnsureWindowClass();

  RECT parent_rect{0, 0, 980, 720};
  if (parent_window_ != nullptr) {
    GetWindowRect(parent_window_, &parent_rect);
  }
  const int width = 980;
  const int height = 720;
  const int x =
      parent_rect.left + ((parent_rect.right - parent_rect.left) - width) / 2;
  const int y =
      parent_rect.top + ((parent_rect.bottom - parent_rect.top) - height) / 2;

  window_ = CreateWindowExW(WS_EX_DLGMODALFRAME, kWindowClassName,
                            L"Xiaomi account verification", WS_OVERLAPPEDWINDOW,
                            x, y, width, height, parent_window_, nullptr,
                            GetModuleHandle(nullptr), this);
  if (window_ == nullptr) {
    Fail("WEBVIEW_FAILED", "Failed to create Xiaomi 2FA window");
    return;
  }

  ShowWindow(window_, SW_SHOW);
  UpdateWindow(window_);
  CreateWebView();
}

void WinMiAccountTwoFactorSession::CreateWebView() {
  const auto weak_session = weak_from_this();
  const std::wstring user_data_folder = GetWebView2UserDataFolder();
  if (user_data_folder.empty()) {
    Fail("WEBVIEW_FAILED", "Failed to prepare WebView2 user data folder");
    return;
  }
  HRESULT hr = CreateCoreWebView2EnvironmentWithOptions(
      nullptr, user_data_folder.c_str(), nullptr,
      Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
          [weak_session](HRESULT result,
                         ICoreWebView2Environment* environment) -> HRESULT {
            const auto self = weak_session.lock();
            if (!self || self->completed_ || self->window_ == nullptr) {
              return S_OK;
            }
            if (FAILED(result) || environment == nullptr) {
              self->Fail("UNAVAILABLE", HResultMessage(result));
              return S_OK;
            }
            const auto controller_session = self->weak_from_this();
            const HRESULT controller_hr = environment->CreateCoreWebView2Controller(
                self->window_,
                Callback<
                    ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                    [controller_session](
                        HRESULT controller_result,
                        ICoreWebView2Controller* controller) -> HRESULT {
                      const auto self = controller_session.lock();
                      if (!self || self->completed_ || self->window_ == nullptr) {
                        return S_OK;
                      }
                      if (FAILED(controller_result) || controller == nullptr) {
                        self->Fail("WEBVIEW_FAILED",
                                   HResultMessage(controller_result));
                        return S_OK;
                      }
                      self->controller_ = controller;
                      const HRESULT core_hr =
                          self->controller_->get_CoreWebView2(&self->webview_);
                      if (FAILED(core_hr)) {
                        self->Fail("WEBVIEW_FAILED", HResultMessage(core_hr));
                        return S_OK;
                      }
                      if (!self->webview_) {
                        self->Fail("WEBVIEW_FAILED",
                                   "WebView2 core is not available");
                        return S_OK;
                      }

                      // The WebView2 profile is shared across sessions so it
                      // can live in a writable per-user directory on an
                      // installed build.  Clear its cookies before every
                      // Xiaomi login, otherwise a second account can reuse
                      // the first account's session.
                      ComPtr<ICoreWebView2_2> webview2;
                      if (FAILED(self->webview_.As(&webview2)) || !webview2) {
                        self->Fail("WEBVIEW_FAILED",
                                   "WebView2 cookie manager is unavailable");
                        return S_OK;
                      }
                      ComPtr<ICoreWebView2CookieManager> cookie_manager;
                      if (FAILED(webview2->get_CookieManager(&cookie_manager)) ||
                          !cookie_manager) {
                        self->Fail("WEBVIEW_FAILED",
                                   "WebView2 cookie manager is unavailable");
                        return S_OK;
                      }
                      const HRESULT delete_cookies_hr =
                          cookie_manager->DeleteAllCookies();
                      if (FAILED(delete_cookies_hr)) {
                        self->Fail("WEBVIEW_FAILED",
                                   HResultMessage(delete_cookies_hr));
                        return S_OK;
                      }

                      self->ResizeWebView();
                      const HRESULT navigate_hr =
                          self->webview_->Navigate(
                              Utf8ToWide(self->url_).c_str());
                      if (FAILED(navigate_hr)) {
                        self->Fail("WEBVIEW_FAILED",
                                   HResultMessage(navigate_hr));
                        return S_OK;
                      }
                      if (SetTimer(self->window_, kPollTimerId,
                                   kPollIntervalMs, nullptr) == 0) {
                        self->Fail("WEBVIEW_FAILED",
                                   "Failed to start Xiaomi 2FA polling");
                      }
                      return S_OK;
                    })
                    .Get());
            if (FAILED(controller_hr)) {
              self->Fail("WEBVIEW_FAILED", HResultMessage(controller_hr));
            }
            return S_OK;
          })
          .Get());

  if (FAILED(hr)) {
    Fail("UNAVAILABLE", HResultMessage(hr));
  }
}

void WinMiAccountTwoFactorSession::CompleteIfReady() {
  if (completed_ || checking_cookies_ || !webview_) {
    return;
  }

  ComPtr<ICoreWebView2_2> webview2;
  if (FAILED(webview_.As(&webview2)) || !webview2) {
    return;
  }

  ComPtr<ICoreWebView2CookieManager> cookie_manager;
  if (FAILED(webview2->get_CookieManager(&cookie_manager)) || !cookie_manager) {
    return;
  }

  LPWSTR source = nullptr;
  if (FAILED(webview_->get_Source(&source)) || source == nullptr) {
    return;
  }
  std::wstring source_uri(source);
  CoTaskMemFree(source);

  checking_cookies_ = true;
  const auto weak_session = weak_from_this();
  const HRESULT cookies_hr = cookie_manager->GetCookies(
      source_uri.c_str(),
      Callback<ICoreWebView2GetCookiesCompletedHandler>(
          [weak_session](HRESULT result,
                         ICoreWebView2CookieList* cookies) -> HRESULT {
            const auto self = weak_session.lock();
            if (!self) {
              return S_OK;
            }
            self->checking_cookies_ = false;
            if (self->completed_) {
              self->finalize_posted_ = false;
              self->ScheduleFinalize();
              return S_OK;
            }
            if (FAILED(result) || cookies == nullptr) {
              return S_OK;
            }
            UINT count = 0;
            cookies->get_Count(&count);
            std::string header;
            for (UINT i = 0; i < count; ++i) {
              ComPtr<ICoreWebView2Cookie> cookie;
              if (FAILED(cookies->GetValueAtIndex(i, &cookie)) || !cookie) {
                continue;
              }
              LPWSTR name = nullptr;
              LPWSTR value = nullptr;
              cookie->get_Name(&name);
              cookie->get_Value(&value);
              const std::string name_utf8 = WideToUtf8(name);
              const std::string value_utf8 = WideToUtf8(value);
              if (name != nullptr) {
                CoTaskMemFree(name);
              }
              if (value != nullptr) {
                CoTaskMemFree(value);
              }
              if (name_utf8.empty() || value_utf8.empty()) {
                continue;
              }
              if (!header.empty()) {
                header += "; ";
              }
              header += name_utf8;
              header += "=";
              header += value_utf8;
            }
            if (HasSessionCookie(header)) {
              self->FinishSuccess(header);
            }
            return S_OK;
          })
          .Get());
  if (FAILED(cookies_hr)) {
    checking_cookies_ = false;
  }
}

void WinMiAccountTwoFactorSession::FinishSuccess(
    const std::string& cookie_header) {
  if (completed_) {
    return;
  }
  completed_ = true;
  if (window_ != nullptr) {
    KillTimer(window_, kPollTimerId);
  }
  pending_success_ = true;
  pending_value_ = cookie_header;
  ScheduleFinalize();
}

void WinMiAccountTwoFactorSession::Fail(const std::string& code,
                                        const std::string& message) {
  if (completed_) {
    return;
  }
  completed_ = true;
  if (window_ != nullptr) {
    KillTimer(window_, kPollTimerId);
  }
  pending_success_ = false;
  pending_error_code_ = code;
  pending_error_message_ = message;
  ScheduleFinalize();
}

void WinMiAccountTwoFactorSession::ScheduleFinalize() {
  if (finalize_posted_) {
    return;
  }
  finalize_posted_ = true;
  if (window_ == nullptr ||
      !PostMessage(window_, kFinalizeMessage, 0, 0)) {
    Finalize();
  }
}

void WinMiAccountTwoFactorSession::Finalize() {
  if (checking_cookies_) {
    finalize_posted_ = false;
    return;
  }
  auto result = std::move(result_);
  if (window_ != nullptr) {
    const HWND window = window_;
    window_ = nullptr;
    SetWindowLongPtr(window, GWLP_USERDATA, 0);
    DestroyWindow(window);
  }
  if (controller_) {
    controller_->Close();
  }
  webview_.Reset();
  controller_.Reset();
  if (result) {
    if (pending_success_) {
      result->Success(EncodableValue(pending_value_));
    } else {
      result->Error(pending_error_code_, pending_error_message_);
    }
  }
  if (g_session.get() == this) {
    g_session.reset();
  }
}

#endif  // defined(ORONBOX_HAVE_WEBVIEW2)

void HandleResolve(HWND parent_window, const EncodableValue* arguments,
                   std::unique_ptr<MethodResult<EncodableValue>> result) {
  if (arguments == nullptr ||
      !std::holds_alternative<EncodableMap>(*arguments)) {
    result->Error("INVALID_ARGUMENT", "url is required");
    return;
  }
  const auto& args = std::get<EncodableMap>(*arguments);
  auto it = args.find(EncodableValue("url"));
  if (it == args.end() || !std::holds_alternative<std::string>(it->second)) {
    result->Error("INVALID_ARGUMENT", "url is required");
    return;
  }

#if defined(ORONBOX_HAVE_WEBVIEW2)
  if (g_session) {
    result->Error("BUSY", "Xiaomi 2FA WebView is already open");
    return;
  }
  g_session = std::make_shared<WinMiAccountTwoFactorSession>(parent_window,
                                                             std::move(result));
  g_session->Start(std::get<std::string>(it->second));
#else
  (void)parent_window;
  result->Error("UNAVAILABLE",
                "Windows Xiaomi 2FA requires the Microsoft Edge "
                "WebView2 SDK at build time");
#endif
}

}  // namespace

void RegisterMiAccountTwoFactorChannel(flutter::BinaryMessenger* messenger,
                                       HWND parent_window) {
  auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, kChannelName, &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [parent_window](const flutter::MethodCall<EncodableValue>& call,
                      std::unique_ptr<MethodResult<EncodableValue>> result) {
        if (call.method_name() == "resolve") {
          HandleResolve(parent_window, call.arguments(), std::move(result));
          return;
        }
        result->NotImplemented();
      });

  channel.release();
}
