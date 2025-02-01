const std = @import("std");
const gtk = @import("gtk");
const wl = @import("wayland").client.wl;
const util = @import("./util.zig");

pub const State = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    gtk_label: *gtk.Label,

    labels: std.ArrayList([]const u8),
    formats: std.StringHashMap([]const u8),

    wl_registry: ?*wl.Registry,
    wl_seat: ?*wl.Seat,
    wl_keyboard: ?*wl.Keyboard,

    pub fn init(allocator: std.mem.Allocator) !*State {
        const result = try allocator.create(State);
        result.* = State{
            .allocator = allocator,
            .gtk_label = gtk.Label.new(""),
            .labels = try std.ArrayList([]const u8).initCapacity(std.heap.page_allocator, 2),
            .formats = std.StringHashMap([]const u8).init(std.heap.page_allocator),
            .wl_registry = null,
            .wl_seat = null,
            .wl_keyboard = null,
        };
        return result;
    }

    pub fn deinit(self: *Self) void {
        self.labels.deinit();
        self.formats.deinit();
        if (self.wl_keyboard) |wl_keyboard| {
            wl_keyboard.destroy();
        }
        if (self.wl_seat) |wl_seat| {
            wl_seat.destroy();
        }
        if (self.wl_registry) |wl_registry| {
            wl_registry.destroy();
        }
        self.allocator.destroy(self);
    }

    pub fn parseFormats(self: *Self, formats: [*c][*c]const u8) !void {
        if (formats != null) {
            var i: usize = 0;
            while (formats[i] != null) : (i += 1) {
                const str = util.convertCString(formats[i]);
                var iter = std.mem.splitScalar(u8, str, '=');
                if (iter.next()) |key| {
                    if (iter.next()) |value| {
                        self.formats.put(key, value) catch continue;
                    }
                }
            }
        }
    }
};
