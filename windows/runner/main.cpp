#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>
#include <algorithm>
#include <cctype>
#include <cstring>
#include <utility>
#include <vector>

#include "file_open_channel.h"
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
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, L"Software\\Classes\\oronbox", 0,
                        nullptr, 0, KEY_WRITE, nullptr, &protocol_key,
                        nullptr) != ERROR_SUCCESS) {
    return;
  }
  SetRegistryString(protocol_key, nullptr, L"URL:OronBox Protocol");
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

// Claims "open with OronBox" for wearable resource packages. Registered under
// HKCU so no elevation is required; the app is offered in the "Open with"
// chooser for these extensions.
void RegisterFileAssociations() {
  wchar_t executable_path[MAX_PATH];
  if (::GetModuleFileNameW(nullptr, executable_path, MAX_PATH) == 0) {
    return;
  }
  const wchar_t *extensions[] = {L".rpk", L".bin", L".face", L".zpk",
                                 L".mwz", L".obp", L".abp"};
  const wchar_t *descriptions[] = {
      L"OronBox RPK Package", L"OronBox Firmware", L"OronBox Watchface",
      L"OronBox ZPK Package", L"OronBox MWZ Project",
      L"OronBox Plugin Package", L"AstroBox Plugin Package"};
  const std::wstring command =
      L"\"" + std::wstring(executable_path) + L"\" \"%1\"";
  for (int i = 0; i < 7; i++) {
    std::wstring class_name =
        std::wstring(L"OronBox.") + (extensions[i] + 1);
    HKEY class_key = nullptr;
    if (::RegCreateKeyExW(HKEY_CURRENT_USER,
                          (L"Software\\Classes\\" + class_name).c_str(), 0,
                          nullptr, 0, KEY_WRITE, nullptr, &class_key,
                          nullptr) != ERROR_SUCCESS) {
      continue;
    }
    SetRegistryString(class_key, nullptr, descriptions[i]);

    HKEY open_with_key = nullptr;
    if (::RegCreateKeyExW(class_key, L"shell\\open", 0, nullptr, 0, KEY_WRITE,
                          nullptr, &open_with_key,
                          nullptr) == ERROR_SUCCESS) {
      HKEY command_key = nullptr;
      if (::RegCreateKeyExW(open_with_key, L"command", 0, nullptr, 0,
                            KEY_WRITE, nullptr, &command_key,
                            nullptr) == ERROR_SUCCESS) {
        SetRegistryString(command_key, nullptr, command);
        ::RegCloseKey(command_key);
      }
      ::RegCloseKey(open_with_key);
    }
    ::RegCloseKey(class_key);

    // Point the extension at the app class so Explorer offers OronBox.
    HKEY ext_key = nullptr;
    if (::RegCreateKeyExW(HKEY_CURRENT_USER,
                          (L"Software\\Classes\\" + std::wstring(extensions[i]))
                              .c_str(),
                          0, nullptr, 0, KEY_WRITE, nullptr, &ext_key,
                          nullptr) == ERROR_SUCCESS) {
      SetRegistryString(ext_key, nullptr, class_name);
      ::RegCloseKey(ext_key);
    }
  }
}

// Extracts a file path from the command line when the app was launched by
// opening one of the claimed extensions (e.g. double-click in Explorer).
std::string FilePathFromArguments(
    const std::vector<std::string> &arguments) {
  for (const std::string &argument : arguments) {
    if (argument.empty() || argument[0] == '-') {
      continue;
    }
    std::string lower = argument;
    std::transform(lower.begin(), lower.end(), lower.begin(),
                   [](unsigned char value) {
                     return static_cast<char>(std::tolower(value));
                   });
    for (const char *extension : {".rpk", ".bin", ".face", ".zpk", ".mwz",
                                  ".obp", ".abp"}) {
      if (lower.size() >= strlen(extension) &&
          lower.compare(lower.size() - strlen(extension), strlen(extension),
                        extension) == 0) {
        return argument;
      }
    }
  }
  return "";
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
  RegisterFileAssociations();

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  const std::string initial_open_path =
      FilePathFromArguments(command_line_arguments);

  const bool no_gui =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--nogui") != command_line_arguments.end();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, initial_open_path, !no_gui);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"OronBox", origin, size)) {
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
