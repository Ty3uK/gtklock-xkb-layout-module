#include "module.h"
#include "gtklock-module.h"
#include <assert.h>
#include <gdk/gdkwayland.h>
#include <glib.h>
#include <gtk/gtk.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/unistd.h>
#include <wayland-client-core.h>
#include <wayland-client-protocol.h>
#include <wayland-client.h>
#include <wayland.h>
#include <xkbcommon/xkbcommon.h>
#include <xkbcommon/xkbregistry.h>

#define MODULE_DATA(x) (x->module_data[self_id])

const gchar module_name[] = "xkb-layout";
const guint module_major_version = 4;
const guint module_minor_version = 0;

static gchar **formats = NULL;
static guint font_size = 0;
static guint width_chars = 2;

GOptionEntry module_entries[] = {
    {"formats", 0, 0, G_OPTION_ARG_STRING_ARRAY, &formats, NULL, NULL},
    {"font-size", 0, 0, G_OPTION_ARG_INT, &font_size, NULL, NULL},
    {"width-chars", 0, 0, G_OPTION_ARG_INT, &width_chars, NULL, NULL},
    {NULL},
};

static int self_id;

static void handle_keyboard_layout_change(void *data, const char *layout_name) {
  struct State *state = data;
  gchar *label = (gchar *)layout_name;
  gchar *layout_code = g_hash_table_lookup(state->labels, layout_name);
  if (layout_code) {
    label = g_hash_table_lookup(state->formats, layout_code);
    if (!label) {
      label = layout_code;
    }
  }
  gtk_label_set_text(GTK_LABEL(state->gtk_label), label);
}

static void set_label_font_size(GtkLabel *label, int font_size) {
  PangoAttrList *list = pango_attr_list_new();
  PangoFontDescription *font_description = pango_font_description_new();
  pango_font_description_set_size(font_description, font_size * PANGO_SCALE);
  PangoAttribute *attr = pango_attr_font_desc_new(font_description);
  pango_attr_list_insert(list, attr);
  gtk_label_set_attributes(label, list);
}

static void cleanup(struct Window *win) {
  struct State *state = win->module_data[self_id];
  if (state->formats) {
    g_hash_table_destroy(state->formats);
  }
  if (state->labels) {
    g_hash_table_destroy(state->labels);
  }
  if (state->xkb_keymap) {
    xkb_keymap_unref(state->xkb_keymap);
  }
  if (state->xkb_context) {
    xkb_context_unref(state->xkb_context);
  }
  if (state->gtk_label) {
    gtk_widget_destroy(state->gtk_label);
  }
  g_free(state);
  MODULE_DATA(win) = NULL;
}

static GHashTable *setup_layout_codes() {
  GHashTable *result = g_hash_table_new(g_str_hash, g_str_equal);
  struct rxkb_context *ctx = rxkb_context_new(RXKB_CONTEXT_NO_FLAGS);
  if (!rxkb_context_parse_default_ruleset(ctx)) {
    return result;
  }
  struct rxkb_layout *l = rxkb_layout_first(ctx);
  while (l) {
    gchar *key = g_strdup(rxkb_layout_get_description(l));
    gchar *val = g_strdup(rxkb_layout_get_name(l));
    g_hash_table_insert(result, key, val);
    l = rxkb_layout_next(l);
  }
  rxkb_layout_unref(l);
  rxkb_context_unref(ctx);
  return result;
}

static GHashTable *setup_layout_formats() {
  GHashTable *result = g_hash_table_new(g_str_hash, g_str_equal);
  if (formats) {
    for (guint i = 0; formats[i] != NULL; i++) {
      gchar **splitted = g_strsplit(formats[i], "=", 2);
      g_hash_table_insert(result, splitted[0], splitted[1]);
    }
  }
  return result;
}

void on_activation(struct GtkLock *gtklock, int id) { self_id = id; }

void on_window_destroy(struct GtkLock *gtklock, struct Window *win) {
  if (MODULE_DATA(win) != NULL) {
    cleanup(win);
  }
}

void on_window_create(struct GtkLock *gtklock, struct Window *win) {
  if (MODULE_DATA(win) != NULL) {
    cleanup(win);
  }

  MODULE_DATA(win) = g_malloc(sizeof(struct State));
  struct State *state = win->module_data[self_id];
  state->on_keyboard_layout_change = handle_keyboard_layout_change;
  state->labels = setup_layout_codes();
  state->formats = setup_layout_formats();
  state->xkb_context = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
  state->gtk_label = gtk_label_new("");
  gtk_label_set_width_chars(GTK_LABEL(state->gtk_label), width_chars);
  gtk_container_add(GTK_CONTAINER(gtk_widget_get_parent(win->input_field)),
                    state->gtk_label);
  gtk_widget_show_all(state->gtk_label);
  if (font_size > 0) {
    set_label_font_size(GTK_LABEL(state->gtk_label), font_size);
  }
  setup_wayland_registry(state);
}
