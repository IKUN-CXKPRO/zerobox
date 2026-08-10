#pragma once

#include <flutter/binary_messenger.h>

#include <string>

/// Registers the "oronbox/file_open" channel and immediately pushes a file
/// path received from the command line (cold start), if any.
void RegisterFileOpenChannel(flutter::BinaryMessenger* messenger,
                             const std::string& initial_path);
