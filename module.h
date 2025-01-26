#include <gtk/gtk.h>
#include <xkbcommon/xkbcommon.h>

struct State {
  struct xkb_context *xkb_context;
  struct xkb_keymap *xkb_keymap;
  GtkWidget *gtk_label;
  GHashTable *formats;
  GHashTable *labels;
  void (*on_keyboard_layout_change)(void *data, const char *layout_name);
};
