// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    // The add-station tab: search, filters and discover lists.
    public class AddStationPage : Gtk.Box {
        private unowned Elmish.Dispatch<Message> dispatch;
        private Gtk.SearchEntry search_entry;
        private Gtk.Stack add_stack;
        private StationList search_list;
        private StationList discover_popular_list;
        private StationList discover_new_list;
        private Gtk.Label discover_empty_label;
        private Gtk.Label discover_error_label;
        private Gtk.Spinner spinner;
        private Gtk.Label search_error_label;
        private Gtk.DropDown country_dropdown;
        private Gtk.DropDown language_dropdown;
        private Gtk.DropDown tag_dropdown;
        private bool syncing_filters = false;
        private string filter_signature = "";
        private bool was_visible = false;

        public AddStationPage (Elmish.Dispatch<Message> dispatch, AppModel model) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 8);
            this.dispatch = dispatch;
            hexpand = true;
            vexpand = true;

            var search_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8) {
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12
            };

            search_entry = new Gtk.SearchEntry () {
                placeholder_text = _("Search for radio stations"),
                search_delay = 300,
                hexpand = true
            };
            search_entry.search_started.connect (() => dispatch (
                new SearchRequestedMessage (search_entry.text)));
            search_entry.activate.connect (() => dispatch (
                new SearchRequestedMessage (search_entry.text)));
            search_entry.stop_search.connect (() => dispatch (
                new SearchRequestedMessage ("")));
            search_row.append (search_entry);

            var search_sort = new Gtk.DropDown.from_strings (
                { _("Relevance"), _("Clicks"), _("Votes"), _("Bitrate") });
            search_sort.tooltip_text = _("Sort search results");
            search_sort.valign = Gtk.Align.CENTER;
            search_sort.selected = (uint) model.config.search_sort;
            search_sort.notify["selected"].connect (() => {
                dispatch (new SetSearchSortModeMessage ((SearchSortMode) search_sort.selected));
            });
            search_row.append (search_sort);

            append (search_row);

            var filters_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                margin_start = 12,
                margin_end = 12,
                margin_bottom = 12,
                homogeneous = true
            };

            country_dropdown = build_filter_dropdown (SearchFilterKind.COUNTRY,
                _("Country"), _("Filter by country"));
            filters_row.append (country_dropdown);

            var state_entry = new Gtk.Entry () {
                placeholder_text = _("State"),
                hexpand = true,
                text = model.config.search_filters.state,
                tooltip_text = _("Filter by state")
            };
            state_entry.activate.connect (() => dispatch (
                new SetSearchFilterMessage (SearchFilterKind.STATE, state_entry.text)));
            var state_focus = new Gtk.EventControllerFocus ();
            state_focus.leave.connect (() => dispatch (
                new SetSearchFilterMessage (SearchFilterKind.STATE, state_entry.text)));
            state_entry.add_controller (state_focus);
            filters_row.append (state_entry);

            language_dropdown = build_filter_dropdown (SearchFilterKind.LANGUAGE,
                _("Language"), _("Filter by language"));
            filters_row.append (language_dropdown);

            tag_dropdown = build_filter_dropdown (SearchFilterKind.TAG,
                _("Tag"), _("Filter by tag"));
            filters_row.append (tag_dropdown);

            append (filters_row);

            add_stack = new Gtk.Stack () {
                transition_type = Gtk.StackTransitionType.CROSSFADE,
                vexpand = true
            };

            var idle = new Gtk.Label (_("Search by name, or leave it empty and use the filters below.")) {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER
            };
            idle.add_css_class ("dim-label");
            add_stack.add_named (idle, "idle");

            spinner = new Gtk.Spinner () {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER
            };
            add_stack.add_named (spinner, "loading");

            search_list = new StationList (dispatch, StationListMode.BROWSE);
            var scroll = new Gtk.ScrolledWindow () {
                child = search_list,
                vexpand = true,
                hscrollbar_policy = Gtk.PolicyType.NEVER
            };
            add_stack.add_named (scroll, "results");

            var discover_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                margin_top = 6,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12
            };
            var popular_label = new Gtk.Label (_("Popular near you")) {
                halign = Gtk.Align.START
            };
            popular_label.add_css_class ("title-4");
            discover_content.append (popular_label);
            discover_popular_list = new StationList (dispatch, StationListMode.BROWSE);
            discover_content.append (discover_popular_list);

            var new_label = new Gtk.Label (_("New stations")) {
                halign = Gtk.Align.START,
                margin_top = 12
            };
            new_label.add_css_class ("title-4");
            discover_content.append (new_label);
            discover_new_list = new StationList (dispatch, StationListMode.BROWSE);
            discover_content.append (discover_new_list);

            discover_empty_label = new Gtk.Label (_("No stations found.")) {
                halign = Gtk.Align.CENTER,
                margin_top = 12
            };
            discover_empty_label.add_css_class ("dim-label");
            discover_content.append (discover_empty_label);

            discover_error_label = new Gtk.Label ("") {
                halign = Gtk.Align.CENTER,
                wrap = true,
                margin_top = 12
            };
            discover_error_label.add_css_class ("dim-label");
            discover_content.append (discover_error_label);

            var discover_scroll = new Gtk.ScrolledWindow () {
                child = discover_content,
                vexpand = true,
                hscrollbar_policy = Gtk.PolicyType.NEVER
            };
            add_stack.add_named (discover_scroll, "discover");

            var empty = new Gtk.Label (_("No stations found.")) {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER
            };
            empty.add_css_class ("dim-label");
            add_stack.add_named (empty, "empty");

            search_error_label = new Gtk.Label ("") {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER,
                wrap = true,
                margin_start = 24,
                margin_end = 24
            };
            search_error_label.add_css_class ("dim-label");
            add_stack.add_named (search_error_label, "error");

            append (add_stack);
            sync_filter_pickers (model);
        }

        public void update (AppModel model) {
            bool visible = model.view == ViewMode.ADD_STATION;
            if (visible && !was_visible) {
                search_entry.text = "";
                focus_search ();
            }
            was_visible = visible;
            sync_filter_pickers (model);

            discover_popular_list.update (model.discover_popular, model);
            discover_new_list.update (model.discover_new, model);

            var results = StationSort.sort_search (model.search_results,
                model.config.search_sort);
            search_list.update (results, model);

            bool discover_mode = visible && model.search_query == "" &&
                !model.search_active && model.config.search_filters.is_empty ();
            if (discover_mode) {
                if (model.discover_loading) {
                    spinner.spinning = true;
                    add_stack.set_visible_child_name ("loading");
                } else {
                    spinner.spinning = false;
                    if (model.discover_should_show_error ()) {
                        search_error_label.label = model.discover_error;
                        add_stack.set_visible_child_name ("error");
                    } else {
                        discover_empty_label.visible =
                            model.discover_popular.length == 0 &&
                            model.discover_new.length == 0;
                        discover_error_label.label = model.discover_error ?? "";
                        discover_error_label.visible = model.discover_error != null;
                        add_stack.set_visible_child_name ("discover");
                    }
                }
            } else if (model.searching) {
                spinner.spinning = true;
                add_stack.set_visible_child_name ("loading");
            } else {
                spinner.spinning = false;
                if (model.search_error != null) {
                    search_error_label.label = model.search_error;
                    add_stack.set_visible_child_name ("error");
                } else if (!model.search_active) {
                    add_stack.set_visible_child_name ("idle");
                } else if (model.search_results.length == 0) {
                    add_stack.set_visible_child_name ("empty");
                } else {
                    add_stack.set_visible_child_name ("results");
                }
            }
        }

        public void focus_search () {
            GLib.Idle.add (() => {
                search_entry.grab_focus ();
                return false;
            });
        }

        private static Gtk.ListItemFactory plain_value_factory () {
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect ((obj) => {
                var item = obj as Gtk.ListItem;
                item.child = new Gtk.Label ("") {
                    halign = Gtk.Align.START
                };
            });
            factory.bind.connect ((obj) => {
                var item = obj as Gtk.ListItem;
                var label = item.child as Gtk.Label;
                if (label == null)
                    return;
                var string_object = item.item as Gtk.StringObject;
                label.label = string_object != null ? string_object.string : "";
            });
            return factory;
        }

        // The selected value is shown as inlay caption text when nothing is
        // filtered, mirroring the placeholder of a Gtk.Entry.
        private static Gtk.ListItemFactory inlay_caption_factory (string caption) {
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect ((obj) => {
                var item = obj as Gtk.ListItem;
                var label = new Gtk.Label (caption) {
                    halign = Gtk.Align.START
                };
                label.add_css_class ("dim-label");
                item.child = label;
            });
            factory.bind.connect ((obj) => {
                var item = obj as Gtk.ListItem;
                var label = item.child as Gtk.Label;
                if (label == null)
                    return;
                var string_object = item.item as Gtk.StringObject;
                string value = string_object != null ? string_object.string : "";
                if (value == "" || value == _("Any")) {
                    label.label = caption;
                    label.add_css_class ("dim-label");
                } else {
                    label.label = value;
                    label.remove_css_class ("dim-label");
                }
            });
            return factory;
        }

        private Gtk.DropDown build_filter_dropdown (SearchFilterKind field,
                string caption, string tooltip) {
            var dropdown = new Gtk.DropDown.from_strings ({ _("Any") }) {
                hexpand = true,
                tooltip_text = tooltip
            };
            dropdown.factory = inlay_caption_factory (caption);
            dropdown.list_factory = plain_value_factory ();
            dropdown.enable_search = true;
            dropdown.notify["selected"].connect (() => {
                if (syncing_filters)
                    return;
                var list = dropdown.model;
                if (list == null)
                    return;
                uint index = dropdown.selected;
                if (index >= list.get_n_items ())
                    return;
                var item = list.get_item (index) as Gtk.StringObject;
                string value = item != null ? item.string : "";
                dispatch (new SetSearchFilterMessage (field, index == 0 ? "" : value));
            });
            return dropdown;
        }

        private static void append_option_signature (GLib.StringBuilder builder,
                string[] options) {
            for (uint i = 0; i < options.length; i++)
                builder.append_printf ("\x1e%s", options[i]);
            builder.append ("\x1f");
        }

        private string filter_picker_signature (AppModel model) {
            var builder = new GLib.StringBuilder ();
            builder.append_printf ("%s\x1f%s\x1f%s\x1f%s\x1f",
                model.config.search_filters.country, model.config.search_filters.state,
                model.config.search_filters.language, model.config.search_filters.tag);
            append_option_signature (builder, model.filter_countries);
            append_option_signature (builder, model.filter_languages);
            append_option_signature (builder, model.filter_tags);
            return builder.str;
        }

        private static void set_filter_options (Gtk.DropDown dropdown, string current,
                string[] options) {
            var list = new Gtk.StringList (null);
            list.append (_("Any"));
            bool present = current == "";
            uint selected = 0;
            for (uint i = 0; i < options.length; i++) {
                list.append (options[i]);
                if (options[i] == current) {
                    present = true;
                    selected = i + 1;
                }
            }
            if (!present) {
                list.append (current);
                selected = options.length + 1;
            }
            dropdown.model = list;
            dropdown.selected = selected;
        }

        private void sync_filter_pickers (AppModel model) {
            string sig = filter_picker_signature (model);
            if (sig == filter_signature)
                return;
            filter_signature = sig;

            syncing_filters = true;
            set_filter_options (country_dropdown, model.config.search_filters.country,
                model.filter_countries);
            set_filter_options (language_dropdown, model.config.search_filters.language,
                model.filter_languages);
            set_filter_options (tag_dropdown, model.config.search_filters.tag,
                model.filter_tags);
            syncing_filters = false;
        }
    }
}
