// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Sergii Fesenko

// Model behavior: dispatch messages, assert model state.
using Gradio;

AppModel make_model () {
    return new AppModel ();
}

void test_defaults () {
    var model = make_model ();

    assert (model.page == PageMode.LIBRARY);
    assert (model.playing == false);
}

void test_set_page () {
    var model = make_model ();

    updateModel (new SetPageMessage (PageMode.SEARCH), model);

    assert (model.page == PageMode.SEARCH);
}

void test_set_page_twice () {
    var model = make_model ();

    updateModel (new SetPageMessage (PageMode.SETTINGS), model);
    updateModel (new SetPageMessage (PageMode.COLLECTIONS), model);

    assert (model.page == PageMode.COLLECTIONS);
}

void test_toggle_play () {
    var model = make_model ();

    updateModel (new TogglePlayMessage (), model);
    assert (model.playing == true);
    assert (model.status_message == _("Playing"));

    updateModel (new TogglePlayMessage (), model);
    assert (model.playing == false);
    assert (model.status_message == _("Paused"));
}

void test_update_returns_no_cmd () {
    var model = make_model ();

    var cmd = updateModel (new SetPageMessage (PageMode.SEARCH), model);

    assert (cmd == null);
}

void test_plain_message_is_as_type_check () {
    // Plain classes support is/as — the type-safe way to read payloads.
    Gradio.Message msg = new SetPageMessage (PageMode.SEARCH);
    var set_page = msg as SetPageMessage;
    assert (set_page != null);
    assert (set_page.page == PageMode.SEARCH);
    assert ((msg is TogglePlayMessage) == false);
}

int main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/update/defaults", test_defaults);
    Test.add_func ("/update/set_page", test_set_page);
    Test.add_func ("/update/set_page_twice", test_set_page_twice);
    Test.add_func ("/update/toggle_play", test_toggle_play);
    Test.add_func ("/update/returns_no_cmd", test_update_returns_no_cmd);
    Test.add_func ("/update/plain_message_is_as", test_plain_message_is_as_type_check);

    return Test.run ();
}
