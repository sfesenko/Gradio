// SPDX-License-Identifier: GPL-3.0-or-later

public class Gradio.MainView : Gtk.ApplicationWindow {
    private unowned Elmish.Dispatch<Gradio.Message> dispatch;
    private Gtk.Stack stack;
    private Gradio.LibraryPage library_page;
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
    private bool placement_initialized = false;
    private bool player_in_header_active = false;
    private Gradio.PlayerBar player_bar;
    private Gtk.Box status_bar;
    private Gtk.Label status_label;
    private Gtk.SearchEntry search_entry;
    private Gtk.Stack add_stack;
    private Gradio.StationList search_list_box;
    private Gradio.StationList discover_popular_list;
    private Gradio.StationList discover_new_list;
    private Gtk.Label discover_empty_label;
    private Gtk.Label discover_error_label;
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
    private Gtk.MenuButton cast_button;
    private Gtk.Scale cast_volume_scale;
    private Gtk.Box cast_volume_row;
    private Gtk.Image cast_volume_icon;
    private Gtk.Label cast_volume_value;
    private bool updating_cast_volume = false;
    private Gtk.ListBox cast_device_list;
    private Gtk.Button cast_discover_button;
    private Gtk.Label cast_status_label;
    private Gtk.Button cast_launch_button;
    private Gtk.Button cast_stop_button;
    private Gtk.Button cast_local_button;
    private string cast_device_signature = "";

    public MainView (Gtk.Application app) {
        Object (application: app);
    }

