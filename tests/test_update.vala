// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Sergii Fesenko

using Gradio;

class RecordingCommands : Gradio.Commands {
    public int search_calls = 0;
    public int play_calls = 0;
    public int stop_calls = 0;
    public int set_volume_calls = 0;
    public int save_calls = 0;
    public int favicon_calls = 0;
    public int clear_favicon_calls = 0;
    public int vote_calls = 0;
    public int notify_calls = 0;
    public int import_calls = 0;
    public int export_calls = 0;
    public string last_import_path = "";
    public string last_export_path = "";
    public int last_export_count = 0;
    public int playlist_calls = 0;
    public string last_playlist_path = "";
    public int last_playlist_count = 0;
    public int filter_option_calls = 0;
    public int refresh_calls = 0;
    public int last_refresh_count = 0;
    public string last_vote_id = "";
    public string last_notification = "";
    public string last_query = "";
    public uint last_generation = 0;
    public double last_volume = -1;
    public GLib.GenericArray<RadioStation> last_favicon_stations = new GLib.GenericArray<RadioStation> ();

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

    public override Elmish.Cmd<Gradio.Message>? load_favicons (GLib.GenericArray<RadioStation> stations) {
        favicon_calls++;
        last_favicon_stations = new GLib.GenericArray<RadioStation> ();
        for (uint i = 0; i < stations.length; i++)
            last_favicon_stations.add (stations.get (i));
        return dummy ();
    }

    public override Elmish.Cmd<Gradio.Message>? clear_favicon_cache () {
        clear_favicon_calls++;
        return dummy ();
    }

    public override Elmish.Cmd<Gradio.Message>? vote (string station_id) {
        vote_calls++;
        last_vote_id = station_id;
        return dummy ();
    }

    public override Elmish.Cmd<Gradio.Message>? notify_error (string message) {
        notify_calls++;
        last_notification = message;
        return dummy ();
    }

    public override Elmish.Cmd<Gradio.Message>? import_stations (string path) {
        import_calls++;
        last_import_path = path;
        return dummy ();
    }

    public override Elmish.Cmd<Gradio.Message>? export_stations (GLib.GenericArray<RadioStation> stations, string path) {
        export_calls++;
        last_export_path = path;
        last_export_count = (int) stations.length;
        return dummy ();
    }

    public override Elmish.Cmd<Gradio.Message>? export_playlist (GLib.GenericArray<RadioStation> stations, string path) {
        playlist_calls++;
        last_playlist_path = path;
        last_playlist_count = (int) stations.length;
        return dummy ();
    }

    public override Elmish.Cmd<Gradio.Message>? load_filter_options () {
        filter_option_calls++;
        return dummy ();
    }

    public override Elmish.Cmd<Gradio.Message>? refresh_library (GLib.GenericArray<RadioStation> stations) {
        refresh_calls++;
        last_refresh_count = (int) stations.length;
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
    station.favicon = "https://example.test/" + id + ".png";
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
    assert (model.search_active == false);
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
    assert (model.search_active == false);
    assert (commands.search_calls == 0);
}

void test_search_requested_blank_with_filter_browses () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.config.search_filters.country = "Ukraine";
    model.search_generation = 3;

    var cmd = updateModel (new SearchRequestedMessage ("   "), model, commands);

    assert (cmd != null);
    assert (model.search_active == true);
    assert (model.searching == true);
    assert (model.search_generation == 4);
    assert (commands.search_calls == 1);
    assert (commands.last_query == "");
    assert (commands.last_generation == 4);
}

void test_search_clear_invalidates_in_flight () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.search_generation = 1;
    model.searching = true;

    updateModel (new SearchRequestedMessage (""), model, commands);
    assert (model.search_generation == 2);
    assert (model.searching == false);

    var results = new GLib.GenericArray<RadioStation> ();
    results.add (make_station ("u1"));
    updateModel (new SearchResultsMessage (results, 1), model, commands);
    assert (model.search_results.length == 0);

    updateModel (new SearchFailedMessage ("late", 1), model, commands);
    assert (model.search_error == null);
}

