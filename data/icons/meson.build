icondir = join_paths(get_option('datadir'), 'icons', 'hicolor')
icon_sizes = ['16x16', '22x22', '24x24', '32x32', '48x48', '256x256', '512x512']

foreach size : icon_sizes
  install_data(
    join_paths('hicolor', size, 'apps', 'de.haeckerfelix.gradio.png'),
    install_dir: join_paths(icondir, size, 'apps')
  )
  install_data(
    join_paths('hicolor', size, 'apps', 'gradio.png'),
    install_dir: join_paths(icondir, size, 'apps')
  )
endforeach

scalable_dir = join_paths('hicolor', 'scalable', 'apps')
install_data(
  join_paths(scalable_dir, 'de.haeckerfelix.gradio.svg'),
  install_dir: join_paths(get_option('datadir'), 'icons', scalable_dir)
)
install_data(
  join_paths(scalable_dir, 'de.haeckerfelix.gradio-symbolic.svg'),
  install_dir: join_paths(get_option('datadir'), 'icons', scalable_dir)
)
