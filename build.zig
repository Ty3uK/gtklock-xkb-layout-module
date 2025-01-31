const std = @import("std");
const Scanner = @import("zig-wayland").Scanner;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "xkb-layout-module",
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const gobject = b.dependency("gobject", .{});
    lib.root_module.addImport("glib", gobject.module("glib2"));
    lib.root_module.addImport("gtk", gobject.module("gtk3"));
    lib.root_module.addImport("gdk", gobject.module("gdk3"));
    lib.root_module.addImport("gdkwayland", gobject.module("gdkwayland4"));
    lib.root_module.addImport("pango", gobject.module("pango1"));

    const scanner = Scanner.create(b, .{});
    scanner.generate("wl_seat", 4);
    scanner.generate("wl_compositor", 4);
    const wayland = b.createModule(.{ .root_source_file = scanner.result });
    lib.root_module.addImport("wayland", wayland);

    lib.linkSystemLibrary("glib-2.0");
    lib.linkSystemLibrary("gtk+-3.0");
    lib.linkSystemLibrary("wayland-client");
    lib.linkSystemLibrary("xkbcommon");
    lib.linkSystemLibrary("xkbregistry");

    b.getInstallStep().dependOn(&b.addInstallFileWithDir(lib.getEmittedBin(), .lib, "xkb-layout-module.so").step);
}