void test_set_view_invalidates_in_flight () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.search_generation = 1;
    model.searching = true;

    updateModel (new SetViewMessage (ViewMode.ADD_STATION), model, commands);
    assert (model.search_generation == 2);
    assert (model.searching == false);

    var results = new GLib.GenericArray<RadioStation> ();
    results.add (make_station ("u1"));
    updateModel (new SearchResultsMessage (results, 1), model, commands);
    assert (model.search_results.length == 0);
}

void test_same_view_keeps_search () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.view = ViewMode.ADD_STATION;
    model.search_query = "jazz";
    model.search_results.add (make_station ("u1"));
    model.search_generation = 5;

    updateModel (new SetViewMessage (ViewMode.ADD_STATION), model, commands);
    assert (model.search_query == "jazz");
    assert (model.search_results.length == 1);
    assert (model.search_generation == 5);
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

void test_move_station_reorders_and_saves () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.config.add_station (make_station ("a"));
    model.config.add_station (make_station ("b"));
    model.config.add_station (make_station ("c"));

    updateModel (new MoveStationMessage ("a", "c", true), model, commands);

    assert (model.config.stations.get (0).id == "b");
    assert (model.config.stations.get (1).id == "c");
    assert (model.config.stations.get (2).id == "a");
    assert (commands.save_calls == 1);
}

void test_move_station_noop_does_not_save () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.config.add_station (make_station ("a"));
    model.config.add_station (make_station ("b"));

    updateModel (new MoveStationMessage ("a", "missing", true), model, commands);

    assert (model.config.stations.get (0).id == "a");
    assert (commands.save_calls == 0);
}

void test_vote_starts_command () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.config.add_station (make_station ("u1"));

    var cmd = updateModel (new VoteStationMessage ("u1"), model, commands);
    assert (cmd != null);
    assert (commands.vote_calls == 1);
    assert (commands.last_vote_id == "u1");
    assert (model.votes_pending.contains ("u1"));
    assert (!model.voted_ids.contains ("u1"));
}

void test_vote_unknown_station_is_ignored () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    var cmd = updateModel (new VoteStationMessage ("missing"), model, commands);
    assert (cmd == null);
    assert (commands.vote_calls == 0);
}

void test_vote_duplicate_is_ignored () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.config.add_station (make_station ("u1"));
    model.voted_ids.set ("u1", true);

    var cmd = updateModel (new VoteStationMessage ("u1"), model, commands);
    assert (cmd == null);
    assert (commands.vote_calls == 0);
}

void test_vote_success_marks_voted_and_updates_count () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var station = make_station ("u1");
    station.votes = 3;
    model.config.add_station (station);
    model.votes_pending.set ("u1", true);

    var updated = make_station ("u1");
    updated.votes = 4;
    var cmd = updateModel (new VoteSucceededMessage ("u1", updated), model, commands);

    assert (cmd == null);
    assert (model.voted_ids.contains ("u1"));
    assert (!model.votes_pending.contains ("u1"));
    assert (station.votes == 4);
    assert (model.status_message == "Thanks for voting");
}

void test_vote_success_without_station_increments_count () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var station = make_station ("u1");
    station.votes = 3;
    model.config.add_station (station);
    model.votes_pending.set ("u1", true);

    updateModel (new VoteSucceededMessage ("u1", null), model, commands);
    assert (station.votes == 4);
}

void test_vote_failure_reports_and_clears_pending () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.config.add_station (make_station ("u1"));
    model.votes_pending.set ("u1", true);

    updateModel (new VoteFailedMessage ("u1", "try later"), model, commands);
    assert (!model.votes_pending.contains ("u1"));
    assert (!model.voted_ids.contains ("u1"));
    assert (model.status_message == "try later");
}

void test_player_error_notifies () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    var cmd = updateModel (new PlayerErrorMessage ("boom"), model, commands);
    assert (cmd != null);
    assert (commands.notify_calls == 1);
    assert (commands.last_notification == "boom");
}

void test_import_stations_starts_command () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    var cmd = updateModel (new ImportStationsMessage ("/tmp/stations.json"), model, commands);
    assert (cmd != null);
    assert (commands.import_calls == 1);
    assert (commands.last_import_path == "/tmp/stations.json");
}

void test_import_success_merges_and_saves () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.config.add_station (make_station ("u1"));

    var incoming = new GLib.GenericArray<RadioStation> ();
    incoming.add (make_station ("u1"));
    incoming.add (make_station ("u2"));

    var cmd = updateModel (new StationsImportedMessage (incoming), model, commands);
    assert (cmd != null);
    assert (model.config.stations.length == 2);
    assert (model.status_message == "Imported 1 station, skipped 1");
    assert (commands.save_calls == 1);
}

