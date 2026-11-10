test_deps = [
  dependency('gio-2.0', version: '>= 2.76'),
]

test_update = executable('test_update',
  'test_update.vala',
  dependencies: [test_deps, lib_core_dep],
)
test('update-model', test_update)

test_elmish = executable('test_elmish',
  'test_elmish.vala',
  dependencies: [test_deps, lib_core_dep],
)
test('test elmish core', test_elmish)

test_radio_station = executable('test_radio_station',
  'test_radio_station.vala',
  dependencies: [test_deps, lib_core_dep],
)
test('radio-station', test_radio_station)

test_app_config = executable('test_app_config',
  'test_app_config.vala',
  dependencies: [test_deps, lib_core_dep],
)
test('app-config', test_app_config)

test_http = executable('test_http',
  'test_http.vala',
  dependencies: [test_deps, lib_core_dep],
)
test('http', test_http)

test_radio_browser = executable('test_radio_browser',
  'test_radio_browser.vala',
  dependencies: [test_deps, lib_core_dep],
)
test('radio-browser', test_radio_browser)

test_player = executable('test_player',
  'test_player.vala',
  dependencies: [test_deps, lib_core_dep],
)
test('player', test_player)

test_app_runtime = executable('test_app_runtime',
  'test_app_runtime.vala',
  dependencies: [test_deps, lib_core_dep],
)
test('app-runtime', test_app_runtime)
