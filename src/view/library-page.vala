// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    // The library tab: empty state, station list and the details sidebar.
    public class LibraryPage : Gtk.Box {
        public signal void edit_requested (RadioStation station);

        private Gtk.Stack stack;
        private StationList list;
        private Gtk.Revealer details_revealer;
        private DetailsPanel details_panel;

        public LibraryPage (Elmish.Dispatch<Message> dispatch) {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);
            hexpand = true;
            vexpand = true;

            stack = new Gtk.Stack () {
                transition_type = Gtk.StackTransitionType.CROSSFADE,
                hexpand = true
            };

            var empty = new Gtk.Box (Gtk.Orientation.VERTICAL, 8) {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER
            };
            var icon = new Gtk.Image.from_icon_name ("application-rss+xml-symbolic") {
                pixel_size = 128
            };
            var empty_title = new Gtk.Label (_("Your library is empty"));
            empty_title.add_css_class ("title-2");
            var empty_hint = new Gtk.Label (_("Press + to add a radio station"));
            empty_hint.add_css_class ("dim-label");
            var empty_add = new Gtk.Button.with_label (_("Add station")) {
                halign = Gtk.Align.CENTER,
                margin_top = 12
            };
            empty_add.clicked.connect (() => dispatch (
                new SetViewMessage (ViewMode.ADD_STATION)));
            empty.append (icon);
            empty.append (empty_title);
            empty.append (empty_hint);
            empty.append (empty_add);
            stack.add_named (empty, "empty");

            list = new StationList (dispatch, StationListMode.LIBRARY);
            var scroll = new Gtk.ScrolledWindow () {
                child = list,
                vexpand = true,
                hscrollbar_policy = Gtk.PolicyType.NEVER
            };
            stack.add_named (scroll, "list");

            details_panel = new DetailsPanel (dispatch);
            details_panel.edit_requested.connect ((station) => {
                edit_requested (station);
            });
            var details_scroll = new Gtk.ScrolledWindow () {
                child = details_panel,
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                width_request = 320,
                propagate_natural_width = false,
                hexpand = false,
                vexpand = true
            };
            details_revealer = new Gtk.Revealer () {
                transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT,
                child = details_scroll
            };

            append (stack);
            append (new Gtk.Separator (Gtk.Orientation.VERTICAL));
            append (details_revealer);
        }

        public void update (AppModel model) {
            bool empty = model.library_order.length == 0;
            stack.set_visible_child_name (empty ? "empty" : "list");
            list.update (model.library_order, model);
            details_revealer.reveal_child = model.details_visible;
            details_panel.update (model.details_station, model);
        }
    }
}