void test_import_failure_reports_status () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    updateModel (new ImportFailedMessage ("bad file"), model, commands);
    assert (model.status_message == "bad file");
    assert (commands.save_calls == 0);
}

void test_export_starts_command () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.config.add_station (make_station ("u1"));
    model.config.add_station (make_station ("u2"));

    var cmd = updateModel (new ExportStationsMessage ("/tmp/out.json"), model, commands);
    assert (cmd != null);
    assert (commands.export_calls == 1);
    assert (commands.last_export_path == "/tmp/out.json");
    assert (commands.last_export_count == 2);
}

void test_export_success_reports_status () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    updateModel (new ExportSucceededMessage ("/tmp/out.json", 3), model, commands);
    assert (model.status_message == "Exported 3 stations");
}

void test_export_failure_reports_status () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    updateModel (new ExportFailedMessage ("disk full"), model, commands);
    assert (model.status_message == "disk full");
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
    assert (model.config.last_station_id == "u1");
    assert (commands.save_calls == 1);
}

void test_restore_last_station_plays_when_enabled () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var station = make_station ("u1");
    model.config.add_station (station);
    model.config.last_station_id = "u1";
    model.config.resume_playback = true;

    var cmd = updateModel (new RestoreLastStationMessage (), model, commands);
    assert (cmd != null);
    assert (model.current_station == station);
    assert (model.playing == true);
    assert (commands.play_calls == 1);
}

void test_restore_last_station_needs_setting () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.config.add_station (make_station ("u1"));
    model.config.last_station_id = "u1";
    model.config.resume_playback = false;

    var cmd = updateModel (new RestoreLastStationMessage (), model, commands);
    assert (cmd == null);
    assert (model.current_station == null);
    assert (commands.play_calls == 0);
}

void test_restore_last_station_unknown_id_is_noop () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.config.last_station_id = "missing";
    model.config.resume_playback = true;

    var cmd = updateModel (new RestoreLastStationMessage (), model, commands);
    assert (cmd == null);
    assert (commands.play_calls == 0);
}

void test_set_resume_playback_saves () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    var cmd = updateModel (new SetResumePlaybackMessage (true), model, commands);
    assert (cmd != null);
    assert (model.config.resume_playback == true);
    assert (commands.save_calls == 1);
}

void test_remove_current_station_clears_last_station () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.config.add_station (make_station ("u1"));
    model.config.last_station_id = "u1";

    updateModel (new RemoveStationMessage ("u1"), model, commands);
    assert (model.config.last_station_id == "");
}

void test_export_playlist_starts_command () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.config.add_station (make_station ("u1"));
    model.config.add_station (make_station ("u2"));

    var cmd = updateModel (new ExportPlaylistMessage ("/tmp/out.m3u"), model, commands);
    assert (cmd != null);
    assert (commands.playlist_calls == 1);
    assert (commands.last_playlist_path == "/tmp/out.m3u");
    assert (commands.last_playlist_count == 2);
}

void test_request_filter_options_starts_command () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    var cmd = updateModel (new RequestFilterOptionsMessage (), model, commands);
    assert (cmd != null);
    assert (commands.filter_option_calls == 1);
}

void test_filter_options_loaded_sets_names () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    updateModel (new FilterOptionsLoadedMessage (SearchFilterKind.COUNTRY,
        { "Germany", "France" }), model, commands);
    updateModel (new FilterOptionsLoadedMessage (SearchFilterKind.LANGUAGE,
        { "german" }), model, commands);
    updateModel (new FilterOptionsLoadedMessage (SearchFilterKind.TAG,
        { "jazz" }), model, commands);

    assert (model.filter_options (SearchFilterKind.COUNTRY).length == 2);
    assert (model.filter_options (SearchFilterKind.COUNTRY)[0] == "Germany");
    assert (model.filter_options (SearchFilterKind.LANGUAGE)[0] == "german");
    assert (model.filter_options (SearchFilterKind.TAG)[0] == "jazz");
    assert (model.filter_options (SearchFilterKind.STATE).length == 0);
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
    model.stream_title = "Track";
    model.stream_bitrate = 192;

    updateModel (new PlayerErrorMessage ("boom"), model, commands);
    assert (model.playing == false);
    assert (model.status_message == "boom");
    assert (model.stream_title == "");
    assert (model.stream_bitrate == 0);
}

