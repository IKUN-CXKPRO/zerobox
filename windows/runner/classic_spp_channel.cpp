#include "classic_spp_channel.h"

#include <bluetoothapis.h>
#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <winsock2.h>
#include <ws2bth.h>

#include <algorithm>
#include <atomic>
#include <cstdint>
#include <chrono>
#include <iomanip>
#include <memory>
#include <mutex>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

SOCKET g_socket = INVALID_SOCKET;
SOCKET g_connect_socket = INVALID_SOCKET;
std::mutex g_socket_mutex;
std::thread g_read_thread;
std::atomic_bool g_read_running(false);
std::atomic_bool g_emit_disconnect_on_read_close(true);
std::atomic_uint64_t g_connect_generation(0);
std::atomic_uint64_t g_scan_generation(0);
std::unique_ptr<flutter::EventSink<EncodableValue>> g_event_sink;
std::unique_ptr<flutter::EventSink<EncodableValue>> g_scan_event_sink;

std::string WideToUtf8(const wchar_t* text) {
  if (text == nullptr || text[0] == L'\0') {
    return "";
  }
  const int size = WideCharToMultiByte(CP_UTF8, 0, text, -1, nullptr, 0, nullptr, nullptr);
  if (size <= 1) {
    return "";
  }
  std::string result(static_cast<size_t>(size - 1), '\0');
  WideCharToMultiByte(CP_UTF8, 0, text, -1, result.data(), size, nullptr, nullptr);
  return result;
}

std::string AddressToString(BTH_ADDR addr) {
  std::ostringstream out;
  out << std::uppercase << std::hex << std::setfill('0');
  for (int i = 5; i >= 0; --i) {
    if (i != 5) {
      out << ':';
    }
    out << std::setw(2) << ((addr >> (i * 8)) & 0xff);
  }
  return out.str();
}

bool ParseAddress(const std::string& text, BTH_ADDR* out) {
  std::string digits;
  for (char c : text) {
    if (c == ':' || c == '-' || c == ' ') {
      continue;
    }
    digits.push_back(c);
  }
  if (digits.size() != 12) {
    return false;
  }
  unsigned long long value = 0;
  std::istringstream in(digits);
  in >> std::hex >> value;
  if (in.fail()) {
    return false;
  }
  *out = static_cast<BTH_ADDR>(value);
  return true;
}

EncodableMap DeviceToMap(const BLUETOOTH_DEVICE_INFO& info) {
  return EncodableMap{
      {EncodableValue("addr"), EncodableValue(AddressToString(info.Address.ullLong))},
      {EncodableValue("name"), EncodableValue(WideToUtf8(info.szName))},
      {EncodableValue("connectType"), EncodableValue("spp")},
  };
}

int ArgInt(const EncodableMap& args, const char* key, int fallback) {
  auto it = args.find(EncodableValue(key));
  if (it == args.end()) {
    return fallback;
  }
  if (std::holds_alternative<int>(it->second)) {
    return std::get<int>(it->second);
  }
  if (std::holds_alternative<int64_t>(it->second)) {
    return static_cast<int>(std::get<int64_t>(it->second));
  }
  return fallback;
}

EncodableList BluetoothDevices(bool issue_inquiry = false,
                               int timeout_ms = 15000,
                               uint64_t scan_generation = 0) {
  EncodableList devices;
  BLUETOOTH_DEVICE_SEARCH_PARAMS params = {};
  params.dwSize = sizeof(params);
  params.fReturnAuthenticated = TRUE;
  params.fReturnRemembered = TRUE;
  params.fReturnUnknown = issue_inquiry ? TRUE : FALSE;
  params.fReturnConnected = TRUE;
  params.fIssueInquiry = issue_inquiry ? TRUE : FALSE;
  params.cTimeoutMultiplier = static_cast<UCHAR>(
      std::clamp((timeout_ms + 1279) / 1280, 1, 48));

  BLUETOOTH_DEVICE_INFO info = {};
  info.dwSize = sizeof(info);
  HBLUETOOTH_DEVICE_FIND handle = BluetoothFindFirstDevice(&params, &info);
  if (handle == nullptr) {
    return devices;
  }
  do {
    if (scan_generation != 0 && scan_generation != g_scan_generation.load()) {
      break;
    }
    auto item = DeviceToMap(info);
    devices.emplace_back(item);
    if (g_scan_event_sink) {
      g_scan_event_sink->Success(EncodableValue(item));
    }
    info = {};
    info.dwSize = sizeof(info);
  } while (BluetoothFindNextDevice(handle, &info));
  BluetoothFindDeviceClose(handle);
  return devices;
}

