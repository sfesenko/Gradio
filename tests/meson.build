test_deps = [
  dependency('gio-2.0', version: '>= 2.76'),
]

test_update = executable('test_update',
  'test_update.vala',
  dependencies: [test_deps, lib_core_dep],
)
test('test update model', test_update)

test_elmish = executable('test_elmish',
  'test_elmish.vala',
  dependencies: [test_deps, lib_core_dep],
)
test('test elmish core', test_elmish)