void test_error_survives_stopped_state () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.playing = true;

    updateModel (new PlayerErrorMessage ("boom"), model, commands);
    updateModel (new PlayerStateChangedMessage (false), model, commands);
    assert (model.playing == false);
    assert (model.status_message == "boom");
}

void test_play_clears_error_state () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.playing = true;
    updateModel (new PlayerErrorMessage ("boom"), model, commands);

    updateModel (new PlayStationMessage (make_station ("u1")), model, commands);
    updateModel (new PlayerStateChangedMessage (false), model, commands);
    assert (model.status_message == "Stopped");
}

void test_stop_clears_metadata () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.current_station = make_station ("u1");
    model.playing = true;
    model.stream_title = "Track";
    model.stream_bitrate = 192;

    updateModel (new TogglePlayMessage (), model, commands);
    assert (model.playing == false);
    assert (model.stream_title == "");
    assert (model.stream_bitrate == 0);
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

void test_config_save_failed () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    updateModel (new ConfigSaveFailedMessage ("disk full"), model, commands);
    assert (model.status_message == "disk full");
}

void test_request_favicons_loads_library_and_results () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var library = make_station ("lib");
    var found = make_station ("found");
    model.config.add_station (library);
    model.search_results.add (found);

    updateModel (new RequestFaviconsMessage (), model, commands);

    assert (commands.favicon_calls == 1);
    assert (commands.last_favicon_stations.length == 2);
    assert (commands.last_favicon_stations.get (0) == library);
    assert (commands.last_favicon_stations.get (1) == found);
}

void test_favicon_loaded_stores_for_known_station () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var station = make_station ("u1");
    model.config.add_station (station);

    updateModel (new FaviconLoadedMessage ("u1", station.favicon, "/cache/u1.png"), model, commands);

    assert (model.favicon_for (station) == "/cache/u1.png");
}

void test_favicon_loaded_rejects_stale_url () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var station = make_station ("u1");
    model.config.add_station (station);

    updateModel (new FaviconLoadedMessage ("u1", "https://old.test/u1", "/cache/u1.png"), model, commands);

    assert (model.favicons.size () == 0);
    assert (model.favicon_for (station) == null);
}

void test_favicon_loaded_ignores_unknown_station () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    updateModel (new FaviconLoadedMessage ("missing", "https://example.test/x", "/cache/x.png"),
        model, commands);

    assert (model.favicons.size () == 0);
}

void test_favicon_failure_uses_fallback () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var station = make_station ("u1");
    model.config.add_station (station);

    updateModel (new FaviconLoadedMessage ("u1", station.favicon, ""), model, commands);

    assert (model.favicon_for (station) == null);
}

void test_favicon_loaded_ignores_station_without_favicon () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var station = make_station ("u1");
    station.favicon = "";
    model.config.add_station (station);

    updateModel (new FaviconLoadedMessage ("u1", "https://example.test/x.png", "/cache/x.png"),
        model, commands);

    assert (model.favicons.size () == 0);
    assert (model.favicon_for (station) == null);
}

void test_favicon_stale_source_is_not_rendered () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var station = make_station ("u1");
    model.config.add_station (station);

    updateModel (new FaviconLoadedMessage ("u1", station.favicon, "/cache/u1.png"), model, commands);
    station.favicon = "https://example.test/changed.png";

    assert (model.favicon_for (station) == null);
}

void test_clear_favicon_cache () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var station = make_station ("u1");
    model.config.add_station (station);
    model.favicons.set ("u1", "/cache/u1.png");
    model.favicon_sources.set ("u1", station.favicon);

    updateModel (new ClearFaviconCacheMessage (), model, commands);

    assert (model.favicons.size () == 0);
    assert (model.favicon_sources.size () == 0);
    assert (commands.clear_favicon_calls == 1);
    assert (commands.favicon_calls == 1);
    assert (model.status_message == "Favicon cache cleared");
}

