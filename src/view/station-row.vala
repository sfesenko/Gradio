// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public class StationRow : Gtk.ListBoxRow {
        public RadioStation station { get; private set; }
        public bool library_row { get; private set; }
        public Gtk.Widget? drag_handle { get; private set; }

        private unowned Elmish.Dispatch<Message> dispatch;
        private bool is_current;
        private bool playing;
        private bool already_added;
        private bool show_technical_info;
        private Gtk.Label secondary_label;
        private Gtk.Image station_icon;
        private string favicon_path = "";
        private int icon_size;
        private Gtk.Button? add_button = null;
        private Gtk.Button? play_button = null;

        public StationRow (RadioStation station, bool library_row, bool show_technical_info,
                bool is_current, bool playing, bool already_added, string? favicon_path,
                int icon_size, Elmish.Dispatch<Message> dispatch) {
            this.station = station;
            this.library_row = library_row;
            this.dispatch = dispatch;
            this.is_current = is_current;
            this.playing = playing;
            this.already_added = already_added;
            this.show_technical_info = show_technical_info;
            this.icon_size = icon_size;

            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
                margin_top = 8,
                margin_bottom = 8,
                margin_start = 12,
                margin_end = 12
            };

            var icon = new Gtk.Image.from_icon_name ("application-rss+xml-symbolic") {
                pixel_size = icon_size
            };
            if (library_row) {
                var handle = new Gtk.Image.from_icon_name ("list-drag-handle-symbolic") {
                    pixel_size = 16,
                    valign = Gtk.Align.CENTER,
                    tooltip_text = _("Drag to reorder")
                };
                handle.add_css_class ("dim-label");
                row.append (handle);
                drag_handle = handle;
            }
            row.append (icon);
            station_icon = icon;
            set_favicon (favicon_path);

            var text = new Gtk.Box (Gtk.Orientation.VERTICAL, 2) {
                hexpand = true,
                valign = Gtk.Align.CENTER
            };
            var title = new Gtk.Label (station.name) {
                halign = Gtk.Align.START,
                ellipsize = Pango.EllipsizeMode.END
            };
            title.add_css_class ("heading");
            secondary_label = new Gtk.Label (display_secondary ()) {
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

        private string display_secondary () {
            string secondary = station.secondary_text (show_technical_info);
            if (station.orphaned)
                secondary = secondary == "" ? _("Unavailable") : secondary + " • " + _("Unavailable");
            return secondary;
        }

        public void set_favicon (string? path) {
            string next = path ?? "";
            if (next == favicon_path)
                return;
            favicon_path = next;

            if (next == "") {
                station_icon.set_from_icon_name ("application-rss+xml-symbolic");
                station_icon.pixel_size = icon_size;
                return;
            }

            try {
                // Favicons are cached at <= FaviconCache.MAX_SIZE, so load the
                // texture as-is and let Gtk.Image scale it to pixel_size.
                station_icon.set_from_paintable (Gdk.Texture.from_filename (next));
                station_icon.pixel_size = icon_size;
            } catch (GLib.Error e) {
                station_icon.set_from_icon_name ("application-rss+xml-symbolic");
                station_icon.pixel_size = icon_size;
            }
        }

        public void set_state (bool is_current, bool playing, bool already_added, string stream_title = "") {
            this.is_current = is_current;
            this.playing = playing;
            if (is_current && playing && stream_title != "")
                secondary_label.label = stream_title;
            else
                secondary_label.label = display_secondary ();
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

        public void set_drag_enabled (bool enabled) {
            if (drag_handle != null)
                drag_handle.visible = enabled;
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
            remove.clicked.connect (() => on_remove_clicked ());
            actions.append (remove);

            return actions;
        }

        private void on_remove_clicked () {
            // Remote stations can be added again from search; locally created
            // ones exist only in the config and would be lost permanently.
            if (!station.is_local) {
                dispatch (new RemoveStationMessage (station.id));
                return;
            }

            var dialog = new Gtk.AlertDialog (_("Remove %s?").printf (station.name));
            dialog.detail = _("This locally created station cannot be restored.");
            dialog.buttons = { _("Cancel"), _("Remove") };
            dialog.cancel_button = 0;
            dialog.default_button = 0;
            dialog.modal = true;
            dialog.choose.begin (get_root () as Gtk.Window, null, (obj, res) => {
                try {
                    if (dialog.choose.end (res) == 1)
                        dispatch (new RemoveStationMessage (station.id));
                } catch (GLib.Error e) {
                }
            });
        }
    }
}
