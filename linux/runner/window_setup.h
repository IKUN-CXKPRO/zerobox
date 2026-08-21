#ifndef RUNNER_WINDOW_SETUP_H_
#define RUNNER_WINDOW_SETUP_H_

#include <gtk/gtk.h>

void oronbox_set_window_icon(GtkWindow* window);
gboolean oronbox_restore_flutter_focus(GtkWidget* widget,
                                       GdkEventButton* event,
                                       gpointer user_data);

#endif  // RUNNER_WINDOW_SETUP_H_
