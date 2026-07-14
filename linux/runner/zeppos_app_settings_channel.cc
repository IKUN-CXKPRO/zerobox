#include "zeppos_app_settings_channel.h"
#include <webkit2/webkit2.h>
#include <cstring>

namespace {
struct Session { GtkOverlay* overlay = nullptr; GtkWidget* frame = nullptr; WebKitWebView* view = nullptr; FlMethodChannel* channel = nullptr; int app_id = 0; } session;
FlValue* arg(FlMethodCall* call, const char* key) { FlValue* args = fl_method_call_get_args(call); return args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP ? fl_value_lookup_string(args, key) : nullptr; }
void send(const char* method, FlValue* args) { fl_method_channel_invoke_method(session.channel, method, args, nullptr, nullptr, nullptr); }
void close_session(bool notify) {
  if (notify && session.app_id) { g_autoptr(FlValue) args = fl_value_new_map(); fl_value_set_string_take(args, "appId", fl_value_new_int(session.app_id)); send("closed", args); }
  if (session.frame) gtk_widget_destroy(session.frame);
  session.frame = nullptr; session.view = nullptr; session.app_id = 0;
}
void script_message(WebKitUserContentManager*, WebKitJavascriptResult* result, gpointer) {
  JSCValue* value = webkit_javascript_result_get_js_value(result); g_autofree gchar* text = jsc_value_to_string(value);
  if (!text || !session.app_id) return;
  g_autoptr(FlValue) args = fl_value_new_map(); fl_value_set_string_take(args, "appId", fl_value_new_int(session.app_id)); fl_value_set_string_take(args, "message", fl_value_new_string(text)); send("bridge", args);
}
GtkWidget* build(const char* title, const char* html) {
  GtkWidget* frame = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0); gtk_widget_set_size_request(frame, 720, 720); gtk_widget_set_halign(frame, GTK_ALIGN_CENTER); gtk_widget_set_valign(frame, GTK_ALIGN_CENTER);
  GtkWidget* header = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8); GtkWidget* label = gtk_label_new(title); gtk_widget_set_hexpand(label, TRUE); gtk_widget_set_halign(label, GTK_ALIGN_START); GtkWidget* close = gtk_button_new_with_label("关闭");
  g_signal_connect(close, "clicked", G_CALLBACK(+[](GtkButton*, gpointer){ close_session(true); }), nullptr); gtk_box_pack_start(GTK_BOX(header), label, TRUE, TRUE, 12); gtk_box_pack_end(GTK_BOX(header), close, FALSE, FALSE, 12); gtk_box_pack_start(GTK_BOX(frame), header, FALSE, FALSE, 8);
  WebKitUserContentManager* manager = webkit_user_content_manager_new(); webkit_user_content_manager_register_script_message_handler(manager, "ZeppSettingsBridge"); g_signal_connect(manager, "script-message-received::ZeppSettingsBridge", G_CALLBACK(script_message), nullptr);
  GtkWidget* view = webkit_web_view_new_with_user_content_manager(manager); g_object_unref(manager); session.view = WEBKIT_WEB_VIEW(view); webkit_settings_set_enable_javascript(webkit_web_view_get_settings(session.view), TRUE); gtk_box_pack_end(GTK_BOX(frame), view, TRUE, TRUE, 0); webkit_web_view_load_html(session.view, html, nullptr); return frame;
}
void call_cb(FlMethodChannel*, FlMethodCall* call, gpointer) {
  const char* method = fl_method_call_get_name(call); g_autoptr(GError) error = nullptr;
  if (strcmp(method, "open") == 0) {
    FlValue *id = arg(call, "appId"), *html = arg(call, "html"), *title = arg(call, "title");
    if (!id || !html || fl_value_get_type(id) != FL_VALUE_TYPE_INT || fl_value_get_type(html) != FL_VALUE_TYPE_STRING) { fl_method_call_respond_error(call, "INVALID_ARGUMENT", "appId and html are required", nullptr, &error); return; }
    close_session(true); session.app_id = fl_value_get_int(id); session.frame = build(title && fl_value_get_type(title) == FL_VALUE_TYPE_STRING ? fl_value_get_string(title) : "应用设置", fl_value_get_string(html)); gtk_overlay_add_overlay(session.overlay, session.frame); gtk_widget_show_all(session.frame); fl_method_call_respond_success(call, nullptr, &error); return;
  }
  if (strcmp(method, "settingsChanged") == 0) {
    FlValue *id = arg(call, "appId"), *json = arg(call, "settingsJson");
    if (session.view && id && json && fl_value_get_type(id) == FL_VALUE_TYPE_INT && fl_value_get_type(json) == FL_VALUE_TYPE_STRING && fl_value_get_int(id) == session.app_id) {
      g_autofree gchar* script = g_strdup_printf("globalThis.__zeroboxSettingsChanged(%s)", fl_value_get_string(json));
#if WEBKIT_MAJOR_VERSION < 2 || (WEBKIT_MAJOR_VERSION == 2 && WEBKIT_MINOR_VERSION < 40)
      webkit_web_view_run_javascript(session.view, script, nullptr, nullptr, nullptr);
#else
      webkit_web_view_evaluate_javascript(session.view, script, -1, nullptr, nullptr, nullptr, nullptr, nullptr);
#endif
    }
    fl_method_call_respond_success(call, nullptr, &error); return;
  }
  fl_method_call_respond_not_implemented(call, &error);
}
}
void zeppos_app_settings_channel_register(FlBinaryMessenger* messenger, GtkOverlay* overlay) {
  session.overlay = overlay; g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new(); session.channel = fl_method_channel_new(messenger, "zerobox/zeppos_app_settings", FL_METHOD_CODEC(codec)); fl_method_channel_set_method_call_handler(session.channel, call_cb, nullptr, nullptr);
}