void test_search_results_request_favicons () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var station = make_station ("found");
    model.search_generation = 7;

    var results = new GLib.GenericArray<RadioStation> ();
    results.add (station);
    updateModel (new SearchResultsMessage (results, 7), model, commands);

    assert (commands.favicon_calls == 1);
    assert (commands.last_favicon_stations.length == 1);
    assert (commands.last_favicon_stations.get (0) == station);
}

void test_window_geometry_changed () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    updateModel (new WindowGeometryChangedMessage (1200, 800, true), model, commands);

    assert (model.config.window_width == 1200);
    assert (model.config.window_height == 800);
    assert (model.config.maximized == true);
    assert (commands.save_calls == 1);
}

void test_window_geometry_rejects_invalid_size () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    updateModel (new WindowGeometryChangedMessage (0, -20, false), model, commands);

    assert (model.config.window_width == 900);
    assert (model.config.window_height == 600);
    assert (commands.save_calls == 0);
}

void test_set_icon_size () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    updateModel (new SetIconSizeMessage (64), model, commands);
    assert (model.config.icon_size == 64);
    assert (commands.save_calls == 1);

    updateModel (new SetIconSizeMessage (77), model, commands);
    assert (model.config.icon_size == 48);
}

void test_set_search_sort_mode_reruns_search () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.search_query = "jazz";
    model.search_generation = 4;

    updateModel (new SetSearchSortModeMessage (SearchSortMode.VOTES), model, commands);

    assert (model.config.search_sort == SearchSortMode.VOTES);
    assert (commands.save_calls == 1);
    assert (commands.search_calls == 1);
    assert (commands.last_query == "jazz");
    assert (model.search_generation == 5);
}

void test_set_search_filter_reruns_search () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.search_query = "jazz";
    model.search_generation = 2;

    updateModel (new SetSearchFilterMessage (SearchFilterKind.COUNTRY, "Germany"), model, commands);

    assert (model.config.search_filters.country == "Germany");
    assert (commands.save_calls == 1);
    assert (commands.search_calls == 1);
    assert (model.search_generation == 3);
}

void test_set_search_filter_without_query_searches_all () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.search_generation = 2;

    updateModel (new SetSearchFilterMessage (SearchFilterKind.TAG, "jazz"), model, commands);

    assert (model.config.search_filters.tag == "jazz");
    assert (commands.save_calls == 1);
    assert (commands.search_calls == 1);
    assert (commands.last_query == "");
    assert (model.search_active == true);
    assert (model.search_generation == 3);
}

void test_clearing_last_filter_stops_filter_search () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.config.search_filters.country = "Ukraine";
    model.search_active = true;
    model.search_results.add (make_station ("u1"));
    model.searching = true;
    model.search_generation = 2;

    updateModel (new SetSearchFilterMessage (SearchFilterKind.COUNTRY, ""), model, commands);

    assert (model.config.search_filters.is_empty ());
    assert (commands.save_calls == 1);
    assert (commands.search_calls == 0);
    assert (model.search_active == false);
    assert (model.search_results.length == 0);
    assert (model.searching == false);
    assert (model.search_generation == 3);
}

void test_set_search_sort_replays_filter_only_search () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    model.config.search_filters.country = "Ukraine";
    model.search_active = true;
    model.search_generation = 4;

    updateModel (new SetSearchSortModeMessage (SearchSortMode.CLICKS), model, commands);

    assert (commands.save_calls == 1);
    assert (commands.search_calls == 1);
    assert (commands.last_query == "");
    assert (model.search_generation == 5);
}

void test_favicon_discovered_sets_empty_source () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var station = make_station ("u1");
    station.favicon = "";
    model.config.add_station (station);

    updateModel (new FaviconDiscoveredMessage ("u1", "https://example.test/favicon.ico"),
        model, commands);

    assert (station.favicon == "https://example.test/favicon.ico");
    assert (commands.save_calls == 1);
}

void test_favicon_discovered_keeps_existing_source () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var station = make_station ("u1");
    model.config.add_station (station);

    updateModel (new FaviconDiscoveredMessage ("u1", "https://example.test/favicon.ico"),
        model, commands);

    assert (station.favicon == "https://example.test/u1.png");
    assert (commands.save_calls == 0);
}

