// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    // The header cast button and its popover: device list, volume and
    // transport controls.
    public class CastButton : Gtk.Box {
        private unowned Elmish.Dispatch<Message> dispatch;
        private Gtk.MenuButton button;
        private Gtk.Scale volume_scale;
        private Gtk.Box volume_row;
        private Gtk.Image volume_icon;
        private Gtk.Label volume_value;
        private bool updating_volume = false;
        private Gtk.ListBox device_list;
        private Gtk.Button discover_button;
        private Gtk.Label status_label;
        private Gtk.Button launch_button;
        private Gtk.Button stop_button;
        private Gtk.Button local_button;
        private string device_signature = "";
        private uint device_count = 0;
        private CastStatus cast_status = CastStatus.IDLE;

        public CastButton (Elmish.Dispatch<Message> dispatch) {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);
            this.dispatch = dispatch;
            button = new Gtk.MenuButton () {
                icon_name = "audio-volume-high-symbolic",
                tooltip_text = _("Cast to a device")
            };

            // The button opens the cast popover, which is also where the
            // volume lives: a speaker icon says both, and it tracks the level.
            var cast_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                margin_top = 8,
                margin_bottom = 8,
                margin_start = 8,
                margin_end = 8
            };
            volume_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8) {
                tooltip_text = _("Local volume")
            };
            volume_icon = new Gtk.Image.from_icon_name ("audio-volume-high-symbolic");
            volume_row.append (volume_icon);
            volume_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL,
                0.0, 1.0, 0.01);
            volume_scale.set_draw_value (false);
            volume_scale.set_hexpand (true);
            volume_scale.value_changed.connect (() => {
                if (!updating_volume)
                    dispatch (new SetVolumeMessage (volume_scale.get_value ()));
            });
            volume_row.append (volume_scale);
            // A fixed-width value keeps the slider from resizing while dragging.
            volume_value = new Gtk.Label ("") {
                xalign = 1.0f,
                width_chars = 4
            };
            volume_value.add_css_class ("dim-label");
            volume_row.append (volume_value);
            cast_box.append (volume_row);
            cast_box.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
            discover_button = new Gtk.Button.with_label (_("Discover devices"));
            discover_button.clicked.connect (() => dispatch (
                new DiscoverCastDevicesMessage ()));
            cast_box.append (discover_button);
            device_list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.SINGLE
            };
            device_list.row_selected.connect ((row) => {
                if (row == null)
                    return;
                var device = (Gradio.CastDevice) row.get_data<Gradio.CastDevice> ("device");
                if (device != null)
                    dispatch (new SelectCastDeviceMessage (device.id, device.name,
                        device.host, device.port));
            });
            cast_box.append (new Gtk.ScrolledWindow () {
                child = device_list,
                min_content_height = 120,
                hexpand = true
            });
            status_label = new Gtk.Label ("") { xalign = 0, wrap = true };
            cast_box.append (status_label);
            launch_button = new Gtk.Button.with_label (_("Cast current stream"));
            launch_button.clicked.connect (() => dispatch (new CastToSelectedMessage ()));
            stop_button = new Gtk.Button.with_label (_("Stop casting"));
            stop_button.clicked.connect (() => dispatch (new StopCastMessage ()));
            local_button = new Gtk.Button.with_label (_("Play on this computer"));
            local_button.clicked.connect (() => dispatch (new PlayLocalMessage ()));
            cast_box.append (launch_button);
            cast_box.append (stop_button);
            cast_box.append (local_button);

            var popover = new Gtk.Popover () { child = cast_box };
            popover.notify["visible"].connect (() => {
                if (!popover.visible)
                    return;
                if (device_count == 0 && cast_status != CastStatus.DISCOVERING)
                    dispatch (new DiscoverCastDevicesMessage ());
            });
            button.set_popover (popover);
            append (button);
        }

        public void update (AppModel model) {
            device_count = model.cast_devices.length;
            cast_status = model.cast_status;
            var selected_id = model.cast_device_id;
            // Rebuild rows only when the device list changed.
            var signature = "%u:%s".printf (device_count, selected_id ?? "");
            if (signature != device_signature) {
                device_signature = signature;
                while (device_list.get_first_child () != null)
                    device_list.remove (device_list.get_first_child ());
                foreach (var device in model.cast_devices) {
                    var row = new Gtk.ListBoxRow () { selectable = true };
                    row.set_data ("device", device);
                    row.child = new Gtk.Label (device.name) {
                        xalign = 0,
                        margin_top = 4,
                        margin_bottom = 4,
                        margin_start = 6
                    };
                    device_list.append (row);
                }
            }
            switch (model.cast_status) {
                case CastStatus.IDLE:
                    status_label.label = _("Not casting");
                    break;
                case CastStatus.DISCOVERING:
                    status_label.label = _("Discovering…");
                    break;
                case CastStatus.READY:
                    status_label.label = model.cast_device_name != null
                        ? _("Ready to cast to %s").printf (model.cast_device_name)
                        : _("Ready to cast");
                    break;
                case CastStatus.CONNECTING:
                    status_label.label = _("Connecting…");
                    break;
                case CastStatus.PLAYING:
                    status_label.label = model.cast_device_name != null
                        ? _("Casting to %s").printf (model.cast_device_name)
                        : _("Casting");
                    break;
                case CastStatus.BUFFERING:
                    status_label.label = _("Buffering…");
                    break;
                case CastStatus.PAUSED:
                    status_label.label = _("Paused on cast device");
                    break;
                case CastStatus.STOPPED:
                    status_label.label = _("Stopped");
                    break;
                case CastStatus.FAILED:
                    status_label.label = model.cast_error;
                    break;
                case CastStatus.LOST:
                    status_label.label = model.cast_error != ""
                        ? model.cast_error : _("Cast connection lost");
                    break;
            }
            if (model.cast_reconnecting)
                status_label.label = _("Reconnecting…");
            if (model.cast_remote_label != "" && !model.cast_is_active () &&
                    !model.cast_reconnecting)
                status_label.label = model.cast_remote_label;
            string cast_tooltip = _("Cast to a device");
            if (model.cast_reconnecting)
                cast_tooltip = _("Reconnecting…");
            else if (model.cast_status == CastStatus.PLAYING && model.cast_device_name != null)
                cast_tooltip = _("Casting to %s").printf (model.cast_device_name);
            else if (model.cast_status == CastStatus.BUFFERING && model.cast_device_name != null)
                cast_tooltip = _("Buffering on %s").printf (model.cast_device_name);
            else if (model.cast_status == CastStatus.PAUSED && model.cast_device_name != null)
                cast_tooltip = _("Paused on %s").printf (model.cast_device_name);
            else if (model.cast_status == CastStatus.LOST)
                cast_tooltip = _("Cast connection lost");
            button.tooltip_text = cast_tooltip;
            if (model.cast_is_active ())
                button.add_css_class ("cast-active");
            else
                button.remove_css_class ("cast-active");
            bool can_change_device = !(model.cast_is_active () || model.cast_attached);
            discover_button.sensitive = can_change_device;
            device_list.sensitive = can_change_device;
            discover_button.tooltip_text = can_change_device
                ? _("Discover cast devices")
                : model.cast_reconnecting
                    ? _("Reconnecting…")
                    : _("Stop casting to change device");
            button.icon_name = volume_icon_name (model.config.volume);
            volume_icon.icon_name = volume_icon_name (model.config.volume);
            volume_value.label = volume_percent_text (model.config.volume);
            bool casting = model.playback_target == PlaybackTarget.CAST &&
                model.cast_attached && !model.cast_reconnecting;
            updating_volume = true;
            if (volume_scale.get_value () != model.config.volume)
                volume_scale.set_value (model.config.volume);
            updating_volume = false;
            volume_row.tooltip_text = casting
                ? _("Volume (local and cast)") : _("Local volume");
            // Starting a new cast must stay possible after a loss even though
            // the output is still CAST: only a live session disables it.
            launch_button.sensitive = !model.cast_is_active () &&
                model.cast_device_id != null && model.current_stream_url != "";
            stop_button.sensitive = model.playback_target == PlaybackTarget.CAST &&
                !model.cast_reconnecting;
            local_button.sensitive = model.playback_target == PlaybackTarget.CAST &&
                !model.cast_reconnecting;
        }

        private static string volume_icon_name (double volume) {
            if (volume <= 0.0)
                return "audio-volume-muted-symbolic";
            if (volume < 0.33)
                return "audio-volume-low-symbolic";
            if (volume < 0.66)
                return "audio-volume-medium-symbolic";
            return "audio-volume-high-symbolic";
        }

        private static string volume_percent_text (double volume) {
            // No libm dependency. The config clamps the level, so this only
            // guards a hand-set value from printing "140%".
            double clamped = volume.clamp (0.0, 1.0);
            return "%d%%".printf ((int) (clamped * 100 + 0.5));
        }
    }
}
