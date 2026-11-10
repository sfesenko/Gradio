// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public class StationRow : Gtk.ListBoxRow {
        public RadioStation station { get; private set; }
        public bool library_row { get; private set; }

        private Elmish.Dispatch<Message> dispatch;
        private bool is_current;
        private bool playing;
        private bool already_added;
        private bool show_technical_info;
        private Gtk.Label secondary_label;
        private Gtk.Button? add_button = null;
        private Gtk.Button? play_button = null;

        public StationRow (RadioStation station, bool library_row, bool show_technical_info,
                bool is_current, bool playing, bool already_added, Elmish.Dispatch<Message> dispatch) {
            this.station = station;
            this.library_row = library_row;
            this.dispatch = dispatch;
            this.is_current = is_current;
            this.playing = playing;
            this.already_added = already_added;
            this.show_technical_info = show_technical_info;

            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
                margin_top = 8,
                margin_bottom = 8,
                margin_start = 12,
                margin_end = 12
            };

            var icon = new Gtk.Image.from_icon_name ("application-rss+xml-symbolic") {
                pixel_size = 48
            };
            row.append (icon);

            var text = new Gtk.Box (Gtk.Orientation.VERTICAL, 2) {
                hexpand = true,
                valign = Gtk.Align.CENTER
            };
            var title = new Gtk.Label (station.name) {
                halign = Gtk.Align.START,
                ellipsize = Pango.EllipsizeMode.END
            };
            title.add_css_class ("heading");
            secondary_label = new Gtk.Label (station.secondary_text (show_technical_info)) {
                halign = Gtk.Align.START,
                ellipsize = Pango.EllipsizeMode.END
            };
            secondary_label.add_css_class ("dim-label");
            text.append (title);
            text.append (secondary_label);
            row.append (text);

            if (library_row) {
                row.append (build_actions ());
            } else {
                add_button = new Gtk.Button.with_label (already_added ? _("Added") : _("Add")) {
                    valign = Gtk.Align.CENTER
                };
                add_button.sensitive = !already_added;
                add_button.clicked.connect (() => {
                    if (!already_added)
                        dispatch (new AddStationMessage (station));
                });
                row.append (add_button);
            }

            set_child (row);

            activate.connect (() => {
                if (library_row) {
                    if (is_current && playing)
                        dispatch (new TogglePlayMessage ());
                    else
                        dispatch (new PlayStationMessage (station));
                } else if (!already_added) {
                    dispatch (new AddStationMessage (station));
                }
            });
        }

        public void set_state (bool is_current, bool playing, bool already_added, string stream_title = "") {
            this.is_current = is_current;
            this.playing = playing;
            if (is_current && playing && stream_title != "")
                secondary_label.label = stream_title;
            else
                secondary_label.label = station.secondary_text (show_technical_info);
            if (is_current)
                add_css_class ("current-station");
            else
                remove_css_class ("current-station");
            if (play_button != null) {
                bool current_playing = is_current && playing;
                play_button.icon_name = current_playing
                    ? "media-playback-stop-symbolic" : "media-playback-start-symbolic";
                play_button.tooltip_text = current_playing ? _("Stop") : _("Play");
            }
            if (this.already_added != already_added && add_button != null) {
                add_button.label = already_added ? _("Added") : _("Add");
                add_button.sensitive = !already_added;
            }
            this.already_added = already_added;
        }

        private Gtk.Box build_actions () {
            var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                valign = Gtk.Align.CENTER
            };

            play_button = new Gtk.Button () {
                icon_name = "media-playback-start-symbolic",
                tooltip_text = _("Play")
            };
            play_button.clicked.connect (() => {
                if (is_current && playing)
                    dispatch (new TogglePlayMessage ());
                else
                    dispatch (new PlayStationMessage (station));
            });
            actions.append (play_button);

            var details = new Gtk.Button () {
                icon_name = "dialog-information-symbolic",
                tooltip_text = _("Details")
            };
            details.clicked.connect (() => dispatch (new ShowDetailsMessage (station)));
            actions.append (details);

            var remove = new Gtk.Button () {
                icon_name = "user-trash-symbolic",
                tooltip_text = _("Remove from library")
            };
            remove.clicked.connect (() => dispatch (new RemoveStationMessage (station.id)));
            actions.append (remove);

            return actions;
        }
    }
}
