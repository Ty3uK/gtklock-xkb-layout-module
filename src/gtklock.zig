const gtk = @import("gtk");
const gdk = @import("gdk");

pub fn Window(comptime T: type) type {
    return extern struct {
        monitor: *gdk.Monitor,

        window: *gtk.Widget,
        overlay: *gtk.Widget,
        window_box: *gtk.Widget,
        body_revealer: *gtk.Widget,
        body_grid: *gtk.Widget,
        input_label: *gtk.Widget,
        input_field: *gtk.Widget,
        message_revealer: *gtk.Widget,
        message_scrolled_window: *gtk.Widget,
        message_box: *gtk.Widget,
        unlock_button: *gtk.Widget,
        error_label: *gtk.Widget,
        warning_label: *gtk.Widget,
        info_box: *gtk.Widget,
        time_box: *gtk.Widget,
        clock_label: *gtk.Widget,
        date_label: *gtk.Widget,

        pub fn moduleData(self: anytype) [*]?*T {
            return @ptrCast(@alignCast(@as([*]?*T, @ptrCast(self)) + @sizeOf(@This())));
        }
    };
}
