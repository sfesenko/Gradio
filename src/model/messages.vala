// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Sergii Fesenko

// ── Discriminator enums ──
// Keep MessageKind entries in sync with the message classes below.
public enum Gradio.PageMode {
    LIBRARY,
    SEARCH,
    COLLECTIONS,
    SETTINGS
}

public enum Gradio.MessageKind {
    SET_PAGE,
    TOGGLE_PLAY
}

// ── Base class ──
// Messages are PLAIN classes: neither GLib.Object nor [Compact]. Valac
// compiles them as GType-registered, atomically ref-counted classes — cheap
// to create, `is`/`as` type-safe, and valid generic type arguments for the
// elmish core. The `kind` enum is the fast dispatch discriminator.
public abstract class Gradio.Message {
    public abstract MessageKind kind { get; }
}

// ── Messages ──

public class Gradio.SetPageMessage : Gradio.Message {
    public PageMode page;

    public SetPageMessage (PageMode page) {
        this.page = page;
    }

    public override MessageKind kind { get { return MessageKind.SET_PAGE; } }
}

public class Gradio.TogglePlayMessage : Gradio.Message {
    public override MessageKind kind { get { return MessageKind.TOGGLE_PLAY; } }
}

// ── Model ──
// Application state. Also a plain class: mutated only from updateModel.
public class Gradio.AppModel {
    public PageMode page = PageMode.LIBRARY;
    public bool playing = false;
    public string status_message = _("Ready");
}