EncodableList PairedDevices() {
  return BluetoothDevices(false);
}

void SendDisconnectedEvent() {
  if (g_event_sink) {
    g_event_sink->Success(EncodableValue(EncodableMap{
        {EncodableValue("event"), EncodableValue("disconnected")},
    }));
  }
}

void CloseSocket() {
  SOCKET socket = INVALID_SOCKET;
  SOCKET connect_socket = INVALID_SOCKET;
  {
    std::lock_guard<std::mutex> lock(g_socket_mutex);
    socket = g_socket;
    g_socket = INVALID_SOCKET;
    connect_socket = g_connect_socket;
    g_connect_socket = INVALID_SOCKET;
  }
  if (connect_socket != INVALID_SOCKET) {
    shutdown(connect_socket, SD_BOTH);
    closesocket(connect_socket);
  }
  if (socket != INVALID_SOCKET) {
    shutdown(socket, SD_BOTH);
    closesocket(socket);
  }
}

void CloseConnectSocketIfOwned(SOCKET socket) {
  bool should_close = false;
  {
    std::lock_guard<std::mutex> lock(g_socket_mutex);
    if (g_connect_socket == socket) {
      g_connect_socket = INVALID_SOCKET;
      should_close = true;
    }
  }
  if (should_close) {
    closesocket(socket);
  }
}

void StopReadThread() {
  g_read_running = false;
  g_emit_disconnect_on_read_close = false;
  CloseSocket();
  if (g_read_thread.joinable()) {
    g_read_thread.join();
  }
  g_emit_disconnect_on_read_close = true;
}

void StartReadThread() {
  g_read_running = true;
  g_emit_disconnect_on_read_close = true;
  g_read_thread = std::thread([] {
    std::vector<uint8_t> buffer(4096);
    while (g_read_running) {
      SOCKET socket = INVALID_SOCKET;
      {
        std::lock_guard<std::mutex> lock(g_socket_mutex);
        socket = g_socket;
      }
      if (socket == INVALID_SOCKET) {
        break;
      }
      const int read = recv(socket, reinterpret_cast<char*>(buffer.data()),
                            static_cast<int>(buffer.size()), 0);
      if (read <= 0) {
        break;
      }
      if (g_event_sink) {
        std::vector<uint8_t> packet(buffer.begin(), buffer.begin() + read);
        g_event_sink->Success(EncodableValue(packet));
      }
    }
    g_read_running = false;
    CloseSocket();
    if (g_emit_disconnect_on_read_close) {
      SendDisconnectedEvent();
    }
  });
}