    public void build_ui (Elmish.Dispatch<Gradio.Message> dispatch, Gradio.AppModel model) {
        this.dispatch = dispatch;

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
            if (syncing_sort || app_model == null)
                return;
            dispatch (new SetLibrarySortMessage (app_model.config.library_sort,
                sort_descending_switch.active));
        });
        header.pack_end (sort_button);

        // The button opens the cast popover, which is also where the volume
        // lives: a speaker icon says both, and it tracks the current level.
        cast_button = new Gtk.MenuButton () {
            icon_name = volume_icon_name (model.config.volume),
            tooltip_text = _("Cast to a device")
        };
        var cast_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
            margin_top = 8,
            margin_bottom = 8,
            margin_start = 8,
            margin_end = 8
        };
        cast_volume_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8) {
            tooltip_text = _("Local volume")
        };
        cast_volume_icon = new Gtk.Image.from_icon_name (
            "audio-volume-high-symbolic");
        cast_volume_row.append (cast_volume_icon);
        cast_volume_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL,
            0.0, 1.0, 0.01);
        cast_volume_scale.set_draw_value (false);
        cast_volume_scale.set_hexpand (true);
        cast_volume_scale.set_value (model.config.volume);
        cast_volume_scale.value_changed.connect (() => {
            if (!updating_cast_volume)
                dispatch (new SetVolumeMessage (cast_volume_scale.get_value ()));
        });
        cast_volume_row.append (cast_volume_scale);
        // A fixed-width value keeps the slider from resizing while dragging.
        cast_volume_value = new Gtk.Label (volume_percent_text (model.config.volume)) {
            xalign = 1.0f,
            width_chars = 4
        };
        cast_volume_value.add_css_class ("dim-label");
        cast_volume_row.append (cast_volume_value);
        cast_box.append (cast_volume_row);
        cast_box.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        cast_discover_button = new Gtk.Button.with_label (_("Discover devices"));
        cast_discover_button.clicked.connect (() => dispatch (new DiscoverCastDevicesMessage ()));
        cast_box.append (cast_discover_button);
        cast_device_list = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.SINGLE
        };
        cast_device_list.row_selected.connect ((row) => {
            if (row == null || app_model == null)
                return;
            var device = (Gradio.CastDevice) row.get_data<Gradio.CastDevice> ("device");
            if (device != null)
                dispatch (new SelectCastDeviceMessage (device.id, device.name,
                    device.host, device.port));
        });
        cast_box.append (new Gtk.ScrolledWindow () {
            child = cast_device_list,
            min_content_height = 120,
            hexpand = true
        });
        cast_status_label = new Gtk.Label ("") { xalign = 0, wrap = true };
        cast_box.append (cast_status_label);
        cast_launch_button = new Gtk.Button.with_label (_("Cast current stream"));
        cast_launch_button.clicked.connect (() => dispatch (new CastToSelectedMessage ()));
        cast_stop_button = new Gtk.Button.with_label (_("Stop casting"));
        cast_stop_button.clicked.connect (() => dispatch (new StopCastMessage ()));
        cast_local_button = new Gtk.Button.with_label (_("Play on this computer"));
        cast_local_button.clicked.connect (() => dispatch (new PlayLocalMessage ()));
        cast_box.append (cast_launch_button);
        cast_box.append (cast_stop_button);
        cast_box.append (cast_local_button);
        var cast_popover = new Gtk.Popover () { child = cast_box };
        cast_popover.notify["visible"].connect (() => {
            if (!cast_popover.visible || app_model == null)
                return;
            if (app_model.cast_devices.length == 0 &&
                    app_model.cast_status != CastStatus.DISCOVERING)
                dispatch (new DiscoverCastDevicesMessage ());
        });
        cast_button.set_popover (cast_popover);
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
        stack.add_named (build_add_page (model), "add");

        player_bar = new Gradio.PlayerBar (dispatch);

        player_area = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        player_area.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        player_area.append (player_bar);

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
        update (new Gradio.SetViewMessage (model.view), model);
    }

    private void apply_player_placement (bool header_mode) {
        if (placement_initialized && header_mode == player_in_header_active)
            return;
        placement_initialized = true;
        player_in_header_active = header_mode;

        player_bar.unparent ();
        if (header_mode) {
            header.set_title_widget (empty_title);
            header_text_area.visible = true;
            header_controls_area.visible = true;
            player_area.visible = false;
            player_bar.set_compact (true);
            player_bar.place_in_header (header_text_area, header_controls_area);
        } else {
            header.set_title_widget (title_box);
            header_text_area.visible = false;
            header_controls_area.visible = false;
            player_area.visible = true;
            player_bar.set_compact (false);
            player_bar.restore_to_bar ();
            player_area.append (player_bar);
        }
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

        box.append (filters_row);

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

        search_list_box = new Gradio.StationList (dispatch, StationListMode.BROWSE);
        var scroll = new Gtk.ScrolledWindow () {
            child = search_list_box,
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
        discover_popular_list = new Gradio.StationList (dispatch, StationListMode.BROWSE);
        discover_content.append (discover_popular_list);

        var new_label = new Gtk.Label (_("New stations")) {
            halign = Gtk.Align.START,
            margin_top = 12
        };
        new_label.add_css_class ("title-4");
        discover_content.append (new_label);
        discover_new_list = new Gradio.StationList (dispatch, StationListMode.BROWSE);
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

        box.append (add_stack);
        sync_filter_pickers (model);
        return box;
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

    private static string volume_icon_name (double volume) {
        if (volume <= 0.0)
            return "audio-volume-muted-symbolic";
        if (volume < 0.33)
            return "audio-volume-low-symbolic";
        if (volume < 0.66)
            return "audio-volume-medium-symbolic";
        return "audio-volume-high-symbolic";
    }

    private static string volume_percent_text (double volume) {
        // No libm dependency. The config clamps the level, so this only guards
        // a hand-set value from printing "140%".
        double clamped = volume.clamp (0.0, 1.0);
        return "%d%%".printf ((int) (clamped * 100 + 0.5));
    }

    private void update_cast_ui (Gradio.AppModel model) {
        if (cast_device_list == null)
            return;
        var selected_id = model.cast_device_id;
        // rebuild rows only when the device list changed
        var signature = "%u:%s".printf (model.cast_devices.length, selected_id ?? "");
        if (signature != cast_device_signature) {
            cast_device_signature = signature;
            while (cast_device_list.get_first_child () != null)
                cast_device_list.remove (cast_device_list.get_first_child ());
            foreach (var device in model.cast_devices) {
                var row = new Gtk.ListBoxRow () { selectable = true };
                row.set_data ("device", device);
                row.child = new Gtk.Label (device.name) {
                    xalign = 0,
                    margin_top = 4,
                    margin_bottom = 4,
                    margin_start = 6
                };
                cast_device_list.append (row);
            }
        }
        switch (model.cast_status) {
            case CastStatus.IDLE:
                cast_status_label.label = _("Not casting");
                break;
            case CastStatus.DISCOVERING:
                cast_status_label.label = _("Discovering…");
                break;
            case CastStatus.READY:
                cast_status_label.label = model.cast_device_name != null
                    ? _("Ready to cast to %s").printf (model.cast_device_name)
                    : _("Ready to cast");
                break;
            case CastStatus.CONNECTING:
                cast_status_label.label = _("Connecting…");
                break;
            case CastStatus.PLAYING:
                cast_status_label.label = model.cast_device_name != null
                    ? _("Casting to %s").printf (model.cast_device_name)
                    : _("Casting");
                break;
            case CastStatus.BUFFERING:
                cast_status_label.label = _("Buffering…");
                break;
            case CastStatus.PAUSED:
                cast_status_label.label = _("Paused on cast device");
                break;
            case CastStatus.STOPPED:
                cast_status_label.label = _("Stopped");
                break;
            case CastStatus.FAILED:
                cast_status_label.label = model.cast_error;
                break;
            case CastStatus.LOST:
                cast_status_label.label = model.cast_error != ""
                    ? model.cast_error : _("Cast connection lost");
                break;
        }
        if (model.cast_reconnecting)
            cast_status_label.label = _("Reconnecting…");
        if (model.cast_remote_label != "" && !model.cast_is_active () &&
                !model.cast_reconnecting)
            cast_status_label.label = model.cast_remote_label;
        string cast_tooltip = _("Cast to a device");
        if (model.cast_reconnecting)
            cast_tooltip = _("Reconnecting…");
        else if (model.cast_status == CastStatus.PLAYING && model.cast_device_name != null)
            cast_tooltip = _("Casting to %s").printf (model.cast_device_name);
        else if (model.cast_status == CastStatus.BUFFERING && model.cast_device_name != null)
            cast_tooltip = _("Buffering on %s").printf (model.cast_device_name);
        else if (model.cast_status == CastStatus.PAUSED && model.cast_device_name != null)
            cast_tooltip = _("Paused on %s").printf (model.cast_device_name);
        else if (model.cast_status == CastStatus.LOST)
            cast_tooltip = _("Cast connection lost");
        cast_button.tooltip_text = cast_tooltip;
        if (model.cast_is_active ())
            cast_button.add_css_class ("cast-active");
        else
            cast_button.remove_css_class ("cast-active");
        bool can_change_device = !(model.cast_is_active () || model.cast_attached);
        cast_discover_button.sensitive = can_change_device;
        cast_device_list.sensitive = can_change_device;
        cast_discover_button.tooltip_text = can_change_device
            ? _("Discover cast devices")
            : model.cast_reconnecting
                ? _("Reconnecting…")
                : _("Stop casting to change device");
        cast_button.icon_name = volume_icon_name (model.config.volume);
        cast_volume_icon.icon_name = volume_icon_name (model.config.volume);
        cast_volume_value.label = volume_percent_text (model.config.volume);
        bool casting = model.playback_target == PlaybackTarget.CAST &&
            model.cast_attached && !model.cast_reconnecting;
        updating_cast_volume = true;
        if (cast_volume_scale.get_value () != model.config.volume)
            cast_volume_scale.set_value (model.config.volume);
        updating_cast_volume = false;
        cast_volume_row.tooltip_text = casting
            ? _("Volume (local and cast)") : _("Local volume");
        // Starting a new cast must stay possible after a loss even though the
        // output is still CAST: only a live session disables it.
        cast_launch_button.sensitive = !model.cast_is_active () &&
            model.cast_device_id != null && model.current_stream_url != "";
        cast_stop_button.sensitive = model.playback_target == PlaybackTarget.CAST &&
            !model.cast_reconnecting;
        cast_local_button.sensitive = model.playback_target == PlaybackTarget.CAST &&
            !model.cast_reconnecting;
    }

    public void update (Gradio.Message msg, Gradio.AppModel model) {
        app_model = model;

        bool adding = model.view == ViewMode.ADD_STATION;
        stack.set_visible_child_name (adding ? "add" : "library");
        add_button.visible = !adding;
        back_button.visible = adding;
        apply_player_placement (model.config.player_in_header);
        update_cast_ui (model);
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

        library_page.update (model);

        discover_popular_list.update (model.discover_popular, model);
        discover_new_list.update (model.discover_new, model);

        var results = StationSort.sort_search (model.search_results, model.config.search_sort);
        search_list_box.update (results, model);

        bool discover_mode = adding && model.search_query == "" &&
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
                        model.discover_popular.length == 0 && model.discover_new.length == 0;
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

        player_bar.update (model);

        status_label.label = model.status_message;
        status_bar.visible = model.config.show_status_bar && model.status_message != "";
    }
}
