#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>
#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

namespace {

void SetRegistryString(HKEY key, const wchar_t *name, const std::wstring &value) {
  ::RegSetValueExW(key, name, 0, REG_SZ,
                   reinterpret_cast<const BYTE *>(value.c_str()),
                   static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
}

void RegisterUrlProtocol() {
  wchar_t executable_path[MAX_PATH];
  if (::GetModuleFileNameW(nullptr, executable_path, MAX_PATH) == 0) {
    return;
  }

  HKEY protocol_key = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, L"Software\\Classes\\zerobox", 0,
                        nullptr, 0, KEY_WRITE, nullptr, &protocol_key,
                        nullptr) != ERROR_SUCCESS) {
    return;
  }
  SetRegistryString(protocol_key, nullptr, L"URL:ZeroBox Protocol");
  SetRegistryString(protocol_key, L"URL Protocol", L"");

  HKEY command_key = nullptr;
  if (::RegCreateKeyExW(protocol_key, L"shell\\open\\command", 0, nullptr, 0,
                        KEY_WRITE, nullptr, &command_key,
                        nullptr) == ERROR_SUCCESS) {
    const std::wstring command =
        L"\"" + std::wstring(executable_path) + L"\" \"%1\"";
    SetRegistryString(command_key, nullptr, command);
    ::RegCloseKey(command_key);
  }
  ::RegCloseKey(protocol_key);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  RegisterUrlProtocol();

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  const bool no_gui =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--nogui") != command_line_arguments.end();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, !no_gui);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"zerobox", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
