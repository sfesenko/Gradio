// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Sergii Fesenko

using Gradio;

class RecordingCommands : Gradio.Commands {
    public int search_calls = 0;
    public int play_calls = 0;
    public int stop_calls = 0;
    public int set_volume_calls = 0;
    public int save_calls = 0;
    public string last_query = "";
    public uint last_generation = 0;
    public double last_volume = -1;

    private Elmish.Cmd<Gradio.Message> dummy () {
        return new Elmish.Cmd<Gradio.Message> ((dispatch) => {});
    }

    public override Elmish.Cmd<Gradio.Message>? search (string query, uint generation) {
        search_calls++;
        last_query = query;
        last_generation = generation;
        return dummy ();
    }

    public override Elmish.Cmd<Gradio.Message>? play (RadioStation station) {
        play_calls++;
        return dummy ();
    }

    public override Elmish.Cmd<Gradio.Message>? stop () {
        stop_calls++;
        return dummy ();
    }

    public override Elmish.Cmd<Gradio.Message>? set_volume (double volume) {
        set_volume_calls++;
        last_volume = volume;
        return dummy ();
    }

    public override Elmish.Cmd<Gradio.Message>? save_config () {
        save_calls++;
        return dummy ();
    }
}

AppModel make_model () {
    return new AppModel (new AppConfig ("/tmp/gradio-test-config.json"));
}

RadioStation make_station (string id) {
    var station = new RadioStation ();
    station.id = id;
    station.name = id;
    station.url = "https://example.test/" + id;
    return station;
}

void test_defaults () {
    var model = make_model ();
    assert (model.view == ViewMode.LIBRARY);
    assert (model.current_station == null);
    assert (model.playing == false);
    assert (model.search_results.length == 0);
}

void test_set_view () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    model.search_query = "jazz";
    model.search_results.add (make_station ("u1"));
    model.search_error = "old error";
    model.searching = true;
    model.details_visible = true;

    updateModel (new SetViewMessage (ViewMode.ADD_STATION), model, commands);
    assert (model.view == ViewMode.ADD_STATION);
    assert (model.search_query == "");
    assert (model.search_results.length == 0);
    assert (model.search_error == null);
    assert (model.searching == false);
    assert (model.details_visible == false);

    model.details_visible = true;
    updateModel (new SetViewMessage (ViewMode.LIBRARY), model, commands);
    assert (model.view == ViewMode.LIBRARY);
    assert (model.details_visible == false);
}

void test_search_requested_empty () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.search_results.add (make_station ("u1"));
    model.searching = true;

    var cmd = updateModel (new SearchRequestedMessage ("   "), model, commands);
    assert (cmd == null);
    assert (model.search_results.length == 0);
    assert (model.searching == false);
    assert (commands.search_calls == 0);
}

void test_search_requested () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    var cmd = updateModel (new SearchRequestedMessage ("  jazz  "), model, commands);
    assert (cmd != null);
    assert (model.searching == true);
    assert (model.search_query == "jazz");
    assert (model.search_generation == 1);
    assert (commands.search_calls == 1);
    assert (commands.last_query == "jazz");
    assert (commands.last_generation == 1);
}

void test_search_results_current () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.search_generation = 3;
    model.searching = true;
    model.search_error = "old";

    var results = new GLib.GenericArray<RadioStation> ();
    results.add (make_station ("u1"));
    updateModel (new SearchResultsMessage (results, 3), model, commands);

    assert (model.search_results.length == 1);
    assert (model.searching == false);
    assert (model.search_error == null);
}

void test_search_results_stale () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.search_generation = 3;
    model.searching = true;

    var results = new GLib.GenericArray<RadioStation> ();
    results.add (make_station ("u1"));
    updateModel (new SearchResultsMessage (results, 2), model, commands);

    assert (model.search_results.length == 0);
    assert (model.searching == true);
}

void test_search_failed () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.search_generation = 2;
    model.searching = true;

    updateModel (new SearchFailedMessage ("offline", 2), model, commands);
    assert (model.search_error == "offline");
    assert (model.searching == false);

    updateModel (new SearchFailedMessage ("stale", 1), model, commands);
    assert (model.search_error == "offline");
}

void test_add_station () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    var cmd = updateModel (new AddStationMessage (make_station ("u1")), model, commands);
    assert (cmd != null);
    assert (model.config.stations.length == 1);
    assert (model.status_message == "Added u1");
    assert (commands.save_calls == 1);
}

void test_add_duplicate () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.config.add_station (make_station ("u1"));

    var cmd = updateModel (new AddStationMessage (make_station ("u1")), model, commands);
    assert (cmd == null);
    assert (model.config.stations.length == 1);
    assert (model.status_message == "Already in library");
    assert (commands.save_calls == 0);
}

void test_remove_station () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.config.add_station (make_station ("u1"));

    var cmd = updateModel (new RemoveStationMessage ("u1"), model, commands);
    assert (cmd != null);
    assert (model.config.stations.length == 0);
    assert (commands.save_calls == 1);
}

