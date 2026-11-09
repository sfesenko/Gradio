// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Sergii Fesenko

using App;

int main (string[] args) {
    GLib.Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
    GLib.Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
    GLib.Intl.textdomain (GETTEXT_PACKAGE);

    var app = new Gtk.Application (
        "com.example.half_elmish_template",
        ApplicationFlags.DEFAULT_FLAGS
    );

    var program = new Elmish.ElmishProgram<App.Message, AppModel, CounterView> (
        new AppModel (),
        (dispatch, model) => {
            var view = new CounterView (app);
            view.build_ui (dispatch, model);
            view.present ();
            return view;
        },
        updateModel,
        (msg, model, view) => view.update (msg, model)
    );

    app.activate.connect (() => {
        program.start ();
    });

    return app.run (args);
}
