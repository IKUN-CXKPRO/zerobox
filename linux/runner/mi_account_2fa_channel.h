#ifndef FLUTTER_MI_ACCOUNT_2FA_CHANNEL_H_
#define FLUTTER_MI_ACCOUNT_2FA_CHANNEL_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

void mi_account_2fa_channel_register(FlBinaryMessenger* messenger,
                                     GtkOverlay* overlay);

#endif  // FLUTTER_MI_ACCOUNT_2FA_CHANNEL_H_

