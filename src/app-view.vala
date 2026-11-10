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
    private Gtk.DropDown country_dropdown;
    private Gtk.DropDown language_dropdown;
    private Gtk.DropDown tag_dropdown;
    private bool syncing_filters = false;
    private bool syncing_sort = false;
    private Gtk.CheckButton sort_custom_button;
    private Gtk.CheckButton sort_name_button;
    private Gtk.CheckButton sort_country_button;
    private Gtk.CheckButton sort_state_button;
    private Gtk.CheckButton sort_language_button;
    private Gtk.CheckButton sort_bitrate_button;
    private Gtk.Switch sort_descending_switch;
    private string filter_signature = "";
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
        string rules = ".current-station { background-color: alpha(@accent_bg_color, 0.25); }\n" +
            ".dragging { opacity: 0.5; }\n" +
            ".drop-before { box-shadow: inset 0 2px 0 0 @accent_bg_color; }\n" +
            ".drop-after { box-shadow: inset 0 -2px 0 0 @accent_bg_color; }";
        css.load_from_data (rules.data);
        Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        set_title (_("Gradio"));
        set_default_size (model.config.window_width, model.config.window_height);
        if (model.config.maximized)
            maximize ();

        close_request.connect (() => {
            dispatch (new WindowGeometryChangedMessage (get_width (), get_height (), is_maximized ()));
            return false;
        });

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
        menu.append (_("Add local station…"), "win.add-local-station");
        menu.append (_("Import stations…"), "win.import-stations");
        menu.append (_("Export stations…"), "win.export-stations");
        menu.append (_("Export playlist…"), "win.export-playlist");
        menu.append (_("Preferences"), "win.preferences");
        menu.append (_("About"), "app.about");
        menu.append (_("Quit"), "app.quit");
        menu_button.set_menu_model (menu);
        header.pack_end (menu_button);

        var sort_button = new Gtk.MenuButton () {
            icon_name = "view-sort-ascending-symbolic",
            tooltip_text = _("Sort library")
        };
        var sort_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4) {
            margin_top = 8,
            margin_bottom = 8,
            margin_start = 8,
            margin_end = 8
        };
        sort_custom_button = new Gtk.CheckButton.with_label (_("Custom order"));
        sort_name_button = new Gtk.CheckButton.with_label (_("Name"));
        sort_country_button = new Gtk.CheckButton.with_label (_("Country"));
        sort_state_button = new Gtk.CheckButton.with_label (_("State"));
        sort_language_button = new Gtk.CheckButton.with_label (_("Language"));
        sort_bitrate_button = new Gtk.CheckButton.with_label (_("Bitrate"));
        sort_name_button.set_group (sort_custom_button);
        sort_country_button.set_group (sort_custom_button);
        sort_state_button.set_group (sort_custom_button);
        sort_language_button.set_group (sort_custom_button);
        sort_bitrate_button.set_group (sort_custom_button);
        sort_box.append (sort_custom_button);
        sort_box.append (sort_name_button);
        sort_box.append (sort_country_button);
        sort_box.append (sort_state_button);
        sort_box.append (sort_language_button);
        sort_box.append (sort_bitrate_button);

        var sort_descending_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        sort_descending_row.append (new Gtk.Label (_("Descending")) {
            hexpand = true,
            xalign = 0
        });
        sort_descending_switch = new Gtk.Switch () {
            valign = Gtk.Align.CENTER
        };
        sort_descending_row.append (sort_descending_switch);
        sort_box.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        sort_box.append (sort_descending_row);

        var sort_popover = new Gtk.Popover () { child = sort_box };
        sort_button.set_popover (sort_popover);

        sort_custom_button.toggled.connect (() => {
            if (!syncing_sort && sort_custom_button.active)
                dispatch_library_sort (LibrarySortMode.CUSTOM);
        });
        sort_name_button.toggled.connect (() => {
            if (!syncing_sort && sort_name_button.active)
                dispatch_library_sort (LibrarySortMode.NAME);
        });
        sort_country_button.toggled.connect (() => {
            if (!syncing_sort && sort_country_button.active)
                dispatch_library_sort (LibrarySortMode.COUNTRY);
        });
        sort_state_button.toggled.connect (() => {
            if (!syncing_sort && sort_state_button.active)
                dispatch_library_sort (LibrarySortMode.STATE);
        });
        sort_language_button.toggled.connect (() => {
            if (!syncing_sort && sort_language_button.active)
                dispatch_library_sort (LibrarySortMode.LANGUAGE);
        });
        sort_bitrate_button.toggled.connect (() => {
            if (!syncing_sort && sort_bitrate_button.active)
                dispatch_library_sort (LibrarySortMode.BITRATE);
        });
        sort_descending_switch.notify["active"].connect (() => {
            if (syncing_sort || app_model == null)
                return;
            dispatch (new SetLibrarySortMessage (app_model.config.library_sort,
                sort_descending_switch.active));
        });
        header.pack_end (sort_button);

        set_titlebar (header);

        var add_station_action = new GLib.SimpleAction ("add-station", null);
        add_station_action.activate.connect (open_add_view);
        add_action (add_station_action);

        var add_local_action = new GLib.SimpleAction ("add-local-station", null);
        add_local_action.activate.connect (() => open_station_editor (null));
        add_action (add_local_action);

        var library_action = new GLib.SimpleAction ("library", null);
        library_action.activate.connect (() => dispatch (new SetViewMessage (ViewMode.LIBRARY)));
        add_action (library_action);

        var preferences_action = new GLib.SimpleAction ("preferences", null);
        preferences_action.activate.connect (open_preferences);
        add_action (preferences_action);

        var import_action = new GLib.SimpleAction ("import-stations", null);
        import_action.activate.connect (open_import_dialog);
        add_action (import_action);

        var export_action = new GLib.SimpleAction ("export-stations", null);
        export_action.activate.connect (open_export_dialog);
        add_action (export_action);

        var playlist_action = new GLib.SimpleAction ("export-playlist", null);
        playlist_action.activate.connect (open_playlist_dialog);
        add_action (playlist_action);

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
        stack.add_named (build_add_page (model), "add");

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
        details_panel.edit_requested.connect ((station) => open_station_editor (station));
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

    private void open_station_editor (RadioStation? station) {
        var dialog = new StationEditorDialog (this, app_model, dispatch, station);
        dialog.present ();
    }

    private Gtk.Widget build_add_page (Gradio.AppModel model) {
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);

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
        search_entry.search_started.connect (() => dispatch (new SearchRequestedMessage (search_entry.text)));
        search_entry.activate.connect (() => dispatch (new SearchRequestedMessage (search_entry.text)));
        search_entry.stop_search.connect (() => dispatch (new SearchRequestedMessage ("")));
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

        box.append (search_row);

        var filters_grid = new Gtk.Grid () {
            margin_start = 12,
            margin_end = 12,
            margin_bottom = 12,
            row_spacing = 6,
            column_spacing = 6,
            column_homogeneous = true
        };

        country_dropdown = build_filter_dropdown (SearchFilterKind.COUNTRY,
            _("Filter by country"));
        filters_grid.attach (filter_field (_("Country"), country_dropdown), 0, 0, 1, 1);

        var state_entry = new Gtk.Entry () {
            placeholder_text = _("Any"),
            hexpand = true,
            text = model.config.search_filters.state,
            tooltip_text = _("Filter by state")
        };
        state_entry.activate.connect (() => dispatch (
            new SetSearchFilterMessage (SearchFilterKind.STATE, state_entry.text)));
        filters_grid.attach (filter_field (_("State"), state_entry), 1, 0, 1, 1);

        language_dropdown = build_filter_dropdown (SearchFilterKind.LANGUAGE,
            _("Filter by language"));
        filters_grid.attach (filter_field (_("Language"), language_dropdown), 0, 1, 1, 1);

        tag_dropdown = build_filter_dropdown (SearchFilterKind.TAG, _("Filter by tag"));
        filters_grid.attach (filter_field (_("Tag"), tag_dropdown), 1, 1, 1, 1);

        box.append (filters_grid);

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
        sync_filter_pickers (model);
        return box;
    }

    private static Gtk.Widget filter_field (string caption, Gtk.Widget control) {
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        var label = new Gtk.Label (caption) {
            halign = Gtk.Align.START
        };
        label.add_css_class ("dim-label");
        label.add_css_class ("caption");
        box.append (label);
        box.append (control);
        return box;
    }

    private Gtk.DropDown build_filter_dropdown (SearchFilterKind field, string tooltip) {
        var dropdown = new Gtk.DropDown.from_strings ({ _("Any") }) {
            hexpand = true,
            tooltip_text = tooltip
        };
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

    private static void append_option_signature (GLib.StringBuilder builder, string[] options) {
        for (uint i = 0; i < options.length; i++)
            builder.append_printf ("\x1e%s", options[i]);
        builder.append ("\x1f");
    }

    private string filter_picker_signature (Gradio.AppModel model) {
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

    private void sync_filter_pickers (Gradio.AppModel model) {
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

    private void dispatch_library_sort (LibrarySortMode mode) {
        if (syncing_sort || app_model == null)
            return;
        dispatch (new SetLibrarySortMessage (mode, sort_descending_switch.active));
    }

    private void sync_sort_controls (Gradio.AppModel model) {
        syncing_sort = true;
        var mode = model.config.library_sort;
        sort_custom_button.active = mode == LibrarySortMode.CUSTOM;
        sort_name_button.active = mode == LibrarySortMode.NAME;
        sort_country_button.active = mode == LibrarySortMode.COUNTRY;
        sort_state_button.active = mode == LibrarySortMode.STATE;
        sort_language_button.active = mode == LibrarySortMode.LANGUAGE;
        sort_bitrate_button.active = mode == LibrarySortMode.BITRATE;
        sort_descending_switch.active = model.config.library_sort_descending;
        syncing_sort = false;
    }

    private static string rows_signature (GLib.GenericArray<Gradio.RadioStation> stations,
            bool show_technical_info, int icon_size) {
        var builder = new GLib.StringBuilder ();
        for (uint i = 0; i < stations.length; i++) {
            var station = stations.get (i);
            builder.append_printf ("%s|%s|%s|%s|%d|%s\n", station.id, station.name, station.country,
                station.codec, station.bitrate, station.url);
        }
        builder.append_printf ("%s|%d", show_technical_info ? "tech" : "plain", icon_size);
        return builder.str;
    }

    private void attach_library_drag (Gradio.StationRow row) {
        string station_id = row.station.id;
        var handle = row.drag_handle;
        if (handle == null)
            return;

        var source = new Gtk.DragSource () {
            actions = Gdk.DragAction.MOVE
        };
        source.prepare.connect ((x, y) => {
            var value = GLib.Value (typeof (string));
            value.set_string (station_id);
            return new Gdk.ContentProvider.for_value (value);
        });
        source.drag_begin.connect ((drag) => {
            row.add_css_class ("dragging");
        });
        source.drag_end.connect ((drag, delete_data) => {
            row.remove_css_class ("dragging");
            clear_drop_marks ();
        });
        handle.add_controller (source);

        var target = new Gtk.DropTarget (typeof (string), Gdk.DragAction.MOVE);
        target.enter.connect ((x, y) => {
            set_drop_mark (row, y >= row.get_height () / 2.0);
            return Gdk.DragAction.MOVE;
        });
        target.motion.connect ((x, y) => {
            set_drop_mark (row, y >= row.get_height () / 2.0);
            return Gdk.DragAction.MOVE;
        });
        target.leave.connect (() => {
            row.remove_css_class ("drop-before");
            row.remove_css_class ("drop-after");
        });
        target.drop.connect ((value, x, y) => {
            string source_id = (string) value;
            bool after = y >= row.get_height () / 2.0;
            clear_drop_marks ();
            if (source_id != "" && source_id != station_id)
                dispatch (new MoveStationMessage (source_id, station_id, after));
            return true;
        });
        row.add_controller (target);
    }

    private void set_drop_mark (Gtk.Widget row, bool after) {
        clear_drop_marks ();
        row.add_css_class (after ? "drop-after" : "drop-before");
    }

    private void clear_drop_marks () {
        for (int i = 0; ; i++) {
            var row = list_box.get_row_at_index (i);
            if (row == null)
                break;
            row.remove_css_class ("drop-before");
            row.remove_css_class ("drop-after");
        }
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

    private Gtk.FileFilter json_filter () {
        var filter = new Gtk.FileFilter ();
        filter.name = _("JSON files");
        filter.add_pattern ("*.json");
        filter.add_mime_type ("application/json");
        return filter;
    }

    private GLib.ListStore single_filter (Gtk.FileFilter filter) {
        var filters = new GLib.ListStore (typeof (Gtk.FileFilter));
        filters.append (filter);
        return filters;
    }

    private void open_import_dialog () {
        var dialog = new Gtk.FileDialog () {
            title = _("Import stations"),
            modal = true
        };
        var filter = json_filter ();
        dialog.filters = single_filter (filter);
        dialog.default_filter = filter;

        dialog.open.begin (this, null, (obj, res) => {
            try {
                var file = dialog.open.end (res);
                string? path = file != null ? file.get_path () : null;
                if (path != null)
                    dispatch (new ImportStationsMessage (path));
            } catch (GLib.Error e) {
            }
        });
    }

    private void open_export_dialog () {
        var dialog = new Gtk.FileDialog () {
            title = _("Export stations"),
            initial_name = "gradio-stations.json",
            modal = true
        };
        var filter = json_filter ();
        dialog.filters = single_filter (filter);
        dialog.default_filter = filter;

        dialog.save.begin (this, null, (obj, res) => {
            try {
                var file = dialog.save.end (res);
                string? path = file != null ? file.get_path () : null;
                if (path != null)
                    dispatch (new ExportStationsMessage (path));
            } catch (GLib.Error e) {
            }
        });
    }

    private void open_playlist_dialog () {
        var dialog = new Gtk.FileDialog () {
            title = _("Export playlist"),
            initial_name = "gradio-stations.m3u",
            modal = true
        };
        var filter = new Gtk.FileFilter ();
        filter.name = _("M3U playlists");
        filter.add_pattern ("*.m3u");
        filter.add_mime_type ("audio/x-mpegurl");
        dialog.filters = single_filter (filter);
        dialog.default_filter = filter;

        dialog.save.begin (this, null, (obj, res) => {
            try {
                var file = dialog.save.end (res);
                string? path = file != null ? file.get_path () : null;
                if (path != null)
                    dispatch (new ExportPlaylistMessage (path));
            } catch (GLib.Error e) {
            }
        });
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
        sync_filter_pickers (model);
        sync_sort_controls (model);

        var library = StationSort.sort_library (model.config.stations,
            model.config.library_sort, model.config.library_sort_descending);
        string lib_sig = rows_signature (library, model.config.show_technical_info,
            model.config.icon_size) + "|sort:" +
            StationSort.library_sort_to_string (model.config.library_sort) +
            (model.config.library_sort_descending ? ":desc" : ":asc");
        if (lib_sig != library_signature) {
            library_signature = lib_sig;
            list_box.remove_all ();
            for (uint i = 0; i < library.length; i++) {
                var station = library.get (i);
                var row = new Gradio.StationRow (station, true, model.config.show_technical_info,
                    false, false, false, model.favicon_for (station), model.config.icon_size, dispatch);
                list_box.append (row);
                if (model.config.library_sort == LibrarySortMode.CUSTOM)
                    attach_library_drag (row);
                row.set_drag_enabled (model.config.library_sort == LibrarySortMode.CUSTOM);
            }
        }
        for (uint i = 0; i < library.length; i++) {
            var station = library.get (i);
            var row = list_box.get_row_at_index ((int) i) as Gradio.StationRow;
            if (row == null)
                continue;
            bool is_current = model.current_station != null && model.current_station.id == station.id;
            row.set_favicon (model.favicon_for (station));
            row.set_state (is_current, model.playing, false, model.stream_title);
        }

        bool empty = library.length == 0;
        library_stack.set_visible_child_name (empty ? "empty" : "list");

        var results = StationSort.sort_search (model.search_results, model.config.search_sort);
        string result_sig = rows_signature (results, model.config.show_technical_info,
            model.config.icon_size);
        if (result_sig != search_signature) {
            search_signature = result_sig;
            search_list_box.remove_all ();
            for (uint i = 0; i < results.length; i++) {
                var station = results.get (i);
                var row = new Gradio.StationRow (station, false, model.config.show_technical_info,
                    false, false, false, model.favicon_for (station), model.config.icon_size, dispatch);
                search_list_box.append (row);
            }
        }
        for (uint i = 0; i < results.length; i++) {
            var station = results.get (i);
            var row = search_list_box.get_row_at_index ((int) i) as Gradio.StationRow;
            if (row == null)
                continue;
            row.set_favicon (model.favicon_for (station));
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
            } else if (!model.search_active) {
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
