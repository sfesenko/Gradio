// SPDX-License-Identifier: GPL-3.0-or-later

public class Gradio.MainView : Gtk.ApplicationWindow {
    private Elmish.Dispatch<Gradio.Message> dispatch;
    private Gtk.Stack stack;
    private Gtk.Stack library_stack;
    private Gtk.ListBox list_box;
    private Gtk.Button add_button;
    private Gtk.Button back_button;
    private Gtk.Label title_label;
    private Gradio.PlayerBar player_bar;
    private Gradio.DetailsPanel details_panel;
    private Gtk.Revealer details_revealer;
    private Gtk.SearchEntry search_entry;
    private Gtk.Stack add_stack;
    private Gtk.ListBox search_list_box;
    private Gtk.Spinner spinner;
    private Gtk.Label search_error_label;
    private bool last_adding = false;
    private Gradio.AppModel app_model;
    private string library_signature = "";
    private string search_signature = "";

    public MainView (Gtk.Application app) {
        Object (application: app);
    }

    public void build_ui (Elmish.Dispatch<Gradio.Message> dispatch, Gradio.AppModel model) {
        this.dispatch = dispatch;

        var css = new Gtk.CssProvider ();
        string rules = ".current-station { background-color: alpha(@accent_bg_color, 0.25); }";
        css.load_from_data (rules.data);
        Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        set_title (_("Gradio"));
        set_default_size (900, 600);

        var header = new Gtk.HeaderBar ();

        add_button = new Gtk.Button () {
            icon_name = "list-add-symbolic",
            tooltip_text = _("Add station")
        };
        add_button.clicked.connect (open_add_view);
        header.pack_start (add_button);

        back_button = new Gtk.Button () {
            icon_name = "go-previous-symbolic",
            tooltip_text = _("Back to library"),
            visible = false
        };
        back_button.clicked.connect (() => dispatch (new SetViewMessage (ViewMode.LIBRARY)));
        header.pack_start (back_button);

        title_label = new Gtk.Label (_("Gradio"));
        title_label.add_css_class ("title-4");
        header.set_title_widget (title_label);

        var menu_button = new Gtk.MenuButton () {
            icon_name = "open-menu-symbolic",
            tooltip_text = _("Menu")
        };
        var menu = new GLib.Menu ();
        menu.append (_("Preferences"), "win.preferences");
        menu.append (_("About"), "app.about");
        menu.append (_("Quit"), "app.quit");
        menu_button.set_menu_model (menu);
        header.pack_end (menu_button);

        set_titlebar (header);

        var add_station_action = new GLib.SimpleAction ("add-station", null);
        add_station_action.activate.connect (open_add_view);
        add_action (add_station_action);

        var library_action = new GLib.SimpleAction ("library", null);
        library_action.activate.connect (() => dispatch (new SetViewMessage (ViewMode.LIBRARY)));
        add_action (library_action);

        var preferences_action = new GLib.SimpleAction ("preferences", null);
        preferences_action.activate.connect (open_preferences);
        add_action (preferences_action);

        var toggle_action = new GLib.SimpleAction ("toggle-play", null);
        toggle_action.activate.connect (() => dispatch (new TogglePlayMessage ()));
        add_action (toggle_action);

        var details_action = new GLib.SimpleAction ("details", null);
        details_action.activate.connect (() => dispatch (new ShowDetailsMessage (null)));
        add_action (details_action);

        stack = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.CROSSFADE,
            hexpand = true,
            vexpand = true
        };
        stack.add_named (build_library_page (), "library");
        stack.add_named (build_add_page (), "add");

        player_bar = new Gradio.PlayerBar (dispatch);

        var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        root.append (stack);
        root.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        root.append (player_bar);
        set_child (root);