SOCKET ConnectRfcomm(BTH_ADDR address, int channel, uint64_t generation,
                     int timeout_ms) {
  SOCKET socket = ::socket(AF_BTH, SOCK_STREAM, BTHPROTO_RFCOMM);
  if (socket == INVALID_SOCKET) {
    return INVALID_SOCKET;
  }
  {
    std::lock_guard<std::mutex> lock(g_socket_mutex);
    if (generation != g_connect_generation.load()) {
      g_connect_socket = INVALID_SOCKET;
      closesocket(socket);
      return INVALID_SOCKET;
    }
    g_connect_socket = socket;
  }

  SOCKADDR_BTH remote = {};
  remote.addressFamily = AF_BTH;
  remote.btAddr = address;
  remote.port = static_cast<ULONG>(channel);

  u_long non_blocking = 1;
  ioctlsocket(socket, FIONBIO, &non_blocking);

  int rc = connect(socket, reinterpret_cast<sockaddr*>(&remote), sizeof(remote));
  if (rc == SOCKET_ERROR) {
    const int error = WSAGetLastError();
    if (error != WSAEWOULDBLOCK && error != WSAEINPROGRESS &&
        error != WSAEINVAL) {
      CloseConnectSocketIfOwned(socket);
      return INVALID_SOCKET;
    }

    const auto deadline =
        std::chrono::steady_clock::now() + std::chrono::milliseconds(timeout_ms);
    while (true) {
      if (generation != g_connect_generation.load()) {
        CloseConnectSocketIfOwned(socket);
        return INVALID_SOCKET;
      }
      const auto now = std::chrono::steady_clock::now();
      if (now >= deadline) {
        CloseConnectSocketIfOwned(socket);
        return INVALID_SOCKET;
      }

      const auto wait = std::min(
          std::chrono::milliseconds(250),
          std::chrono::duration_cast<std::chrono::milliseconds>(deadline - now));
      fd_set write_fds;
      FD_ZERO(&write_fds);
      FD_SET(socket, &write_fds);
      timeval tv = {};
      tv.tv_sec = static_cast<long>(wait.count() / 1000);
      tv.tv_usec = static_cast<long>((wait.count() % 1000) * 1000);
      rc = select(0, nullptr, &write_fds, nullptr, &tv);
      if (rc == SOCKET_ERROR) {
        CloseConnectSocketIfOwned(socket);
        return INVALID_SOCKET;
      }
      if (rc == 0) {
        continue;
      }

      int socket_error = 0;
      int len = sizeof(socket_error);
      if (getsockopt(socket, SOL_SOCKET, SO_ERROR,
                     reinterpret_cast<char*>(&socket_error), &len) ==
              SOCKET_ERROR ||
          socket_error != 0) {
        CloseConnectSocketIfOwned(socket);
        return INVALID_SOCKET;
      }
      break;
    }
  }

  non_blocking = 0;
  ioctlsocket(socket, FIONBIO, &non_blocking);
  {
    std::lock_guard<std::mutex> lock(g_socket_mutex);
    if (g_connect_socket == socket) {
      g_connect_socket = INVALID_SOCKET;
    }
    if (generation != g_connect_generation.load()) {
      closesocket(socket);
      return INVALID_SOCKET;
    }
  }
  return socket;
}

std::vector<int> FallbackChannels(const EncodableMap& args) {
  auto it = args.find(EncodableValue("fallbackChannels"));
  if (it == args.end() || !std::holds_alternative<EncodableList>(it->second)) {
    return {5, 1};
  }
  std::vector<int> channels;
  for (const auto& item : std::get<EncodableList>(it->second)) {
    if (!std::holds_alternative<int>(item)) {
      continue;
    }
    int channel = std::get<int>(item);
    if (channel >= 1 && channel <= 30 &&
        std::find(channels.begin(), channels.end(), channel) == channels.end()) {
      channels.push_back(channel);
    }
  }
  if (channels.empty()) {
    channels = {5, 1};
  }
  return channels;
}

void HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  if (call.method_name() == "requestPermissions") {
    result->Success();
    return;
  }
  if (call.method_name() == "startScan") {
    int timeout_ms = 15000;
    if (call.arguments() && std::holds_alternative<EncodableMap>(*call.arguments())) {
      const auto& args = std::get<EncodableMap>(*call.arguments());
      timeout_ms = ArgInt(args, "timeoutMs", timeout_ms);
    }
    timeout_ms = std::clamp(timeout_ms, 1280, 60000);
    const uint64_t scan_generation = g_scan_generation.fetch_add(1) + 1;
    result->Success();
    std::thread([scan_generation, timeout_ms] {
      BluetoothDevices(true, timeout_ms, scan_generation);
    }).detach();
    return;
  }
  if (call.method_name() == "stopScan") {
    g_scan_generation.fetch_add(1);
    result->Success(EncodableValue(PairedDevices()));
    return;
  }
  if (call.method_name() == "disconnect") {
    g_connect_generation.fetch_add(1);
    StopReadThread();
    result->Success();
    return;
  }
  if (!call.arguments() || !std::holds_alternative<EncodableMap>(*call.arguments())) {
    result->Error("INVALID_ARGUMENT", "arguments are required");
    return;
  }
  const auto& args = std::get<EncodableMap>(*call.arguments());

  if (call.method_name() == "connect") {
    auto addr_it = args.find(EncodableValue("addr"));
    if (addr_it == args.end() || !std::holds_alternative<std::string>(addr_it->second)) {
      result->Error("INVALID_ARGUMENT", "addr is required");
      return;
    }
    BTH_ADDR address = 0;
    if (!ParseAddress(std::get<std::string>(addr_it->second), &address)) {
      result->Error("INVALID_ARGUMENT", "addr is invalid");
      return;
    }
    const auto channels = FallbackChannels(args);
    const uint64_t generation = g_connect_generation.fetch_add(1) + 1;
    StopReadThread();
    std::thread([address, channels, generation,
                 result = std::move(result)]() mutable {
      SOCKET connected = INVALID_SOCKET;
      int connected_channel = 0;
      for (int channel : channels) {
        if (generation != g_connect_generation.load()) {
          break;
        }
        connected = ConnectRfcomm(address, channel, generation, 10000);
        if (connected != INVALID_SOCKET) {
          connected_channel = channel;
          break;
        }
      }
      if (connected == INVALID_SOCKET ||
          generation != g_connect_generation.load()) {
        if (connected != INVALID_SOCKET) {
          closesocket(connected);
        }
        result->Error(
            generation == g_connect_generation.load() ? "CONNECT_FAILED"
                                                      : "CONNECT_CANCELLED",
            generation == g_connect_generation.load()
                ? "No RFCOMM channel available"
                : "SPP connect was cancelled");
        return;
      }
      {
        std::lock_guard<std::mutex> lock(g_socket_mutex);
        g_socket = connected;
      }
      StartReadThread();
      result->Success(EncodableValue(EncodableMap{
          {EncodableValue("channel"), EncodableValue(connected_channel)},
      }));
    }).detach();
    return;
  }

  if (call.method_name() == "send") {
    auto data_it = args.find(EncodableValue("data"));
    if (data_it == args.end() || !std::holds_alternative<std::vector<uint8_t>>(data_it->second)) {
      result->Error("INVALID_ARGUMENT", "data is required");
      return;
    }
    SOCKET socket = INVALID_SOCKET;
    {
      std::lock_guard<std::mutex> lock(g_socket_mutex);
      socket = g_socket;
    }
    if (socket == INVALID_SOCKET) {
      result->Error("NOT_CONNECTED", "SPP socket is not connected");
      return;
    }
    const auto& data = std::get<std::vector<uint8_t>>(data_it->second);
    int offset = 0;
    while (offset < static_cast<int>(data.size())) {
      const int sent = send(socket, reinterpret_cast<const char*>(data.data()) + offset,
                            static_cast<int>(data.size()) - offset, 0);
      if (sent <= 0) {
        result->Error("SEND_FAILED", "RFCOMM send failed");
        return;
      }
      offset += sent;
    }
    result->Success();
    return;
  }

  result->NotImplemented();
}

}  // namespace

void RegisterRfcommChannel(flutter::BinaryMessenger* messenger) {
  WSADATA data;
  WSAStartup(MAKEWORD(2, 2), &data);

  auto method_channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "zerobox/classic_spp",
      &flutter::StandardMethodCodec::GetInstance());
  method_channel->SetMethodCallHandler(HandleMethodCall);
  method_channel.release();

  auto event_channel = std::make_unique<flutter::EventChannel<EncodableValue>>(
      messenger, "zerobox/classic_spp/events",
      &flutter::StandardMethodCodec::GetInstance());
  event_channel->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
          [](const EncodableValue*,
             std::unique_ptr<flutter::EventSink<EncodableValue>>&& events)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            g_event_sink = std::move(events);
            return nullptr;
          },
          [](const EncodableValue*)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            g_event_sink.reset();
            return nullptr;
          }));
  event_channel.release();

  auto scan_channel = std::make_unique<flutter::EventChannel<EncodableValue>>(
      messenger, "zerobox/classic_spp/scan_events",
      &flutter::StandardMethodCodec::GetInstance());
  scan_channel->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
          [](const EncodableValue*,
             std::unique_ptr<flutter::EventSink<EncodableValue>>&& events)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            g_scan_event_sink = std::move(events);
            return nullptr;
          },
          [](const EncodableValue*)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            g_scan_event_sink.reset();
            return nullptr;
          }));
  scan_channel.release();
}
