project('gradio', ['c', 'vala'],
          version: '8.0.0',
    meson_version: '>= 0.59.0',
  default_options: [ 'warning_level=2',
                     'werror=false',
                   ],
)

i18n = import('i18n')

gnome = import('gnome')

add_global_arguments([
        '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    ],
    language: 'c'
)


subdir('data')
subdir('po')

gnome.post_install(
  gtk_update_icon_cache: true,
  update_desktop_database: true,
  glib_compile_schemas: true,
)


# Shared library for pure logic (testable without GTK).
# Everything in here must stay GTK-free: no widgets, no Gtk imports.
lib_core_sources = [
  'src/elmish.vala',
  'src/model/messages.vala',
  'src/commands.vala',
  'src/app-runtime.vala',
  'src/model/radio-station.vala',
  'src/model/app-config.vala',
  'src/model/station-sort.vala',
  'src/model/search-filters.vala',
  'src/model/station-validation.vala',
  'src/model/station-transfer.vala',
  'src/backend/http.vala',
  'src/backend/radio-browser.vala',
  'src/backend/player.vala',
  'src/backend/favicon.vala',
  'src/backend/mpris.vala',
  'src/backend/search-provider.vala',
  'src/app-update.vala',
]

lib_core_deps = [
  dependency('gio-2.0', version: '>= 2.76'),
  dependency('json-glib-1.0'),
  dependency('libsoup-3.0'),
  dependency('gstreamer-1.0'),
  dependency('gstreamer-pbutils-1.0'),
  dependency('gdk-pixbuf-2.0'),
]

lib_core = static_library('gradio-core',
  lib_core_sources,
  dependencies: lib_core_deps,
)

lib_core_dep = declare_dependency(
  link_with: lib_core,
  include_directories: include_directories('.'),
  dependencies: lib_core_deps,
)


config_data = configuration_data()
config_data.set_quoted('LOCALEDIR', join_paths(get_option('prefix'), get_option('localedir')))
config_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
config_file = configure_file(
    input: 'src/Config.vala.in',
    output: '@BASENAME@',
    configuration: config_data
)

executable(
  meson.project_name(),
  [
    'src/main.vala',
    'src/app-view.vala',
    'src/view/station-row.vala',
    'src/view/station-editor-dialog.vala',
    'src/view/details-panel.vala',
    'src/view/player-bar.vala',
    'src/view/settings-dialog.vala',
    config_file,
  ],
  vala_args: [ '--target-glib=2.76' ],
  dependencies: [
    dependency('gtk4', version: '>= 4.10'),
    lib_core_dep,
  ],
  install: true,
)

subdir('tests')
