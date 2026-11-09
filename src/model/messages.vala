// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Sergii Fesenko

// ── Discriminator enum (drives the switch dispatch) ──
// Keep the enum entries in sync with the message classes below.
public enum App.MessageKind {
    INCREMENT,
    RESET
}

// ── Base class ──
// Messages are PLAIN classes: neither GLib.Object nor [Compact]. Valac
// compiles them as GType-registered, atomically ref-counted classes — cheap
// to create, `is`/`as` type-safe, and valid generic type arguments for the
// elmish core. The `kind` enum is the fast dispatch discriminator; `is`/`as`
// is available as the type-safe check when payloads differ.
//
// Why not compact classes or structs? Both are rejected by valac as generic
// type arguments of the core (compact: "duplicating instance" — no ref or
// copy machinery for type-erased storage; structs: "use `?` to box value
// types"). Verified empirically — see docs/ARCHITECTURE.md "Messages".
public abstract class App.Message {
    public abstract MessageKind kind { get; }
}

// ── Messages ──

public class App.IncrementMessage : App.Message {
    public override MessageKind kind { get { return MessageKind.INCREMENT; } }
}

public class App.ResetMessage : App.Message {
    public override MessageKind kind { get { return MessageKind.RESET; } }
}

// ── Model ──
// Application state. Also a plain class: mutated only from updateModel.
public class App.AppModel {
    public int count = 0;
}