void test_favicon_discovered_ignores_search_only_station () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var station = make_station ("found");
    station.favicon = "";
    model.search_results.add (station);

    updateModel (new FaviconDiscoveredMessage ("found", "https://example.test/favicon.ico"),
        model, commands);

    assert (station.favicon == "");
    assert (commands.save_calls == 0);
}

void test_add_local_station_assigns_id_and_saves () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var station = new RadioStation ();
    station.name = "Local Jazz";
    station.url = "https://example.test/jazz";

    var cmd = updateModel (new AddLocalStationMessage (station), model, commands);

    assert (cmd != null);
    assert (model.config.stations.length == 1);
    var added = model.config.stations.get (0);
    assert (added.id.has_prefix ("local-"));
    assert (added.is_local == true);
    assert (added.name == "Local Jazz");
    assert (commands.save_calls == 1);
}

void test_add_local_station_rejects_invalid () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var station = new RadioStation ();
    station.name = "Local Jazz";
    station.url = "not a url";

    var cmd = updateModel (new AddLocalStationMessage (station), model, commands);

    assert (cmd == null);
    assert (model.config.stations.length == 0);
    assert (model.status_message.contains ("URL"));
}

void test_add_local_station_rejects_duplicate_url () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var existing = make_station ("u1");
    existing.url = "https://example.test/jazz";
    model.config.add_station (existing);

    var station = new RadioStation ();
    station.name = "Local Jazz";
    station.url = existing.url;

    var cmd = updateModel (new AddLocalStationMessage (station), model, commands);
    assert (cmd == null);
    assert (model.config.stations.length == 1);
}

void test_update_local_station_copies_fields () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var existing = new RadioStation ();
    existing.id = "local-1";
    existing.is_local = true;
    existing.name = "Old";
    existing.url = "https://example.test/old";
    model.config.add_station (existing);

    var edited = existing.copy ();
    edited.name = "New";
    edited.url = "https://example.test/new";

    var cmd = updateModel (new UpdateLocalStationMessage (edited), model, commands);
    assert (cmd != null);
    assert (existing.name == "New");
    assert (existing.url == "https://example.test/new");
    assert (existing.id == "local-1");
    assert (commands.save_calls == 1);
}

void test_update_remote_station_is_rejected () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var remote = make_station ("u1");
    model.config.add_station (remote);

    var edited = remote.copy ();
    edited.name = "Changed";

    var cmd = updateModel (new UpdateLocalStationMessage (edited), model, commands);
    assert (cmd == null);
    assert (remote.name == "u1");
    assert (commands.save_calls == 0);
}

void test_set_library_sort_saves () {
    var model = make_model ();
    var commands = new RecordingCommands ();

    var cmd = updateModel (new SetLibrarySortMessage (LibrarySortMode.NAME, true),
        model, commands);
    assert (cmd != null);
    assert (model.config.library_sort == LibrarySortMode.NAME);
    assert (model.config.library_sort_descending == true);
    assert (commands.save_calls == 1);
}

void test_refresh_library_starts_command () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var remote = make_station ("u1");
    model.config.add_station (remote);
    var local = new RadioStation ();
    local.id = "local-1";
    local.is_local = true;
    model.config.add_station (local);

    var cmd = updateModel (new RefreshLibraryMessage (), model, commands);
    assert (cmd != null);
    assert (commands.refresh_calls == 1);
    assert (commands.last_refresh_count == 1);
}

void test_library_refreshed_updates_remote_and_marks_missing () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var remote = make_station ("u1");
    remote.name = "Old";
    model.config.add_station (remote);
    var gone = make_station ("u2");
    model.config.add_station (gone);
    var local = new RadioStation ();
    local.id = "local-1";
    local.is_local = true;
    local.name = "Local";
    model.config.add_station (local);

    var updated = make_station ("u1");
    updated.name = "New";
    var changed = new GLib.GenericArray<RadioStation> ();
    changed.add (updated);

    var cmd = updateModel (new LibraryRefreshedMessage (changed, { "u2" }), model, commands);
    assert (cmd != null);
    assert (remote.name == "New");
    assert (remote.orphaned == false);
    assert (gone.orphaned == true);
    assert (local.name == "Local");
    assert (local.orphaned == false);
    assert (commands.save_calls == 1);
}

