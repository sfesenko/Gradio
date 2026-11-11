// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public class SettingsDialog : Gtk.Window {
        public SettingsDialog (Gtk.Window parent, AppModel model, Elmish.Dispatch<Message> dispatch) {
            Object (transient_for: parent, modal: true, title: _("Preferences"), default_width: 360);

            var header = new Gtk.HeaderBar ();
            var close = new Gtk.Button.with_label (_("Close"));
            close.clicked.connect (() => this.close ());
            header.pack_end (close);
            set_titlebar (header);

            var list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE,
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12
            };

            var technical_toggle = new Gtk.Switch () {
                active = model.config.show_technical_info,
                valign = Gtk.Align.CENTER
            };
            technical_toggle.state_set.connect ((state) => {
                dispatch (new SetShowTechnicalInfoMessage (state));
                return false;
            });
            list.append (build_row (_("Show technical information"), technical_toggle));

            var resume_toggle = new Gtk.Switch () {
                active = model.config.resume_playback,
                valign = Gtk.Align.CENTER
            };
            resume_toggle.state_set.connect ((state) => {
                dispatch (new SetResumePlaybackMessage (state));
                return false;
            });
            list.append (build_row (_("Resume playback on startup"), resume_toggle));

            var background_toggle = new Gtk.Switch () {
                active = model.config.background_playback,
                valign = Gtk.Align.CENTER
            };
            background_toggle.state_set.connect ((state) => {
                dispatch (new SetBackgroundPlaybackMessage (state));
                return false;
            });
            list.append (build_row (_("Keep playing when the window is closed"), background_toggle));

            var notifications_toggle = new Gtk.Switch () {
                active = model.config.notifications_enabled,
                valign = Gtk.Align.CENTER
            };
            notifications_toggle.state_set.connect ((state) => {
                dispatch (new SetNotificationsMessage (state));
                return false;
            });
            list.append (build_row (_("Show notifications"), notifications_toggle));

            int[] icon_sizes = { 32, 48, 64, 96 };
            var icon_size = new Gtk.DropDown.from_strings ({ "32", "48", "64", "96" });
            uint selected = 0;
            for (int i = 0; i < icon_sizes.length; i++) {
                if (icon_sizes[i] == model.config.icon_size)
                    selected = (uint) i;
            }
            icon_size.selected = selected;
            icon_size.notify["selected"].connect (() => {
                uint index = icon_size.selected;
                if (index < icon_sizes.length)
                    dispatch (new SetIconSizeMessage (icon_sizes[index]));
            });
            list.append (build_row (_("Station icon size"), icon_size));

            var clear_favicons = new Gtk.Button.with_label (_("Clear")) {
                valign = Gtk.Align.CENTER
            };
            clear_favicons.clicked.connect (() => dispatch (new ClearFaviconCacheMessage ()));
            list.append (build_row (_("Favicon cache"), clear_favicons));

            set_child (list);
        }

        private Gtk.ListBoxRow build_row (string label, Gtk.Widget control) {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
                margin_top = 8,
                margin_bottom = 8
            };
            var text = new Gtk.Label (label) {
                halign = Gtk.Align.START,
                hexpand = true
            };
            box.append (text);
            box.append (control);

            var row = new Gtk.ListBoxRow ();
            row.set_child (box);
            return row;
        }
    }
}