void test_remove_current_station () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var station = make_station ("u1");
    model.config.add_station (station);
    model.current_station = station;
    model.playing = true;
    model.details_visible = true;
    model.details_station = station;

    var cmd = updateModel (new RemoveStationMessage ("u1"), model, commands);
    assert (cmd != null);
    assert (model.current_station == null);
    assert (model.playing == false);
    assert (model.details_visible == false);
    assert (model.details_station == null);

    Elmish.Cmd.exec<Gradio.Message> ((message) => {}, cmd);
    assert (commands.stop_calls == 1);
    assert (commands.save_calls == 1);
}

void test_play_station () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var station = make_station ("u1");

    var cmd = updateModel (new PlayStationMessage (station), model, commands);
    assert (cmd != null);
    assert (model.current_station == station);
    assert (model.playing == true);
    assert (model.status_message == "Connecting…");
    assert (commands.play_calls == 1);
}

void test_toggle_play () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    assert (updateModel (new TogglePlayMessage (), model, commands) == null);
    assert (commands.play_calls == 0);
    assert (commands.stop_calls == 0);

    model.current_station = make_station ("u1");
    updateModel (new TogglePlayMessage (), model, commands);
    assert (model.playing == true);
    assert (commands.play_calls == 1);

    updateModel (new TogglePlayMessage (), model, commands);
    assert (model.playing == false);
    assert (commands.stop_calls == 1);
}

void test_player_state () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    updateModel (new PlayerStateChangedMessage (true), model, commands);
    assert (model.playing == true);
    assert (model.status_message == "Connected");

    updateModel (new PlayerStateChangedMessage (false), model, commands);
    assert (model.playing == false);
    assert (model.status_message == "Stopped");
}

void test_player_metadata () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    updateModel (new PlayerMetadataChangedMessage ("Track", 192), model, commands);
    assert (model.stream_title == "Track");
    assert (model.stream_bitrate == 192);
}

void test_player_error () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.playing = true;

    updateModel (new PlayerErrorMessage ("boom"), model, commands);
    assert (model.playing == false);
    assert (model.status_message == "boom");
}

void test_show_details () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var station = make_station ("u1");

    updateModel (new ShowDetailsMessage (station), model, commands);
    assert (model.details_visible == true);
    assert (model.details_station == station);

    model.details_visible = false;
    model.current_station = station;
    updateModel (new ShowDetailsMessage (null), model, commands);
    assert (model.details_visible == true);
    assert (model.details_station == station);
}

void test_hide_details () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.details_visible = true;
    model.details_station = make_station ("u1");

    updateModel (new HideDetailsMessage (), model, commands);
    assert (model.details_visible == false);
}

void test_set_volume_clamps () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    updateModel (new SetVolumeMessage (-0.5), model, commands);
    assert (model.config.volume == 0.0);
    assert (commands.last_volume == 0.0);

    updateModel (new SetVolumeMessage (1.5), model, commands);
    assert (model.config.volume == 1.0);
    assert (commands.last_volume == 1.0);
    assert (commands.set_volume_calls == 2);
}

void test_set_show_technical_info () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    updateModel (new SetShowTechnicalInfoMessage (true), model, commands);
    assert (model.config.show_technical_info == true);
    assert (commands.save_calls == 1);
}

void test_set_dark_theme () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    updateModel (new SetDarkThemeMessage (true), model, commands);
    assert (model.config.dark_theme == true);
    assert (commands.save_calls == 1);
}

void test_config_save_failed () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    updateModel (new ConfigSaveFailedMessage ("disk full"), model, commands);
    assert (model.status_message == "disk full");
}

int main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/update/defaults", test_defaults);
    Test.add_func ("/update/set_view", test_set_view);
    Test.add_func ("/update/search_requested_empty", test_search_requested_empty);
    Test.add_func ("/update/search_requested", test_search_requested);
    Test.add_func ("/update/search_results_current", test_search_results_current);
    Test.add_func ("/update/search_results_stale", test_search_results_stale);
    Test.add_func ("/update/search_failed", test_search_failed);
    Test.add_func ("/update/add_station", test_add_station);
    Test.add_func ("/update/add_duplicate", test_add_duplicate);
    Test.add_func ("/update/remove_station", test_remove_station);
    Test.add_func ("/update/remove_current_station", test_remove_current_station);
    Test.add_func ("/update/play_station", test_play_station);
    Test.add_func ("/update/toggle_play", test_toggle_play);
    Test.add_func ("/update/player_state", test_player_state);
    Test.add_func ("/update/player_metadata", test_player_metadata);
    Test.add_func ("/update/player_error", test_player_error);
    Test.add_func ("/update/show_details", test_show_details);
    Test.add_func ("/update/hide_details", test_hide_details);
    Test.add_func ("/update/set_volume_clamps", test_set_volume_clamps);
    Test.add_func ("/update/set_show_technical_info", test_set_show_technical_info);
    Test.add_func ("/update/set_dark_theme", test_set_dark_theme);
    Test.add_func ("/update/config_save_failed", test_config_save_failed);

    return Test.run ();
}