void test_add_local_station_trims_fields () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var station = new RadioStation ();
    station.name = "  Local Jazz  ";
    station.url = "  https://example.test/jazz  ";

    var cmd = updateModel (new AddLocalStationMessage (station), model, commands);
    assert (cmd != null);
    var added = model.config.stations.get (0);
    assert (added.name == "Local Jazz");
    assert (added.url == "https://example.test/jazz");
    assert (added.original_url == "https://example.test/jazz");
}

void test_add_remote_duplicate_url_of_local_is_rejected () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var local = new RadioStation ();
    local.id = "local-1";
    local.is_local = true;
    local.name = "Local Jazz";
    local.url = "https://example.test/jazz";
    model.config.add_station (local);

    var remote = make_station ("u1");
    remote.url = "https://example.test/jazz";

    var cmd = updateModel (new AddStationMessage (remote), model, commands);
    assert (cmd == null);
    assert (model.config.stations.length == 1);
    assert (model.status_message.contains ("Already"));
}

void test_vote_local_station_is_rejected () {
    var model = make_model ();
    var commands = new RecordingCommands ();
    var local = new RadioStation ();
    local.id = "local-1";
    local.is_local = true;
    local.name = "Local";
    local.url = "https://example.test/local";
    model.config.add_station (local);

    var cmd = updateModel (new VoteStationMessage ("local-1"), model, commands);
    assert (cmd == null);
    assert (commands.vote_calls == 0);
    assert (model.votes_pending.size () == 0);
}

