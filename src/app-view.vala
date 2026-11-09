// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Sergii Fesenko

// The imperative half of the loop: the view never owns state or decides
// behavior. Widget signals become messages (dispatch); update() reflects the
// model back onto widgets.
//
// Half-elmish: this is the ONLY place that deviates from full Elm — the view
// is a mutable widget tree instead of a pure render function. Everything else
// (model, messages, update) is full elmish.
public class App.CounterView : Gtk.ApplicationWindow {
    private Elmish.Dispatch<App.Message> dispatch;
    private Gtk.Label label;

    public CounterView (Gtk.Application app) {
        Object (application: app);
    }

    public void build_ui (Elmish.Dispatch<App.Message> dispatch, AppModel model) {
        this.dispatch = dispatch;

        set_title (_("Elmish Counter"));
        set_default_size (360, 200);

        label = new Gtk.Label (model.count.to_string ()) { margin_top = 24 };
        label.add_css_class ("title-1");

        var inc_button = new Gtk.Button.with_label (_("Increment"));
        inc_button.clicked.connect (() => dispatch (new IncrementMessage ()));
        var reset_button = new Gtk.Button.with_label (_("Reset"));
        reset_button.clicked.connect (() => dispatch (new ResetMessage ()));

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER,
            margin_top = 12,
            margin_bottom = 12,
            margin_start = 12,
            margin_end = 12
        };
        box.append (label);
        box.append (inc_button);
        box.append (reset_button);

        set_child (box);
    }

    public void update (App.Message msg, AppModel model) {
        switch (msg.kind) {
            case MessageKind.INCREMENT:
            case MessageKind.RESET:
                label.label = model.count.to_string ();
                break;
            default:
                break;
        }
    }
}
