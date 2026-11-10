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

            set_child (list);
        }

        private Gtk.ListBoxRow build_row (string label, Gtk.Switch toggle) {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
                margin_top = 8,
                margin_bottom = 8
            };
            var text = new Gtk.Label (label) {
                halign = Gtk.Align.START,
                hexpand = true
            };
            box.append (text);
            box.append (toggle);

            var row = new Gtk.ListBoxRow ();
            row.set_child (box);
            return row;
        }
    }
}
