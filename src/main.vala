// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Sergii Fesenko

using Gradio;

int main (string[] args) {
    Gst.init (ref args);

    GLib.Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
    GLib.Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
    GLib.Intl.textdomain (GETTEXT_PACKAGE);

    Gradio.AppConfig config;
    string? load_error = null;
    bool read_only = false;
    try {
        config = Gradio.AppConfig.load (Gradio.AppConfig.default_path ());
    } catch (Gradio.ConfigError e) {
        config = new Gradio.AppConfig ();
        load_error = e.message;
        read_only = true;
    } catch (GLib.Error e) {
        config = new Gradio.AppConfig ();
        load_error = e.message;
    }

    var runtime = new Gradio.AppRuntime (config, load_error != null && !read_only, read_only);
    var model = new Gradio.AppModel (config);
    if (load_error != null)
        model.status_message = load_error;

    var app = new Gtk.Application (
        "io.github.sfesenko.gradio",
        ApplicationFlags.DEFAULT_FLAGS
    );
    runtime.set_application (app);

    Gradio.MprisServer? mpris = null;

    var program = new Elmish.ElmishProgram<Gradio.Message, Gradio.AppModel, Gradio.MainView> (
        model,
        (dispatch, current_model) => {
            runtime.attach (dispatch);
            var view = new Gradio.MainView (app);
            view.build_ui (dispatch, current_model);
            view.present ();

            mpris = new Gradio.MprisServer (dispatch, app);
            mpris.register_async.begin ((obj, res) => {
                try {
                    mpris.register_async.end (res);
                } catch (GLib.Error e) {
                }
                mpris.update (current_model);
            });
            mpris.update (current_model);

            return view;
        },
        (msg, current_model) => updateModel (msg, current_model, runtime),
        (msg, current_model, view) => {
            view.update (msg, current_model);
            if (mpris != null)
                mpris.update (current_model);
        }
    );

    bool started = false;

    var quit_action = new GLib.SimpleAction ("quit", null);
    quit_action.activate.connect ((parameter) => app.quit ());
    app.add_action (quit_action);

    var raise_action = new GLib.SimpleAction ("raise", null);
    raise_action.activate.connect ((parameter) => {
        unowned GLib.List<Gtk.Window> windows = app.get_windows ();
        if (windows != null) {
            var window = windows.data;
            window.set_visible (true);
            window.present ();
            if (started)
                program.dispatch_message (new Gradio.WindowRaisedMessage ());
        }
    });
    app.add_action (raise_action);

    var hide_action = new GLib.SimpleAction ("hide-window", null);
    hide_action.activate.connect ((parameter) => {
        unowned GLib.List<Gtk.Window> windows = app.get_windows ();
        if (windows != null)
            windows.data.set_visible (false);
    });
    app.add_action (hide_action);

    var about_action = new GLib.SimpleAction ("about", null);
    about_action.activate.connect ((parameter) => {
        var about = new Gtk.AboutDialog ();
        about.set_program_name (_("Gradio"));
        about.set_version (VERSION);
        about.set_logo_icon_name ("io.github.sfesenko.gradio");
        about.set_license_type (Gtk.License.GPL_3_0);
        about.set_comments (_("Listen to internet radio stations."));
        about.set_website ("https://github.com/sfesenko/Gradio");
        about.set_copyright ("© 2016–2019 Felix Häcker\n© 2026 Sergii Fesenko");
        about.set_authors ({ "Felix Häcker", "Sergii Fesenko" });
        about.present ();
    });
    app.add_action (about_action);

    string[] add_accels = { "<Control>f" };
    string[] library_accels = { "<Control>l" };
    string[] toggle_accels = { "<Control>space" };
    string[] details_accels = { "<Control>i" };
    string[] quit_accels = { "<Control>q" };
    app.set_accels_for_action ("win.add-station", add_accels);
    app.set_accels_for_action ("win.library", library_accels);
    app.set_accels_for_action ("win.toggle-play", toggle_accels);
    app.set_accels_for_action ("win.details", details_accels);
    app.set_accels_for_action ("app.quit", quit_accels);

    app.shutdown.connect (() => runtime.shutdown ());

    var search_provider = new Gradio.SearchProvider (config);
    search_provider.station_activated.connect ((station) => {
        app.activate ();
        program.dispatch_message (new Gradio.PlayStationMessage (station));
    });
    search_provider.search_launched.connect (() => {
        app.activate ();
    });

    app.startup.connect (() => {
        var connection = app.get_dbus_connection ();
        if (connection != null)
            search_provider.register (connection);
    });

    app.activate.connect (() => {
        if (!started) {
            started = true;
            program.start ();
            program.dispatch_message (new Gradio.RequestFaviconsMessage ());
            program.dispatch_message (new Gradio.RefreshLibraryMessage ());
            program.dispatch_message (new Gradio.DiscoverServerMessage ());
            program.dispatch_message (new Gradio.RequestFilterOptionsMessage ());
            program.dispatch_message (new Gradio.RestoreLastStationMessage ());
        } else {
            unowned GLib.List<Gtk.Window> windows = app.get_windows ();
            if (windows != null) {
                var window = windows.data;
                window.set_visible (true);
                window.present ();
            }
            program.dispatch_message (new Gradio.WindowRaisedMessage ());
        }
    });

    return app.run (args);
}