        update (new Gradio.SetViewMessage (model.view), model);
    }

    private Gtk.Widget build_library_page () {
        library_stack = new Gtk.Stack () {
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
        empty_add.clicked.connect (open_add_view);
        empty.append (icon);
        empty.append (empty_title);
        empty.append (empty_hint);
        empty.append (empty_add);
        library_stack.add_named (empty, "empty");

        list_box = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.NONE,
            show_separators = true
        };
        var scroll = new Gtk.ScrolledWindow () {
            child = list_box,
            vexpand = true,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };
        library_stack.add_named (scroll, "list");

        details_panel = new Gradio.DetailsPanel (dispatch);
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

        var page = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        page.append (library_stack);
        page.append (new Gtk.Separator (Gtk.Orientation.VERTICAL));
        page.append (details_revealer);
        return page;
    }

    private Gtk.Widget build_add_page () {
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);

        search_entry = new Gtk.SearchEntry () {
            placeholder_text = _("Search for radio stations"),
            search_delay = 300,
            margin_top = 12,
            margin_bottom = 12,
            margin_start = 12,
            margin_end = 12
        };
        search_entry.search_started.connect (() => dispatch (new SearchRequestedMessage (search_entry.text)));
        search_entry.activate.connect (() => dispatch (new SearchRequestedMessage (search_entry.text)));
        search_entry.stop_search.connect (() => dispatch (new SearchRequestedMessage ("")));
        box.append (search_entry);

        add_stack = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.CROSSFADE,
            vexpand = true
        };

        var idle = new Gtk.Label (_("Search for radio stations by name.")) {
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

        search_list_box = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.NONE,
            show_separators = true
        };
        var scroll = new Gtk.ScrolledWindow () {
            child = search_list_box,
            vexpand = true,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };
        add_stack.add_named (scroll, "results");

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

        box.append (add_stack);
        return box;
    }

    private static string rows_signature (GLib.GenericArray<Gradio.RadioStation> stations,
            bool show_technical_info) {
        var builder = new GLib.StringBuilder ();
        for (uint i = 0; i < stations.length; i++) {
            var station = stations.get (i);
            builder.append_printf ("%s|%s|%s|%s|%d|%s\n", station.id, station.name, station.country,
                station.codec, station.bitrate, station.url);
        }
        builder.append (show_technical_info ? "tech" : "plain");
        return builder.str;
    }

    private void open_add_view () {
        dispatch (new SetViewMessage (ViewMode.ADD_STATION));
        GLib.Idle.add (() => {
            search_entry.grab_focus ();
            return false;
        });
    }

    private void open_preferences () {
        var dialog = new Gradio.SettingsDialog (this, app_model, dispatch);
        dialog.present ();
    }

    public void update (Gradio.Message msg, Gradio.AppModel model) {
        app_model = model;

        bool adding = model.view == ViewMode.ADD_STATION;
        stack.set_visible_child_name (adding ? "add" : "library");
        add_button.visible = !adding;
        back_button.visible = adding;
        title_label.label = adding ? _("Add station") : _("Gradio");

        if (adding && !last_adding) {
            search_entry.text = "";
            GLib.Idle.add (() => {
                search_entry.grab_focus ();
                return false;
            });
        }
        last_adding = adding;

        string lib_sig = rows_signature (model.config.stations, model.config.show_technical_info);
        if (lib_sig != library_signature) {
            library_signature = lib_sig;
            list_box.remove_all ();
            for (uint i = 0; i < model.config.stations.length; i++) {
                var station = model.config.stations.get (i);
                var row = new Gradio.StationRow (station, true, model.config.show_technical_info,
                    false, false, false, dispatch);
                list_box.append (row);
            }
        }
        for (uint i = 0; i < model.config.stations.length; i++) {
            var station = model.config.stations.get (i);
            var row = list_box.get_row_at_index ((int) i) as Gradio.StationRow;
            if (row == null)
                continue;
            bool is_current = model.current_station != null && model.current_station.id == station.id;
            row.set_state (is_current, model.playing, false, model.stream_title);
        }

        bool empty = model.config.stations.length == 0;
        library_stack.set_visible_child_name (empty ? "empty" : "list");

        string result_sig = rows_signature (model.search_results, model.config.show_technical_info);
        if (result_sig != search_signature) {
            search_signature = result_sig;
            search_list_box.remove_all ();
            for (uint i = 0; i < model.search_results.length; i++) {
                var station = model.search_results.get (i);
                var row = new Gradio.StationRow (station, false, model.config.show_technical_info,
                    false, false, false, dispatch);
                search_list_box.append (row);
            }
        }
        for (uint i = 0; i < model.search_results.length; i++) {
            var station = model.search_results.get (i);
            var row = search_list_box.get_row_at_index ((int) i) as Gradio.StationRow;
            if (row == null)
                continue;
            row.set_state (false, false, model.config.contains_station (station.id));
        }

        if (model.searching) {
            spinner.spinning = true;
            add_stack.set_visible_child_name ("loading");
        } else {
            spinner.spinning = false;
            if (model.search_error != null) {
                search_error_label.label = model.search_error;
                add_stack.set_visible_child_name ("error");
            } else if (model.search_query == "") {
                add_stack.set_visible_child_name ("idle");
            } else if (model.search_results.length == 0) {
                add_stack.set_visible_child_name ("empty");
            } else {
                add_stack.set_visible_child_name ("results");
            }
        }

        details_revealer.reveal_child = model.details_visible;
        details_panel.update (model.details_station, model);
        player_bar.update (model);
    }
}
