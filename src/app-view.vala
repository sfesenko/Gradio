// SPDX-License-Identifier: GPL-3.0-or-later

public class Gradio.MainView : Gtk.ApplicationWindow {
    private unowned Elmish.Dispatch<Gradio.Message> dispatch;
    private Gtk.Stack stack;
    private Gradio.LibraryPage library_page;
    private Gradio.AddStationPage add_page;
    private Gtk.Button add_button;
    private Gtk.Button back_button;
    private Gtk.Label title_label;
    private Gtk.Label subtitle_label;
    private Gtk.Box title_box;
    private Gtk.HeaderBar header;
    private Gtk.Box header_text_area;
    private Gtk.Box header_controls_area;
    private Gtk.Label empty_title;
    private Gtk.Box player_area;
    private Gradio.PlayerBar player_bar;
    private Gtk.Box status_bar;
    private Gtk.Label status_label;
    private bool syncing_sort = false;
    private Gtk.CheckButton sort_custom_button;
    private Gtk.CheckButton sort_name_button;
    private Gtk.CheckButton sort_country_button;
    private Gtk.CheckButton sort_state_button;
    private Gtk.CheckButton sort_language_button;
    private Gtk.CheckButton sort_bitrate_button;
    private Gtk.Switch sort_descending_switch;
    private Gradio.AppConfig config;
    private Gradio.CastButton cast_button;

    public MainView (Gtk.Application app) {
        Object (application: app);
    }

    public void build_ui (Elmish.Dispatch<Gradio.Message> dispatch, Gradio.AppModel model) {
        this.dispatch = dispatch;
        this.config = model.config;

        var css = new Gtk.CssProvider ();
        string rules = ".current-station { background-color: alpha(@accent_bg_color, 0.25); }\n" +
            ".dragging { opacity: 0.5; }\n" +
            ".drop-before { box-shadow: inset 0 2px 0 0 @accent_bg_color; }\n" +
            ".drop-after { box-shadow: inset 0 -2px 0 0 @accent_bg_color; }\n" +
            ".cast-active { background-color: alpha(@accent_bg_color, 0.25); border-radius: 6px; }";
        css.load_from_data (rules.data);
        Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        set_title (_("Gradio"));
        set_default_size (model.config.window_width, model.config.window_height);
        if (model.config.maximized)
            maximize ();

        close_request.connect (() => {
            dispatch (new WindowGeometryChangedMessage (get_width (), get_height (), is_maximized ()));
            dispatch (new WindowCloseRequestedMessage ());
            return true;
        });

        header = new Gtk.HeaderBar ();

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

        header_text_area = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            valign = Gtk.Align.CENTER,
            visible = false
        };
        header_text_area.append (new Gtk.Separator (Gtk.Orientation.VERTICAL) {
            margin_top = 4,
            margin_bottom = 4
        });
        header.pack_start (header_text_area);

        title_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER
        };
        title_label = new Gtk.Label (_("Gradio")) {
            ellipsize = Pango.EllipsizeMode.END,
            max_width_chars = 48
        };
        title_label.add_css_class ("title-4");
        subtitle_label = new Gtk.Label ("") {
            ellipsize = Pango.EllipsizeMode.END,
            max_width_chars = 48,
            visible = false
        };
        subtitle_label.add_css_class ("dim-label");
        subtitle_label.add_css_class ("caption");
        title_box.append (title_label);
        title_box.append (subtitle_label);
        header.set_title_widget (title_box);

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
            if (syncing_sort)
                return;
            dispatch (new SetLibrarySortMessage (active_sort_mode (),
                sort_descending_switch.active));
        });
        header.pack_end (sort_button);

        cast_button = new Gradio.CastButton (dispatch);
        header.pack_end (cast_button);

        header_controls_area = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            valign = Gtk.Align.CENTER,
            visible = false
        };
        // Packed last, so it sits left of the sort and menu buttons.
        header.pack_end (header_controls_area);

        empty_title = new Gtk.Label ("");

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
        library_page = new Gradio.LibraryPage (dispatch);
        library_page.edit_requested.connect ((station) => open_station_editor (station));
        stack.add_named (library_page, "library");
        add_page = new Gradio.AddStationPage (dispatch, model);
        stack.add_named (add_page, "add");

        player_bar = new Gradio.PlayerBar (dispatch);

        player_area = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        player_area.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));

        status_bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            margin_top = 4,
            margin_bottom = 4,
            margin_start = 12,
            margin_end = 12,
            visible = false
        };
        status_label = new Gtk.Label ("") {
            halign = Gtk.Align.START,
            hexpand = true,
            xalign = 0,
            ellipsize = Pango.EllipsizeMode.END
        };
        status_label.add_css_class ("dim-label");
        status_bar.append (status_label);

        var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        root.append (stack);
        root.append (player_area);
        root.append (status_bar);
        set_child (root);

        apply_player_placement (model.config.player_in_header);
        render (model);
    }

    private void apply_player_placement (bool header_mode) {
        if (header_mode) {
            header.set_title_widget (empty_title);
            header_text_area.visible = true;
            header_controls_area.visible = true;
            player_area.visible = false;
            player_bar.place_in_header (header_text_area, header_controls_area);
        } else {
            header.set_title_widget (title_box);
            header_text_area.visible = false;
            header_controls_area.visible = false;
            player_area.visible = true;
            player_bar.place_in_bar (player_area);
        }
    }

    private void open_station_editor (RadioStation? station) {
        var dialog = new StationEditorDialog (this, config, dispatch, station);
        dialog.present ();
    }

    private LibrarySortMode active_sort_mode () {
        if (sort_name_button.active)
            return LibrarySortMode.NAME;
        if (sort_country_button.active)
            return LibrarySortMode.COUNTRY;
        if (sort_state_button.active)
            return LibrarySortMode.STATE;
        if (sort_language_button.active)
            return LibrarySortMode.LANGUAGE;
        if (sort_bitrate_button.active)
            return LibrarySortMode.BITRATE;
        return LibrarySortMode.CUSTOM;
    }

    private void dispatch_library_sort (LibrarySortMode mode) {
        if (syncing_sort)
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

    private void open_add_view () {
        dispatch (new SetViewMessage (ViewMode.ADD_STATION));
        if (add_page != null)
            add_page.focus_search ();
    }

    private void open_preferences () {
        var dialog = new Gradio.SettingsDialog (this, config, dispatch);
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

    private void render (Gradio.AppModel model) {
        config = model.config;

        bool adding = model.view == ViewMode.ADD_STATION;
        stack.set_visible_child_name (adding ? "add" : "library");
        add_button.visible = !adding;
        back_button.visible = adding;
        apply_player_placement (model.config.player_in_header);
        cast_button.update (model);
        if (adding) {
            title_label.label = _("Add station");
            subtitle_label.visible = false;
        } else if (model.current_station != null) {
            title_label.label = _("Gradio: %s").printf (model.current_station.name);
            subtitle_label.label = model.stream_title;
            subtitle_label.visible = model.stream_title != "";
        } else {
            title_label.label = _("Gradio");
            subtitle_label.visible = false;
        }

        sync_sort_controls (model);

        library_page.update (model);

        add_page.update (model);

        player_bar.update (model);

        status_label.label = model.status_message;
        status_bar.visible = model.config.show_status_bar && model.status_message != "";
    }

    public void update (Gradio.Message msg, Gradio.AppModel model) {
        render (model);
    }
}
