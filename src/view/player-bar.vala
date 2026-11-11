// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public class PlayerBar : Gtk.Box {
        private Elmish.Dispatch<Message> dispatch;
        private Gtk.Button play_button;
        private Gtk.Label station_label;
        private Gtk.Label metadata_label;
        private Gtk.Label status_label;
        private Gtk.VolumeButton volume_button;
        private Gtk.MenuButton history_button;
        private Gtk.Box history_box;
        private string history_signature = "";
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

            history_button = new Gtk.MenuButton () {
                icon_name = "document-open-recent-symbolic",
                tooltip_text = _("Track history"),
                visible = false
            };
            var history_popover = new Gtk.Popover ();
            history_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4) {
                margin_top = 8,
                margin_bottom = 8,
                margin_start = 8,
                margin_end = 8
            };
            history_popover.set_child (history_box);
            history_button.set_popover (history_popover);
            append (history_button);

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

            string signature = string.joinv ("\n", model.track_history);
            if (signature != history_signature) {
                history_signature = signature;
                Gtk.Widget? child = history_box.get_first_child ();
                while (child != null) {
                    var next = child.get_next_sibling ();
                    history_box.remove (child);
                    child = next;
                }
                foreach (string title in model.track_history) {
                    history_box.append (new Gtk.Label (title) {
                        halign = Gtk.Align.START,
                        ellipsize = Pango.EllipsizeMode.END,
                        max_width_chars = 40
                    });
                }
            }
            history_button.visible = model.track_history.length > 0;

            updating = false;
        }
    }
}
