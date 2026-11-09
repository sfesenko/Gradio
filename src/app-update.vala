// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Sergii Fesenko

using Gradio;

// The pure half of the loop: given a message and the model, mutate the model
// and return a Cmd for any side effect.
// Rules:
//   • No IO here. File writes, dialogs, playback — all go into returned Cmds.
//   • No GTK here. This file is compiled into the testable core library.
public Elmish.Cmd<Gradio.Message>? updateModel (Gradio.Message msg, Gradio.AppModel model) {
    Elmish.Cmd<Gradio.Message>? cmd = null;
    switch (msg.kind) {
        case MessageKind.SET_PAGE:
            var set_page = msg as SetPageMessage;
            if (set_page != null) {
                model.page = set_page.page;
            }
            break;
        case MessageKind.TOGGLE_PLAY:
            model.playing = !model.playing;
            model.status_message = model.playing ? _("Playing") : _("Paused");
            break;
        default:
            break;
    }
    return cmd;
}
