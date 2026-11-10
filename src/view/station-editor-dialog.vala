// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public class StationEditorDialog : Gtk.Window {
        private Gtk.Entry name_entry;
        private Gtk.Entry url_entry;
        private Gtk.Entry homepage_entry;
        private Gtk.Entry country_entry;
        private Gtk.Entry state_entry;
        private Gtk.Entry language_entry;
        private Gtk.Entry tags_entry;
        private Gtk.Label error_label;
        private RadioStation? station;
        private AppModel model;
        private Elmish.Dispatch<Message> dispatch;

        public StationEditorDialog (Gtk.Window parent, AppModel model,
                Elmish.Dispatch<Message> dispatch, RadioStation? station) {
            Object (transient_for: parent, modal: true,
                title: station == null ? _("Add local station") : _("Edit station"),
                default_width: 420);
            this.model = model;
            this.dispatch = dispatch;
            this.station = station;

            var header = new Gtk.HeaderBar ();
            var cancel = new Gtk.Button.with_label (_("Cancel"));
            cancel.clicked.connect (() => close ());
            header.pack_start (cancel);
            var save = new Gtk.Button.with_label (_("Save"));
            save.add_css_class ("suggested-action");
            save.clicked.connect (on_save);
            header.pack_end (save);
            set_titlebar (header);

            var grid = new Gtk.Grid () {
                column_spacing = 12,
                row_spacing = 8,
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12
            };

            name_entry = new Gtk.Entry () { hexpand = true };
            url_entry = new Gtk.Entry () { hexpand = true };
            homepage_entry = new Gtk.Entry () { hexpand = true };
            country_entry = new Gtk.Entry () { hexpand = true };
            state_entry = new Gtk.Entry () { hexpand = true };
            language_entry = new Gtk.Entry () { hexpand = true };
            tags_entry = new Gtk.Entry () { hexpand = true };

            string initial_name = station == null ? "" : station.name;
            string initial_url = station == null ? "" : station.url;
            string initial_homepage = station == null ? "" : station.homepage;
            string initial_country = station == null ? "" : station.country;
            string initial_state = station == null ? "" : station.state;
            string initial_language = station == null ? "" : station.language;
            string initial_tags = station == null ? "" : station.tags;

            name_entry.text = initial_name;
            url_entry.text = initial_url;
            homepage_entry.text = initial_homepage;
            country_entry.text = initial_country;
            state_entry.text = initial_state;
            language_entry.text = initial_language;
            tags_entry.text = initial_tags;

            add_row (grid, 0, _("Name"), name_entry);
            add_row (grid, 1, _("Stream URL"), url_entry);
            add_row (grid, 2, _("Homepage"), homepage_entry);
            add_row (grid, 3, _("Country"), country_entry);
            add_row (grid, 4, _("State"), state_entry);
            add_row (grid, 5, _("Language"), language_entry);
            add_row (grid, 6, _("Tags"), tags_entry);

            error_label = new Gtk.Label ("") {
                halign = Gtk.Align.START,
                wrap = true,
                visible = false
            };
            error_label.add_css_class ("error");
            set_child (grid);
            grid.attach (error_label, 0, 7, 2, 1);
        }

        private void add_row (Gtk.Grid grid, int row, string label_text, Gtk.Widget widget) {
            var label = new Gtk.Label (label_text) {
                halign = Gtk.Align.END,
                xalign = 1
            };
            label.add_css_class ("dim-label");
            grid.attach (label, 0, row, 1, 1);
            grid.attach (widget, 1, row, 1, 1);
        }

        private void on_save () {
            var result = new RadioStation ();
            result.id = station == null ? "" : station.id;
            result.name = name_entry.text;
            result.url = url_entry.text;
            result.original_url = result.url;
            result.homepage = homepage_entry.text;
            result.country = country_entry.text;
            result.state = state_entry.text;
            result.language = language_entry.text;
            result.tags = tags_entry.text;

            string? error = StationValidation.validate (result.name, result.url,
                result.homepage, model.config, station == null ? null : station.id);
            if (error != null) {
                error_label.label = error;
                error_label.visible = true;
                return;
            }

            if (station == null)
                dispatch (new AddLocalStationMessage (result));
            else
                dispatch (new UpdateLocalStationMessage (result));
            close ();
        }
    }
}