int main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/update/defaults", test_defaults);
    Test.add_func ("/update/set_view", test_set_view);
    Test.add_func ("/update/search_requested_empty", test_search_requested_empty);
    Test.add_func ("/update/search_requested_blank_with_filter", test_search_requested_blank_with_filter_browses);
    Test.add_func ("/update/search_clear_invalidates_in_flight", test_search_clear_invalidates_in_flight);
    Test.add_func ("/update/set_view_invalidates_in_flight", test_set_view_invalidates_in_flight);
    Test.add_func ("/update/same_view_keeps_search", test_same_view_keeps_search);
    Test.add_func ("/update/search_requested", test_search_requested);
    Test.add_func ("/update/search_results_current", test_search_results_current);
    Test.add_func ("/update/search_results_stale", test_search_results_stale);
    Test.add_func ("/update/search_failed", test_search_failed);
    Test.add_func ("/update/add_station", test_add_station);
    Test.add_func ("/update/add_duplicate", test_add_duplicate);
    Test.add_func ("/update/remove_station", test_remove_station);
    Test.add_func ("/update/move_station", test_move_station_reorders_and_saves);
    Test.add_func ("/update/move_station_noop", test_move_station_noop_does_not_save);
    Test.add_func ("/update/vote_starts_command", test_vote_starts_command);
    Test.add_func ("/update/vote_unknown_station", test_vote_unknown_station_is_ignored);
    Test.add_func ("/update/vote_duplicate", test_vote_duplicate_is_ignored);
    Test.add_func ("/update/vote_success", test_vote_success_marks_voted_and_updates_count);
    Test.add_func ("/update/vote_success_no_station", test_vote_success_without_station_increments_count);
    Test.add_func ("/update/vote_failure", test_vote_failure_reports_and_clears_pending);
    Test.add_func ("/update/player_error_notifies", test_player_error_notifies);
    Test.add_func ("/update/remove_current_station", test_remove_current_station);
    Test.add_func ("/update/import_starts_command", test_import_stations_starts_command);
    Test.add_func ("/update/import_success", test_import_success_merges_and_saves);
    Test.add_func ("/update/import_failure", test_import_failure_reports_status);
    Test.add_func ("/update/export_starts_command", test_export_starts_command);
    Test.add_func ("/update/export_success", test_export_success_reports_status);
    Test.add_func ("/update/export_failure", test_export_failure_reports_status);
    Test.add_func ("/update/play_station", test_play_station);
    Test.add_func ("/update/restore_last_station", test_restore_last_station_plays_when_enabled);
    Test.add_func ("/update/restore_last_station_disabled", test_restore_last_station_needs_setting);
    Test.add_func ("/update/restore_last_station_unknown", test_restore_last_station_unknown_id_is_noop);
    Test.add_func ("/update/set_resume_playback", test_set_resume_playback_saves);
    Test.add_func ("/update/remove_clears_last_station", test_remove_current_station_clears_last_station);
    Test.add_func ("/update/export_playlist", test_export_playlist_starts_command);
    Test.add_func ("/update/request_filter_options", test_request_filter_options_starts_command);
    Test.add_func ("/update/filter_options_loaded", test_filter_options_loaded_sets_names);
    Test.add_func ("/update/toggle_play", test_toggle_play);
    Test.add_func ("/update/player_state", test_player_state);
    Test.add_func ("/update/player_metadata", test_player_metadata);
    Test.add_func ("/update/player_error", test_player_error);
    Test.add_func ("/update/error_survives_stopped_state", test_error_survives_stopped_state);
    Test.add_func ("/update/play_clears_error_state", test_play_clears_error_state);
    Test.add_func ("/update/stop_clears_metadata", test_stop_clears_metadata);
    Test.add_func ("/update/show_details", test_show_details);
    Test.add_func ("/update/hide_details", test_hide_details);
    Test.add_func ("/update/set_volume_clamps", test_set_volume_clamps);
    Test.add_func ("/update/set_show_technical_info", test_set_show_technical_info);
    Test.add_func ("/update/config_save_failed", test_config_save_failed);
    Test.add_func ("/update/request_favicons", test_request_favicons_loads_library_and_results);
    Test.add_func ("/update/favicon_loaded", test_favicon_loaded_stores_for_known_station);
    Test.add_func ("/update/favicon_stale_url", test_favicon_loaded_rejects_stale_url);
    Test.add_func ("/update/favicon_unknown_station", test_favicon_loaded_ignores_unknown_station);
    Test.add_func ("/update/favicon_failure", test_favicon_failure_uses_fallback);
    Test.add_func ("/update/favicon_no_source", test_favicon_loaded_ignores_station_without_favicon);
    Test.add_func ("/update/favicon_discovered", test_favicon_discovered_sets_empty_source);
    Test.add_func ("/update/favicon_discovered_keeps_existing", test_favicon_discovered_keeps_existing_source);
    Test.add_func ("/update/favicon_discovered_search_only", test_favicon_discovered_ignores_search_only_station);
    Test.add_func ("/update/favicon_stale_source", test_favicon_stale_source_is_not_rendered);
    Test.add_func ("/update/clear_favicon_cache", test_clear_favicon_cache);
    Test.add_func ("/update/search_results_request_favicons", test_search_results_request_favicons);
    Test.add_func ("/update/window_geometry", test_window_geometry_changed);
    Test.add_func ("/update/window_geometry_invalid", test_window_geometry_rejects_invalid_size);
    Test.add_func ("/update/set_icon_size", test_set_icon_size);
    Test.add_func ("/update/set_search_sort_mode", test_set_search_sort_mode_reruns_search);
    Test.add_func ("/update/set_search_filter", test_set_search_filter_reruns_search);
    Test.add_func ("/update/set_search_filter_no_query", test_set_search_filter_without_query_searches_all);
    Test.add_func ("/update/clear_last_filter_stops_search", test_clearing_last_filter_stops_filter_search);
    Test.add_func ("/update/set_search_sort_filter_only", test_set_search_sort_replays_filter_only_search);
    Test.add_func ("/update/add_local_station", test_add_local_station_assigns_id_and_saves);
    Test.add_func ("/update/add_local_station_invalid", test_add_local_station_rejects_invalid);
    Test.add_func ("/update/add_local_station_duplicate", test_add_local_station_rejects_duplicate_url);
    Test.add_func ("/update/update_local_station", test_update_local_station_copies_fields);
    Test.add_func ("/update/update_remote_station_rejected", test_update_remote_station_is_rejected);
    Test.add_func ("/update/set_library_sort", test_set_library_sort_saves);
    Test.add_func ("/update/refresh_library", test_refresh_library_starts_command);
    Test.add_func ("/update/library_refreshed", test_library_refreshed_updates_remote_and_marks_missing);
    Test.add_func ("/update/add_local_station_trims", test_add_local_station_trims_fields);
    Test.add_func ("/update/add_remote_duplicate_local_url", test_add_remote_duplicate_url_of_local_is_rejected);
    Test.add_func ("/update/vote_local_rejected", test_vote_local_station_is_rejected);

    return Test.run ();
}
