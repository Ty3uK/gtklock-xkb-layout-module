#include "module.h"
#include <assert.h>
#include <gdk/gdk.h>
#include <gdk/gdkwayland.h>
#include <sys/mman.h>
#include <wayland-client-protocol.h>
#include <wayland-client.h>
#include <xkbcommon/xkbcommon.h>
#include <xkbcommon/xkbregistry.h>

static void handle_keyboard_keymap(void *data, struct wl_keyboard *keyboard,
                                   uint32_t format, int fd, uint32_t size) {
  struct State *state = data;
  assert(format == WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1);
  char *map_shm = mmap(NULL, size, PROT_READ, MAP_PRIVATE, fd, 0);
  assert(map_shm != MAP_FAILED);
  state->xkb_keymap = xkb_keymap_new_from_string(state->xkb_context, map_shm,
                                                 XKB_KEYMAP_FORMAT_TEXT_V1,
                                                 XKB_KEYMAP_COMPILE_NO_FLAGS);

  munmap(map_shm, size);
  close(fd);

  xkb_layout_index_t nums = xkb_keymap_num_layouts(state->xkb_keymap);
  state->labels = g_array_sized_new(FALSE, TRUE, sizeof(Layout*), nums);
  struct rxkb_context *ctx = rxkb_context_new(RXKB_CONTEXT_NO_FLAGS);
  if (!rxkb_context_parse_default_ruleset(ctx)) {
    return;
  }
  struct rxkb_layout *l;
  for (xkb_layout_index_t i = 0; i < nums; i++) {
    const char *layout_name = xkb_keymap_layout_get_name(state->xkb_keymap, i);
    l = rxkb_layout_first(ctx);
    while (l) {
      if (g_strcmp0(rxkb_layout_get_description(l), layout_name) == 0) {
        char *value = g_strdup(rxkb_layout_get_name(l));
        g_array_append_val(state->labels, *value);
        break;
      }
      l = rxkb_layout_next(l);
    }
  }
  rxkb_context_unref(ctx);
}

static void handle_keyboard_modifiers(void *data, struct wl_keyboard *keyboard,
                                      uint32_t serial, uint32_t mods_depressed,
                                      uint32_t mods_latched,
                                      uint32_t mods_locked, uint32_t group) {
  struct State *state = data;
  if (state->on_keyboard_layout_change) {
    state->on_keyboard_layout_change(data, group);
  }
}

static void handle_keyboard_enter(void *data, struct wl_keyboard *keyboard,
                                  uint32_t serial, struct wl_surface *surface,
                                  struct wl_array *keys) {}
static void handle_keyboard_leave(void *data, struct wl_keyboard *keyboard,
                                  uint32_t serial, struct wl_surface *surface) {
}
static void handle_keyboard_key(void *data, struct wl_keyboard *keyboard,
                                uint32_t serial, uint32_t time, uint32_t key,
                                uint32_t state) {}
static void handle_keyboard_repeat_info(void *data,
                                        struct wl_keyboard *keyboard,
                                        int32_t rate, int32_t delay) {}

static const struct wl_keyboard_listener keyboard_listener = {
    .keymap = handle_keyboard_keymap,
    .enter = handle_keyboard_enter,
    .leave = handle_keyboard_leave,
    .key = handle_keyboard_key,
    .modifiers = handle_keyboard_modifiers,
    .repeat_info = handle_keyboard_repeat_info,
};

static void handle_seat_capabilities(void *data, struct wl_seat *wl_seat,
                                     uint32_t capabilities) {
  if (capabilities & WL_SEAT_CAPABILITY_KEYBOARD) {
    struct wl_keyboard *wl_keyboard = wl_seat_get_keyboard(wl_seat);
    wl_keyboard_add_listener(wl_keyboard, &keyboard_listener, data);
  }
}
static void handle_seat_name(void *data, struct wl_seat *wl_seat,
                             const char *name) {}

static const struct wl_seat_listener seat_listener = {
    .name = handle_seat_name,
    .capabilities = handle_seat_capabilities,
};

static void handle_registry_global(void *data, struct wl_registry *registry,
                                   uint32_t id, const char *interface,
                                   uint32_t version) {
  if (g_strcmp0(interface, "wl_seat") == 0) {
    struct wl_seat *wl_seat =
        wl_registry_bind(registry, id, &wl_seat_interface, 7);
    wl_seat_add_listener(wl_seat, &seat_listener, data);
  }
}

static void handle_registry_remove_global(void *data,
                                          struct wl_registry *wl_registry,
                                          uint32_t name) {
  g_print("wl_registry remove global\n");
}

static const struct wl_registry_listener registry_listener = {
    .global = handle_registry_global,
    .global_remove = handle_registry_remove_global,
};

void setup_wayland_registry(void *data) {
  struct wl_display *wl_display =
      gdk_wayland_display_get_wl_display(gdk_display_get_default());
  struct wl_registry *wl_registry = wl_display_get_registry(wl_display);
  wl_registry_add_listener(wl_registry, &registry_listener, data);
}
