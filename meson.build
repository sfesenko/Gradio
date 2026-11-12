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
)


# Shared library for pure logic (testable without GTK).
# Everything in here must stay GTK-free: no widgets, no Gtk imports.
# --- Cast support (Google Cast v2) ---
protoc = find_program('protoc', required: true)
cast_proto_c = custom_target('cast-proto',
  input: 'src/cast/cast.proto',
  output: ['cast.pb-c.c', 'cast.pb-c.h'],
  command: [find_program('scripts/gen-cast-proto.sh'),
            meson.current_build_dir(), meson.current_source_dir(), '@INPUT@'],
  build_by_default: true)

lib_core_c_args = ['-DHAVE_CAST=1']
lib_core_link_args = ['-lprotobuf-c']

lib_core_sources = [
  'src/elmish.vala',
  'src/model/messages.vala',
  'src/commands.vala',
  'src/app-runtime.vala',
  'src/model/radio-station.vala',
  'src/model/app-config.vala',
  'src/model/playback-lifecycle.vala',
  'src/model/station-sort.vala',
  'src/model/search-filters.vala',
  'src/model/station-validation.vala',
  'src/model/station-transfer.vala',
  'src/model/locale.vala',
  'src/backend/http.vala',
  'src/backend/file-io.vala',
  'src/backend/config-store.vala',
  'src/backend/task.vala',
  'src/backend/radio-browser.vala',
  'src/backend/player.vala',
  'src/backend/favicon.vala',
  'src/backend/mpris.vala',
  'src/backend/sleep-inhibitor.vala',
  'src/backend/search-provider.vala',
  'src/app-update.vala',
  'src/cast/cast-service.vala',
  'src/cast/mdns.vala',
  'src/cast/cast-connection.vala',
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
  'src/cast/cast-proto.c',
  cast_proto_c,
  c_args: lib_core_c_args,
  include_directories: include_directories('.'),
  link_args: lib_core_link_args,
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
config_data.set_quoted('VERSION', meson.project_version())
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
    dependency('gtk4', version: '>= 4.12'),
    lib_core_dep,
  ],
  install: true,
)

subdir('tests')
