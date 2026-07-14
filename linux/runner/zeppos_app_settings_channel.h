#ifndef RUNNER_ZEPPOS_APP_SETTINGS_CHANNEL_H_
#define RUNNER_ZEPPOS_APP_SETTINGS_CHANNEL_H_
#include <flutter_linux/flutter_linux.h>
void zeppos_app_settings_channel_register(FlBinaryMessenger* messenger,
                                          GtkOverlay* overlay);
#endif
