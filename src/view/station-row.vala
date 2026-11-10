// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public class StationRow : Gtk.ListBoxRow {
        public RadioStation station { get; private set; }
        public bool library_row { get; private set; }

        private Elmish.Dispatch<Message> dispatch;
        private bool is_current;
        private bool playing;
        private bool already_added;

        public StationRow (RadioStation station, bool library_row, bool show_technical_info,
                bool is_current, bool playing, bool already_added, Elmish.Dispatch<Message> dispatch) {
            this.station = station;
            this.library_row = library_row;
            this.dispatch = dispatch;
            this.is_current = is_current;
            this.playing = playing;
            this.already_added = already_added;

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
            var secondary = new Gtk.Label (station.secondary_text (show_technical_info)) {
                halign = Gtk.Align.START,
                ellipsize = Pango.EllipsizeMode.END
            };
            secondary.add_css_class ("dim-label");
            text.append (title);
            text.append (secondary);
            row.append (text);

            if (library_row) {
                var menu = build_menu ();
                row.append (menu);
            } else {
                var add = new Gtk.Button.with_label (already_added ? _("Added") : _("Add")) {
                    valign = Gtk.Align.CENTER
                };
                add.sensitive = !already_added;
                add.clicked.connect (() => {
                    if (!already_added)
                        dispatch (new AddStationMessage (station));
                });
                row.append (add);
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

        private Gtk.MenuButton build_menu () {
            var popover_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4) {
                margin_top = 6,
                margin_bottom = 6,
                margin_start = 6,
                margin_end = 6
            };

            var play = new Gtk.Button.with_label (_("Play")) {
                halign = Gtk.Align.FILL
            };
            play.clicked.connect (() => dispatch (new PlayStationMessage (station)));
            popover_box.append (play);

            var details = new Gtk.Button.with_label (_("Details")) {
                halign = Gtk.Align.FILL
            };
            details.clicked.connect (() => dispatch (new ShowDetailsMessage (station)));
            popover_box.append (details);

            var remove = new Gtk.Button.with_label (_("Remove from library")) {
                halign = Gtk.Align.FILL
            };
            remove.clicked.connect (() => dispatch (new RemoveStationMessage (station.id)));
            popover_box.append (remove);

            var popover = new Gtk.Popover ();
            popover.set_child (popover_box);

            var menu = new Gtk.MenuButton () {
                icon_name = "view-more-symbolic",
                tooltip_text = _("Station menu"),
                valign = Gtk.Align.CENTER
            };
            menu.set_popover (popover);
            return menu;
        }
    }
}
