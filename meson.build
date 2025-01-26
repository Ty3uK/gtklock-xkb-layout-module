project(
  'gtklock-xkb-layout-module', 'c',
  version : '1.0.0',
  license : 'GPLv3',
  default_options : ['c_std=c11'],
)

gtk = dependency('gtk+-3.0')
wayland = dependency('wayland-client')
xkbcommon = dependency('xkbcommon')
xkbregistry = dependency('xkbregistry')

shared_library(
  'xkb-layout-module',
  'module.c',
  'wayland.c',
  name_prefix : '',
  dependencies : [
    gtk,
    wayland,
    xkbcommon,
    xkbregistry,
  ],
)
