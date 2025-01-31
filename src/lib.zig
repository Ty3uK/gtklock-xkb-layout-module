const std = @import("std");
const glib = @import("glib");
const gtk = @import("gtk");
const pango = @import("pango");
const gdk = @import("gdk");
const gdkwayland = @import("gdkwayland");
const wl = @import("wayland").client.wl;
const gtklock = @import("./gtklock.zig");
const util = @import("./util.zig");
const State = @import("./state.zig").State;

const xkb = @cImport({
    @cInclude("xkbcommon/xkbcommon.h");
    @cInclude("xkbcommon/xkbregistry.h");
});

const log = std.log.scoped(.xkb_layout_module);

pub export const module_name = "xkb-layout".*;
pub export const module_major_version: c_int = 4;
pub export const module_minor_version: c_int = 0;

var config_formats: [*c][*c]const u8 = null;
var config_font_size: c_int = 0;
var config_width_chars: c_int = 2;

pub export const module_entries = [_]glib.OptionEntry{
    glib.OptionEntry{
        .f_long_name = "formats",
        .f_short_name = 0,
        .f_flags = 0,
        .f_arg = glib.OptionArg.string_array,
        .f_arg_data = @ptrCast(&config_formats),
        .f_description = null,
        .f_arg_description = null,
    },
    glib.OptionEntry{
        .f_long_name = "font-size",
        .f_short_name = 0,
        .f_flags = 0,
        .f_arg = glib.OptionArg.int,
        .f_arg_data = @ptrCast(&config_font_size),
        .f_description = null,
        .f_arg_description = null,
    },
    glib.OptionEntry{
        .f_long_name = "width-chars",
        .f_short_name = 0,
        .f_flags = 0,
        .f_arg = glib.OptionArg.int,
        .f_arg_data = @ptrCast(&config_width_chars),
        .f_description = null,
        .f_arg_description = null,
    },
    glib.OptionEntry{
        .f_long_name = null,
        .f_short_name = 0,
        .f_flags = 0,
        .f_arg = glib.OptionArg.none,
        .f_arg_data = null,
        .f_description = null,
        .f_arg_description = null,
    },
};

var selfId: usize = undefined;

pub export fn on_activation(_: ?*anyopaque, id: c_int) void {
    selfId = @intCast(id);
}

pub export fn on_window_destroy(_: ?*anyopaque, ctx: *gtklock.Window(State)) void {
    const state_ptr = ctx.moduleData()[selfId];
    if (state_ptr) |state| {
        state.deinit();
    }
}

pub export fn on_window_create(_: ?*anyopaque, ctx: *gtklock.Window(State)) void {
    const state = State.init(std.heap.page_allocator) catch |err| {
        log.err("Cannot create state: {}", .{err});
        return;
    };
    state.parseFormats(config_formats) catch |err| {
        log.err("Cannot parse formats from config: {}", .{err});
        return;
    };

    state.gtk_label.setWidthChars(config_width_chars);
    if (config_font_size > 0) {
        state.gtk_label.setAttributes(util.createFontSizeAttrList(config_font_size));
    }

    const container: *gtk.Container = @ptrCast(ctx.input_field.getParent().?);
    container.add(state.gtk_label.as(gtk.Widget));

    const gdk_display: ?*gdkwayland.WaylandDisplay = @ptrCast(gdk.Display.getDefault());
    if (gdk_display == null) {
        log.err("Cannot get default gdk_display", .{});
        return;
    }
    const wl_display: ?*wl.Display = @ptrCast(gdkwayland.WaylandDisplay.getWlDisplay(gdk_display.?));
    if (wl_display == null) {
        log.err("Cannot get wl_display from gdk_display", .{});
        return;
    }
    const wl_registry = wl_display.?.getRegistry() catch {
        log.err("Cannot get wl_registry from wl_display", .{});
        return;
    };
    wl_registry.setListener(*State, registryListener, state);

    ctx.moduleData()[selfId] = state;
}

fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, state: *State) void {
    switch (event) {
        .global => |global| {
            if (std.mem.orderZ(u8, global.interface, wl.Seat.getInterface().name) != .eq) {
                return;
            }
            const seat = registry.bind(global.name, wl.Seat, 4) catch |err| {
                log.err("Cannot retreive wl_seat from wl_registry: {}", .{err});
                return;
            };
            seat.setListener(*State, seatListener, state);
        },
        .global_remove => {},
    }
}

fn seatListener(seat: *wl.Seat, event: wl.Seat.Event, state: *State) void {
    switch (event) {
        .capabilities => |data| {
            if (data.capabilities.keyboard) {
                const wl_keyboard = seat.getKeyboard() catch {
                    log.err("Cannot get wl_keyboard from wl_seat", .{});
                    return;
                };
                wl_keyboard.setListener(*State, keyboardListener, state);
            }
        },
        .name => {},
    }
}

fn keyboardListener(_: *wl.Keyboard, event: wl.Keyboard.Event, state: *State) void {
    switch (event) {
        .keymap => |keymap| {
            if (keymap.format != .xkb_v1) {
                log.err("Wrong format: {}", .{keymap.format});
                return;
            }
            const ptr = std.posix.mmap(null, keymap.size, std.posix.PROT.READ, .{ .TYPE = .PRIVATE }, keymap.fd, 0) catch |err| {
                log.err("Cannot mmap: {}", .{err});
                return;
            };
            defer std.posix.munmap(ptr);
            defer std.posix.close(keymap.fd);

            const xkb_context = xkb.xkb_context_new(xkb.XKB_CONTEXT_NO_FLAGS);
            if (xkb_context == null) {
                log.err("xkb_context is null", .{});
                return;
            }
            const xkb_keymap = xkb.xkb_keymap_new_from_string(xkb_context, @ptrCast(ptr), xkb.XKB_KEYMAP_FORMAT_TEXT_V1, xkb.XKB_KEYMAP_COMPILE_NO_FLAGS);
            if (xkb_keymap == null) {
                log.err("xkb_keymap is null", .{});
                return;
            }
            const rxkb_context = xkb.rxkb_context_new(xkb.RXKB_CONTEXT_NO_FLAGS);
            if (rxkb_context == null) {
                log.err("rxkb_context is null", .{});
                return;
            }
            if (!xkb.rxkb_context_parse_default_ruleset(rxkb_context)) {
                log.err("Cannot parse rxkb default ruleset", .{});
                return;
            }
            const layouts_num = xkb.xkb_keymap_num_layouts(xkb_keymap);
            var i: u32 = 0;
            var l: ?*xkb.rxkb_layout = null;
            while (i < layouts_num) : (i += 1) {
                l = xkb.rxkb_layout_first(rxkb_context);
                while (l != null) {
                    if (std.mem.orderZ(u8, xkb.rxkb_layout_get_description(l), xkb.xkb_keymap_layout_get_name(xkb_keymap, i)) == .eq) {
                        const layout_name = util.convertCString(xkb.rxkb_layout_get_name(l));
                        const layout_name_copy = state.allocator.dupeZ(u8, layout_name) catch |err| {
                            log.err("Cannot duplicate layout_name: {}", .{err});
                            return;
                        };
                        state.labels.append(layout_name_copy) catch |err| {
                            log.err("Cannot append layout_name to `state.labels`: {}", .{err});
                            return;
                        };
                    }
                    l = xkb.rxkb_layout_next(l);
                }
            }
            defer xkb.xkb_keymap_unref(xkb_keymap);
            defer xkb.xkb_context_unref(xkb_context);
            defer _ = xkb.rxkb_layout_unref(l);
            defer _ = xkb.rxkb_context_unref(rxkb_context);
        },
        .modifiers => |mods| {
            var label = state.formats.get(state.labels.items[mods.group]);
            if (label == null) {
                label = state.labels.items[mods.group];
            }
            state.gtk_label.setText(@ptrCast(label));
        },
        .key => {},
        .enter => {},
        .leave => {},
        .repeat_info => {},
    }
}
