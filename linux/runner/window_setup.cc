#include "window_setup.h"

#include <flutter_linux/flutter_linux.h>

// Native overlays can take GTK focus away from Flutter. Restore it when the
// user returns to the Flutter surface while leaving the event available to
// Flutter's normal hit testing.
gboolean oronbox_restore_flutter_focus(GtkWidget* widget,
                                       GdkEventButton*, gpointer) {
  gtk_widget_grab_focus(widget);
  return FALSE;
}

void oronbox_set_window_icon(GtkWindow* window) {
  gtk_window_set_icon_name(window, APPLICATION_ID);
  g_autofree gchar* executable = g_file_read_link("/proc/self/exe", nullptr);
  if (executable == nullptr) return;
  g_autofree gchar* executable_dir = g_path_get_dirname(executable);
  g_autofree gchar* icon_path = g_build_filename(
      executable_dir, "data", "flutter_assets", "assets", "images",
      "app_icon.png", nullptr);
  if (g_file_test(icon_path, G_FILE_TEST_IS_REGULAR)) {
    gtk_window_set_icon_from_file(window, icon_path, nullptr);
  }
}
