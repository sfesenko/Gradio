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
  'src/app-update.vala',
]

lib_core = static_library('gradio-core',
  lib_core_sources,
  dependencies: [ dependency('gio-2.0', version: '>= 2.76') ],
)

lib_core_dep = declare_dependency(
  link_with: lib_core,
  include_directories: include_directories('.'),
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
