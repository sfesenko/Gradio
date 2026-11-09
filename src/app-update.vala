// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Sergii Fesenko

using App;

// The pure half of the loop: given a message and the model, mutate the model
// and return a Cmd for any side effect.
// Rules:
//   • No IO here. File writes, dialogs, playback — all go into returned Cmds.
//   • No GTK here. This file is compiled into the testable core library.
public Elmish.Cmd<App.Message>? updateModel (App.Message msg, AppModel model) {
    Elmish.Cmd<App.Message>? cmd = null;
    switch (msg.kind) {
        case MessageKind.INCREMENT:
            model.count++;
            break;
        case MessageKind.RESET:
            model.count = 0;
            break;
        default:
            break;
    }
    return cmd;
}
