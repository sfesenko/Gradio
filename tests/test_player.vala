// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Sergii Fesenko

void test_initial_state () {
    var player = new Gradio.Player ();
    assert (player.volume == 0.8);
}

void test_volume_clamps () {
    var player = new Gradio.Player ();
    player.set_volume (-1.0);
    assert (player.volume == 0.0);
    player.set_volume (2.0);
    assert (player.volume == 1.0);
}

void test_play_empty_url_emits_error () {
    var player = new Gradio.Player ();
    string? error = null;
    player.playback_error.connect ((message) => { error = message; });

    var station = new Gradio.RadioStation ();
    station.url = "";
    player.play (station);

    assert (error != null);
    assert (error != "");
}

void test_stop_without_station () {
    var player = new Gradio.Player ();
    player.stop ();
    assert (player.volume == 0.8);
}

int main (string[] args) {
    Gst.init (ref args);
    Test.init (ref args);

    Test.add_func ("/player/initial_state", test_initial_state);
    Test.add_func ("/player/volume_clamps", test_volume_clamps);
    Test.add_func ("/player/play_empty_url", test_play_empty_url_emits_error);
    Test.add_func ("/player/stop_without_station", test_stop_without_station);

    return Test.run ();
}
