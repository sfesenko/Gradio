// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public class DetailsPanel : Gtk.Box {
        private Elmish.Dispatch<Message> dispatch;
        private RadioStation? station;
        private Gtk.Label name_label;
        private Gtk.Label meta_label;
        private Gtk.Label tags_label;
        private Gtk.Label tech_label;
        private Gtk.LinkButton homepage_button;
        private Gtk.Label url_label;
        private Gtk.Button play_button;
        private bool playing;
        private bool is_current;

        public DetailsPanel (Elmish.Dispatch<Message> dispatch) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 8);
            this.dispatch = dispatch;
            width_request = 300;
            margin_top = 12;
            margin_bottom = 12;
            margin_start = 12;
            margin_end = 12;

            var close_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            var close = new Gtk.Button () {
                icon_name = "window-close-symbolic",
                tooltip_text = _("Close details"),
                halign = Gtk.Align.END
            };
            close.clicked.connect (() => dispatch (new HideDetailsMessage ()));
            close_row.append (close);
            append (close_row);

            name_label = new Gtk.Label ("") {
                halign = Gtk.Align.START,
                wrap = true,
                xalign = 0
            };
            name_label.add_css_class ("title-3");
            append (name_label);

            meta_label = new Gtk.Label ("") {
                halign = Gtk.Align.START,
                wrap = true,
                xalign = 0
            };
            meta_label.add_css_class ("dim-label");
            append (meta_label);

            tags_label = new Gtk.Label ("") {
                halign = Gtk.Align.START,
                wrap = true,
                xalign = 0
            };
            tags_label.add_css_class ("dim-label");
            append (tags_label);

            tech_label = new Gtk.Label ("") {
                halign = Gtk.Align.START,
                xalign = 0
            };
            tech_label.add_css_class ("dim-label");
            append (tech_label);

            homepage_button = new Gtk.LinkButton.with_label ("", _("Homepage")) {
                halign = Gtk.Align.START,
                visible = false
            };
            append (homepage_button);

            url_label = new Gtk.Label ("") {
                halign = Gtk.Align.START,
                wrap = true,
                selectable = true,
                xalign = 0
            };
            url_label.add_css_class ("dim-label");
            append (url_label);

            play_button = new Gtk.Button.with_label (_("Play")) {
                halign = Gtk.Align.FILL,
                margin_top = 12
            };
            play_button.clicked.connect (() => {
                if (station == null)
                    return;
                if (is_current && playing)
                    dispatch (new TogglePlayMessage ());
                else
                    dispatch (new PlayStationMessage (station));
            });
            append (play_button);

            var remove = new Gtk.Button.with_label (_("Remove from library")) {
                halign = Gtk.Align.FILL
            };
            remove.clicked.connect (() => {
                if (station != null)
                    dispatch (new RemoveStationMessage (station.id));
            });
            append (remove);
        }

        public void update (RadioStation? station, AppModel model) {
            this.station = station;
            this.playing = model.playing;
            sensitive = station != null;

            if (station == null) {
                name_label.label = "";
                meta_label.label = "";
                tags_label.label = "";
                tech_label.label = "";
                url_label.label = "";
                homepage_button.visible = false;
                play_button.label = _("Play");
                return;
            }

            name_label.label = station.name;

            var meta = new GLib.StringBuilder ();
            if (station.country != "")
                meta.append (station.country);
            if (station.language != "") {
                if (meta.len > 0)
                    meta.append (" • ");
                meta.append (station.language);
            }
            meta_label.label = meta.str;
            meta_label.visible = meta.len > 0;

            tags_label.label = station.tags;
            tags_label.visible = station.tags != "";

            tech_label.label = station.tech_info ();
            tech_label.visible = station.tech_info () != "";

            homepage_button.visible = station.homepage != "";
            if (station.homepage != "")
                homepage_button.set_uri (station.homepage);

            url_label.label = station.url;

            is_current = model.current_station != null && model.current_station.id == station.id;
            play_button.label = is_current && model.playing ? _("Stop") : _("Play");
        }
    }
}
