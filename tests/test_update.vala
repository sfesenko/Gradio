// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Sergii Fesenko

// Model behavior for the counter: dispatch messages, assert model state.
using App;

AppModel make_model () {
    return new AppModel ();
}

void test_increment () {
    var model = make_model ();

    updateModel (new IncrementMessage (), model);

    assert (model.count == 1);
}

void test_increment_twice () {
    var model = make_model ();

    updateModel (new IncrementMessage (), model);
    updateModel (new IncrementMessage (), model);

    assert (model.count == 2);
}

void test_reset () {
    var model = make_model ();

    updateModel (new IncrementMessage (), model);
    updateModel (new IncrementMessage (), model);
    updateModel (new ResetMessage (), model);

    assert (model.count == 0);
}

void test_update_returns_no_cmd () {
    var model = make_model ();

    var cmd = updateModel (new IncrementMessage (), model);

    assert (cmd == null);
}

void test_plain_message_is_as_type_check () {
    // Plain classes support is/as — the type-safe way to read payloads.
    App.Message msg = new IncrementMessage ();
    var inc = msg as IncrementMessage;
    assert (inc != null);
    assert ((msg is ResetMessage) == false);
}

int main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/update/increment", test_increment);
    Test.add_func ("/update/increment_twice", test_increment_twice);
    Test.add_func ("/update/reset", test_reset);
    Test.add_func ("/update/returns_no_cmd", test_update_returns_no_cmd);
    Test.add_func ("/update/plain_message_is_as", test_plain_message_is_as_type_check);

    return Test.run ();
}
