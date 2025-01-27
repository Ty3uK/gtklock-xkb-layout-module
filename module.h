#include <gtk/gtk.h>
#include <xkbcommon/xkbcommon.h>

typedef char Layout[16];

struct State {
  struct xkb_context *xkb_context;
  struct xkb_keymap *xkb_keymap;
  GtkWidget *gtk_label;
  GHashTable *formats;
  GArray *labels;
  void (*on_keyboard_layout_change)(void *data, int index);
};
