// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public class PlayerBar : Gtk.Box {
        private Elmish.Dispatch<Message> dispatch;
        private Gtk.Button play_button;
        private Gtk.Label station_label;
        private Gtk.Label metadata_label;
        private Gtk.Label status_label;
        private Gtk.VolumeButton volume_button;
        private bool updating = false;

        public PlayerBar (Elmish.Dispatch<Message> dispatch) {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 12);
            this.dispatch = dispatch;
            margin_top = 8;
            margin_bottom = 8;
            margin_start = 12;
            margin_end = 12;

            play_button = new Gtk.Button () {
                icon_name = "media-playback-start-symbolic",
                tooltip_text = _("Play"),
                sensitive = false
            };
            play_button.clicked.connect (() => dispatch (new TogglePlayMessage ()));
            append (play_button);

            var text = new Gtk.Box (Gtk.Orientation.VERTICAL, 2) {
                hexpand = true,
                valign = Gtk.Align.CENTER
            };
            station_label = new Gtk.Label ("") {
                halign = Gtk.Align.START,
                ellipsize = Pango.EllipsizeMode.END
            };
            station_label.add_css_class ("heading");
            metadata_label = new Gtk.Label ("") {
                halign = Gtk.Align.START,
                ellipsize = Pango.EllipsizeMode.END
            };
            metadata_label.add_css_class ("dim-label");
            text.append (station_label);
            text.append (metadata_label);
            append (text);

            status_label = new Gtk.Label ("") {
                halign = Gtk.Align.END,
                valign = Gtk.Align.CENTER,
                ellipsize = Pango.EllipsizeMode.END
            };
            status_label.add_css_class ("dim-label");
            append (status_label);

            volume_button = new Gtk.VolumeButton ();
            volume_button.set_adjustment (new Gtk.Adjustment (0.8, 0.0, 1.0, 0.01, 0.05, 0.0));
            volume_button.value_changed.connect ((value) => {
                if (!updating)
                    dispatch (new SetVolumeMessage (value));
            });
            append (volume_button);
        }

        public void update (AppModel model) {
            updating = true;

            bool has_station = model.current_station != null;
            play_button.sensitive = has_station;
            play_button.icon_name = model.playing
                ? "media-playback-stop-symbolic"
                : "media-playback-start-symbolic";
            play_button.tooltip_text = model.playing ? _("Stop") : _("Play");

            var station = model.current_station;
            if (station != null) {
                station_label.label = station.name;
                metadata_label.label = model.stream_title != ""
                    ? model.stream_title
                    : station.secondary_text (model.config.show_technical_info);
            } else {
                station_label.label = "";
                metadata_label.label = "";
            }

            status_label.label = model.status_message;
            if (volume_button.value != model.config.volume)
                volume_button.value = model.config.volume;

            updating = false;
        }
    }
}
