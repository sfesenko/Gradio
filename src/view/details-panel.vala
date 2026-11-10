// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public class DetailsPanel : Gtk.Box {
        private Elmish.Dispatch<Message> dispatch;
        private RadioStation? station;
        private Gtk.Label name_label;
        private Gtk.Label meta_label;
        private Gtk.Label tags_label;
        private Gtk.Label now_playing_label;
        private Gtk.LinkButton homepage_button;
        private Gtk.Label streams_heading;
        private Gtk.Box streams_box;

        public DetailsPanel (Elmish.Dispatch<Message> dispatch) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 8);
            this.dispatch = dispatch;
            margin_top = 12;
            margin_bottom = 12;
            margin_start = 12;
            margin_end = 12;

            var close_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            var close = new Gtk.Button () {
                icon_name = "go-next-symbolic",
                tooltip_text = _("Hide details"),
                halign = Gtk.Align.START
            };
            close.clicked.connect (() => dispatch (new HideDetailsMessage ()));
            close_row.append (close);
            append (close_row);

            var name_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                halign = Gtk.Align.START
            };
            name_label = new Gtk.Label ("") {
                halign = Gtk.Align.START,
                wrap = true,
                xalign = 0,
                max_width_chars = 24
            };
            name_label.add_css_class ("title-3");
            name_row.append (name_label);

            homepage_button = new Gtk.LinkButton ("") {
                halign = Gtk.Align.START,
                valign = Gtk.Align.CENTER,
                tooltip_text = _("Homepage"),
                visible = false
            };
            homepage_button.set_child (new Gtk.Image.from_icon_name ("web-browser-symbolic"));
            name_row.append (homepage_button);
            append (name_row);

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

            now_playing_label = new Gtk.Label ("") {
                halign = Gtk.Align.START,
                wrap = true,
                xalign = 0,
                visible = false
            };
            now_playing_label.add_css_class ("dim-label");
            append (now_playing_label);

            streams_heading = new Gtk.Label (_("Streams")) {
                halign = Gtk.Align.START,
                xalign = 0,
                visible = false
            };
            streams_heading.add_css_class ("dim-label");
            append (streams_heading);

            streams_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            append (streams_box);
        }

        public void update (RadioStation? station, AppModel model) {
            this.station = station;
            sensitive = station != null;

            if (station == null) {
                name_label.label = "";
                meta_label.label = "";
                tags_label.label = "";
                now_playing_label.label = "";
                now_playing_label.visible = false;
                homepage_button.visible = false;
                rebuild_streams (null);
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

            bool is_current = model.current_station != null && model.current_station.id == station.id;
            now_playing_label.label = is_current ? model.stream_title : "";
            now_playing_label.visible = now_playing_label.label != "";

            homepage_button.visible = station.homepage != "";
            if (station.homepage != "")
                homepage_button.set_uri (station.homepage);

            rebuild_streams (station);
        }

        private void rebuild_streams (RadioStation? station) {
            Gtk.Widget? child = streams_box.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                streams_box.remove (child);
                child = next;
            }

            if (station == null) {
                streams_heading.visible = false;
                return;
            }

            string[] urls = station.stream_urls ();
            streams_heading.visible = urls.length > 0;
            foreach (string url in urls) {
                var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
                var url_label = new Gtk.Label (url) {
                    halign = Gtk.Align.START,
                    valign = Gtk.Align.START,
                    wrap = true,
                    selectable = true,
                    xalign = 0,
                    hexpand = true
                };
                url_label.add_css_class ("dim-label");
                row.append (url_label);

                string tech = station.tech_info ();
                if (tech != "") {
                    var tech_label = new Gtk.Label (tech) {
                        halign = Gtk.Align.END,
                        valign = Gtk.Align.START
                    };
                    tech_label.add_css_class ("dim-label");
                    row.append (tech_label);
                }

                streams_box.append (row);
            }
        }
    }
}
