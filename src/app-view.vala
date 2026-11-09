// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Sergii Fesenko

// The imperative half of the loop: the view never owns state or decides
// behavior. Widget signals become messages (dispatch); update() reflects the
// model back onto widgets.
//
// Half-elmish: this is the ONLY place that deviates from full Elm — the view
// is a mutable widget tree instead of a pure render function. Everything else
// (model, messages, update) is full elmish.
public class Gradio.MainView : Gtk.ApplicationWindow {
    private Elmish.Dispatch<Gradio.Message> dispatch;
    private Gtk.Stack stack;
    private Gtk.ToggleButton play_button;
    private Gtk.Label status_label;
    private bool updating = false;

    public MainView (Gtk.Application app) {
        Object (application: app);
    }

    public void build_ui (Elmish.Dispatch<Gradio.Message> dispatch, Gradio.AppModel model) {
        this.dispatch = dispatch;

        set_title (_("Gradio"));
        set_default_size (900, 600);

        var header = new Gtk.HeaderBar ();

        stack = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.CROSSFADE,
            hexpand = true,
            vexpand = true
        };
        stack.add_titled (build_placeholder (_("Library"),
                _("Your saved radio stations will appear here.")), "library", _("Library"));
        stack.add_titled (build_placeholder (_("Discover"),
                _("Search and browse internet radio stations.")), "search", _("Discover"));
        stack.add_titled (build_placeholder (_("Collections"),
                _("Group stations into collections.")), "collections", _("Collections"));
        stack.add_titled (build_placeholder (_("Settings"),
                _("Playback, appearance and library settings.")), "settings", _("Settings"));

        var switcher = new Gtk.StackSwitcher () { stack = stack };
        header.set_title_widget (switcher);

        var menu_button = new Gtk.MenuButton () {
            icon_name = "open-menu-symbolic",
            tooltip_text = _("Menu")
        };
        var menu = new GLib.Menu ();
        menu.append (_("Library"), "win.library");
        menu.append (_("Discover"), "win.search");
        menu.append (_("Collections"), "win.collections");
        menu.append (_("Settings"), "win.settings");
        menu.append (_("Quit"), "app.quit");
        menu_button.set_menu_model (menu);
        header.pack_end (menu_button);

        set_titlebar (header);

        add_action (create_page_action ("library", PageMode.LIBRARY));
        add_action (create_page_action ("search", PageMode.SEARCH));
        add_action (create_page_action ("collections", PageMode.COLLECTIONS));
        add_action (create_page_action ("settings", PageMode.SETTINGS));

        var bottom = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            margin_top = 8,
            margin_bottom = 8,
            margin_start = 12,
            margin_end = 12
        };

        play_button = new Gtk.ToggleButton () {
            icon_name = "media-playback-start-symbolic",
            tooltip_text = _("Play")
        };
        play_button.toggled.connect (() => {
            if (!updating) {
                dispatch (new TogglePlayMessage ());
            }
        });
        bottom.append (play_button);

        status_label = new Gtk.Label (model.status_message) {
            hexpand = true,
            halign = Gtk.Align.START
        };
        bottom.append (status_label);

        var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        root.append (stack);
        root.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        root.append (bottom);

        set_child (root);

        stack.notify["visible-child-name"].connect (() => {
            if (updating) {
                return;
            }
            var name = stack.get_visible_child_name ();
            if (name == null) {
                return;
            }
            switch (name) {
                case "library":
                    dispatch (new SetPageMessage (PageMode.LIBRARY));
                    break;
                case "search":
                    dispatch (new SetPageMessage (PageMode.SEARCH));
                    break;
                case "collections":
                    dispatch (new SetPageMessage (PageMode.COLLECTIONS));
                    break;
                case "settings":
                    dispatch (new SetPageMessage (PageMode.SETTINGS));
                    break;
                default:
                    break;
            }
        });

        update (new SetPageMessage (model.page), model);
    }

    private GLib.SimpleAction create_page_action (string name, PageMode page) {
        var action = new GLib.SimpleAction (name, null);
        action.activate.connect ((parameter) => dispatch (new SetPageMessage (page)));
        return action;
    }

    private Gtk.Widget build_placeholder (string title, string subtitle) {
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8) {
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER,
            margin_top = 24,
            margin_bottom = 24,
            margin_start = 24,
            margin_end = 24
        };

        var title_label = new Gtk.Label (title);
        title_label.add_css_class ("title-1");

        var subtitle_label = new Gtk.Label (subtitle);
        subtitle_label.add_css_class ("dim-label");
        subtitle_label.wrap = true;

        box.append (title_label);
        box.append (subtitle_label);
        return box;
    }

    public void update (Gradio.Message msg, Gradio.AppModel model) {
        updating = true;

        switch (model.page) {
            case PageMode.LIBRARY:
                stack.set_visible_child_name ("library");
                break;
            case PageMode.SEARCH:
                stack.set_visible_child_name ("search");
                break;
            case PageMode.COLLECTIONS:
                stack.set_visible_child_name ("collections");
                break;
            case PageMode.SETTINGS:
                stack.set_visible_child_name ("settings");
                break;
        }

        play_button.active = model.playing;
        play_button.icon_name = model.playing
            ? "media-playback-pause-symbolic"
            : "media-playback-start-symbolic";
        play_button.tooltip_text = model.playing ? _("Pause") : _("Play");
        status_label.label = model.status_message;

        updating = false;
    }
}
