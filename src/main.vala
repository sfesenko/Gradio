// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Sergii Fesenko

using Gradio;

int main (string[] args) {
    GLib.Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
    GLib.Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
    GLib.Intl.textdomain (GETTEXT_PACKAGE);

    var app = new Gtk.Application (
        "de.haeckerfelix.gradio",
        ApplicationFlags.DEFAULT_FLAGS
    );

    var program = new Elmish.ElmishProgram<Gradio.Message, Gradio.AppModel, Gradio.MainView> (
        new Gradio.AppModel (),
        (dispatch, model) => {
            var view = new Gradio.MainView (app);
            view.build_ui (dispatch, model);
            view.present ();
            return view;
        },
        updateModel,
        (msg, model, view) => view.update (msg, model)
    );

    var quit_action = new GLib.SimpleAction ("quit", null);
    quit_action.activate.connect ((parameter) => app.quit ());
    app.add_action (quit_action);

    bool started = false;
    app.activate.connect (() => {
        if (!started) {
            started = true;
            program.start ();
        }
    });

    return app.run (args);
}
