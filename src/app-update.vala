// SPDX-License-Identifier: GPL-3.0-or-later

using Gradio;

// Receivers quantise the volume (commonly 0.05), so a duplicate report is only
// an exact repeat. Anything smaller than a step must still count as a change:
// comparing with a step-sized tolerance would swallow a real one-tap change.
private const double CAST_VOLUME_REPEAT_EPSILON = 0.001;

// A receiver that drops the sender again right after every attach is not
// recovering. Retrying forever would keep every cast control inert, so after a
// few quick drops the cast is reported lost and the controls work again.
private const int MAX_CAST_RECONNECTS = 3;
// Drops further apart than this are separate incidents, not a flapping loop: a
// cast that played for a while starts a fresh streak.
private const int64 CAST_RECONNECT_STREAK_US = 120 * 1000000L;

private RadioStation? find_station (Gradio.AppModel model, string id) {
    for (uint i = 0; i < model.config.stations.length; i++) {
        var station = model.config.stations.get (i);
        if (station.id == id)
            return station;
    }
    for (uint i = 0; i < model.search_results.length; i++) {
        var station = model.search_results.get (i);
        if (station.id == id)
            return station;
    }
    for (uint i = 0; i < model.discover_popular.length; i++) {
        var station = model.discover_popular.get (i);
        if (station.id == id)
            return station;
    }
    for (uint i = 0; i < model.discover_new.length; i++) {
        var station = model.discover_new.get (i);
        if (station.id == id)
            return station;
    }
    return null;
}

private Elmish.Cmd<Gradio.Message>? begin_discover (Gradio.AppModel model,
        Gradio.Commands commands) {
    model.discover_generation++;
    model.discover_pending = 2;
    model.discover_loading = true;
    model.discover_error = null;
    model.discover_popular = new GLib.GenericArray<RadioStation> ();
    model.discover_new = new GLib.GenericArray<RadioStation> ();
    return commands.discover (model.discover_generation);
}

private GLib.GenericArray<RadioStation> stations_for_favicons (Gradio.AppModel model) {
    var result = new GLib.GenericArray<RadioStation> ();
    var seen = new GLib.HashTable<string, bool> (str_hash, str_equal);

    for (uint i = 0; i < model.config.stations.length; i++) {
        var station = model.config.stations.get (i);
        if (seen.contains (station.id))
            continue;
        seen.set (station.id, true);
        result.add (station);
    }
    for (uint i = 0; i < model.search_results.length; i++) {
        var station = model.search_results.get (i);
        if (seen.contains (station.id))
            continue;
        seen.set (station.id, true);
        result.add (station);
    }
    for (uint i = 0; i < model.discover_popular.length; i++) {
        var station = model.discover_popular.get (i);
        if (seen.contains (station.id))
            continue;
        seen.set (station.id, true);
        result.add (station);
    }
    for (uint i = 0; i < model.discover_new.length; i++) {
        var station = model.discover_new.get (i);
        if (seen.contains (station.id))
            continue;
        seen.set (station.id, true);
        result.add (station);
    }

    return result;
}

private Elmish.Cmd<Gradio.Message>? stop_and_leave_background (Gradio.AppModel model,
        Gradio.Commands commands, Elmish.Cmd<Gradio.Message>? stop_cmd) {
    var release = commands.release_background ();
    var quit = model.window_hidden ? commands.quit_application () : null;
    model.window_hidden = false;
    return Gradio.Commands.chain (stop_cmd, Gradio.Commands.chain (release, quit));
}

public Elmish.Cmd<Gradio.Message>? updateModel (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var command = update_model (msg, model, commands);
    model.ensure_library_order ();
    return command;
}

private Elmish.Cmd<Gradio.Message>? update_model (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    switch (msg.kind) {
        case MessageKind.SET_VIEW:
            return update_set_view (msg, model, commands);
        case MessageKind.SEARCH_REQUESTED:
            return update_search_requested (msg, model, commands);
        case MessageKind.SEARCH_RESULTS:
            return update_search_results (msg, model, commands);
        case MessageKind.SEARCH_FAILED:
            return update_search_failed (msg, model, commands);
        case MessageKind.ADD_STATION:
            return update_add_station (msg, model, commands);
        case MessageKind.REMOVE_STATION:
            return update_remove_station (msg, model, commands);
        case MessageKind.MOVE_STATION:
            return update_move_station (msg, model, commands);
        case MessageKind.VOTE_STATION:
            return update_vote_station (msg, model, commands);
        case MessageKind.VOTE_SUCCEEDED:
            return update_vote_succeeded (msg, model, commands);
        case MessageKind.VOTE_FAILED:
            return update_vote_failed (msg, model, commands);
        case MessageKind.STOP_PLAYBACK:
            return update_stop_playback (msg, model, commands);
        case MessageKind.SET_BACKGROUND_PLAYBACK:
            return update_background_playback (msg, model, commands);
        case MessageKind.WINDOW_CLOSE_REQUESTED:
            return update_window_close_requested (msg, model, commands);
        case MessageKind.WINDOW_RAISED:
            return update_window_raised (msg, model, commands);
        case MessageKind.SET_NOTIFICATIONS:
            return update_notifications (msg, model, commands);
        case MessageKind.SET_CAST_LOSS_ACTION:
            return update_cast_loss_action (msg, model, commands);
        case MessageKind.IMPORT_STATIONS:
            return update_import_stations (msg, model, commands);
        case MessageKind.STATIONS_IMPORTED:
            return update_stations_imported (msg, model, commands);
        case MessageKind.IMPORT_FAILED:
            return update_import_failed (msg, model, commands);
        case MessageKind.EXPORT_STATIONS:
            return update_export_stations (msg, model, commands);
        case MessageKind.EXPORT_SUCCEEDED:
            return update_export_succeeded (msg, model, commands);
        case MessageKind.EXPORT_FAILED:
            return update_export_failed (msg, model, commands);
        case MessageKind.EXPORT_PLAYLIST:
            return update_export_playlist (msg, model, commands);
        case MessageKind.SET_RESUME_PLAYBACK:
            return update_resume_playback (msg, model, commands);
        case MessageKind.RESTORE_LAST_STATION:
            return update_restore_last_station (msg, model, commands);
        case MessageKind.REQUEST_FILTER_OPTIONS:
            return update_request_filter_options (msg, model, commands);
        case MessageKind.FILTER_OPTIONS_LOADED:
            return update_filter_options (msg, model, commands);
        case MessageKind.ADD_LOCAL_STATION:
            return update_add_local_station (msg, model, commands);
        case MessageKind.UPDATE_LOCAL_STATION:
            return update_update_local_station (msg, model, commands);
        case MessageKind.SET_LIBRARY_SORT:
            return update_set_library_sort (msg, model, commands);
        case MessageKind.REFRESH_LIBRARY:
            return update_refresh_library (msg, model, commands);
        case MessageKind.LIBRARY_REFRESHED:
            return update_library_refreshed (msg, model, commands);
        case MessageKind.PLAY_STATION:
            return update_play_station (msg, model, commands);
        case MessageKind.TOGGLE_PLAY:
            return update_toggle_play (msg, model, commands);
        case MessageKind.PLAYER_STATE_CHANGED:
            return update_player_state_changed (msg, model, commands);
        case MessageKind.PLAYER_METADATA_CHANGED:
            return update_player_metadata_changed (msg, model, commands);
        case MessageKind.PLAYER_ERROR:
            return update_player_error (msg, model, commands);
        case MessageKind.PLAYER_RECONNECTING:
            return update_player_reconnecting (msg, model, commands);
        case MessageKind.SHOW_DETAILS:
            return update_show_details (msg, model, commands);
        case MessageKind.HIDE_DETAILS:
            return update_hide_details (msg, model, commands);
        case MessageKind.SET_VOLUME:
            return update_volume (msg, model, commands);
        case MessageKind.SET_SHOW_TECHNICAL_INFO:
            return update_show_technical_info (msg, model, commands);
        case MessageKind.SET_SHOW_STATUS_BAR:
            return update_show_status_bar (msg, model, commands);
        case MessageKind.SET_PLAYER_IN_HEADER:
            return update_player_in_header (msg, model, commands);
        case MessageKind.CONFIG_SAVE_FAILED:
            return update_config_save_failed (msg, model, commands);
        case MessageKind.REQUEST_FAVICONS:
            return update_request_favicons (msg, model, commands);
        case MessageKind.FAVICON_LOADED:
            return update_favicon_loaded (msg, model, commands);
        case MessageKind.FAVICON_DISCOVERED:
            return update_favicon_discovered (msg, model, commands);
        case MessageKind.CLEAR_FAVICON_CACHE:
            return update_clear_favicon_cache (msg, model, commands);
        case MessageKind.WINDOW_GEOMETRY_CHANGED:
            return update_window_geometry (msg, model, commands);
        case MessageKind.SET_ICON_SIZE:
            return update_set_icon_size (msg, model, commands);
        case MessageKind.SET_SEARCH_SORT_MODE:
            return update_set_search_sort_mode (msg, model, commands);
        case MessageKind.SET_SEARCH_FILTER:
            return update_set_search_filter (msg, model, commands);
        case MessageKind.REQUEST_DISCOVER:
            return update_request_discover (msg, model, commands);
        case MessageKind.DISCOVER_RESULTS:
            return update_discover_results (msg, model, commands);
        case MessageKind.DISCOVER_FAILED:
            return update_discover_failed (msg, model, commands);
        case MessageKind.DISCOVER_SERVER:
            return update_discover_server (msg, model, commands);
        case MessageKind.SERVER_DISCOVERED:
            return update_server_discovered (msg, model, commands);
        case MessageKind.SERVER_DISCOVERY_FAILED:
            return update_server_discovery_failed (msg, model, commands);
        case MessageKind.DISCOVER_CAST_DEVICES:
            return update_discover_cast_devices (msg, model, commands);
        case MessageKind.CAST_DEVICES_DISCOVERED:
            return update_cast_devices_discovered (msg, model, commands);
        case MessageKind.CAST_DISCOVERY_FAILED:
            return update_cast_discovery_failed (msg, model, commands);
        case MessageKind.SELECT_CAST_DEVICE:
            return update_select_cast_device (msg, model, commands);
        case MessageKind.CAST_TO_SELECTED:
            return update_cast_to_selected (msg, model, commands);
        case MessageKind.CAST_STARTED:
            return update_cast_started (msg, model, commands);
        case MessageKind.CAST_STOPPED:
            return update_cast_stopped (msg, model, commands);
        case MessageKind.CAST_FAILED:
            return update_cast_failed (msg, model, commands);
        case MessageKind.CAST_LOST:
            return update_cast_lost (msg, model, commands);
        case MessageKind.CAST_SENDER_LOST:
            return update_cast_sender_lost (msg, model, commands);
        case MessageKind.CAST_VOLUME:
            return update_cast_volume (msg, model, commands);
        case MessageKind.CAST_PAUSED:
            return update_cast_paused (msg, model, commands);
        case MessageKind.CAST_BUFFERING:
            return update_cast_buffering (msg, model, commands);
        case MessageKind.STOP_CAST:
            return update_stop_cast (msg, model, commands);
        case MessageKind.PLAY_LOCAL:
            return update_play_local (msg, model, commands);
        case MessageKind.SYNC_CAST_SESSION:
            return update_sync_cast_session (msg, model, commands);
        case MessageKind.CAST_SESSION_DETECTED:
            return update_cast_session_detected (msg, model, commands);
        case MessageKind.CAST_ADOPTED:
            return update_cast_adopted (msg, model, commands);
        case MessageKind.CAST_ADOPT_FAILED:
            return update_cast_adopt_failed (msg, model, commands);
        case MessageKind.CAST_METADATA:
            return update_cast_metadata (msg, model, commands);
        case MessageKind.SET_CAST_KEEP_ON_QUIT:
            return update_set_cast_keep_on_quit (msg, model, commands);
        case MessageKind.SET_CAST_TRACK_TITLES:
            return update_set_cast_track_titles (msg, model, commands);
        case MessageKind.SET_CAST_TRACK_TITLES_INTERVAL:
            return update_set_cast_track_titles_interval (msg, model, commands);
        default:
            // Vala enums are not exhaustiveness-checked. Keep a loud failure
            // here so a MessageKind added without an update case cannot
            // silently no-op.
            assert_not_reached ();
    }

    return null;
}

private Elmish.Cmd<Gradio.Message>? update_set_view (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var set_view = msg as SetViewMessage;
    if (set_view == null)
        return null;
    bool view_changed = set_view.view != model.view;
    model.view = set_view.view;
    if (view_changed) {
        model.search_generation++;
        if (set_view.view == ViewMode.ADD_STATION) {
            model.search_query = "";
            model.search_active = false;
            model.search_results = new GLib.GenericArray<RadioStation> ();
            model.search_error = null;
            model.searching = false;
            model.details_visible = false;
            if (!model.config.search_filters.is_empty ()) {
                model.search_active = true;
                model.searching = true;
                return commands.search ("", model.search_generation);
            }
            return begin_discover (model, commands);
        }
    }
    model.details_visible = false;
    return null;
}

private Elmish.Cmd<Gradio.Message>? update_background_playback (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var background = msg as SetBackgroundPlaybackMessage;
    if (background == null || background.enabled == model.config.background_playback)
        return null;
    model.config.background_playback = background.enabled;
    return commands.save_config ();
}

private Elmish.Cmd<Gradio.Message>? update_notifications (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var notifications = msg as SetNotificationsMessage;
    if (notifications == null || notifications.enabled == model.config.notifications_enabled)
        return null;
    model.config.notifications_enabled = notifications.enabled;
    return commands.save_config ();
}

private Elmish.Cmd<Gradio.Message>? update_cast_loss_action (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var action = msg as SetCastLossActionMessage;
    if (action == null || action.action == model.config.cast_loss_action)
        return null;
    model.config.cast_loss_action = action.action;
    return commands.save_config ();
}

private Elmish.Cmd<Gradio.Message>? update_resume_playback (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var resume = msg as SetResumePlaybackMessage;
    if (resume == null || resume.enabled == model.config.resume_playback)
        return null;
    model.config.resume_playback = resume.enabled;
    return commands.save_config ();
}

private Elmish.Cmd<Gradio.Message>? update_show_technical_info (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var technical = msg as SetShowTechnicalInfoMessage;
    if (technical == null)
        return null;
    model.config.show_technical_info = technical.enabled;
    return commands.save_config ();
}

private Elmish.Cmd<Gradio.Message>? update_show_status_bar (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var status_bar = msg as SetShowStatusBarMessage;
    if (status_bar == null || status_bar.enabled == model.config.show_status_bar)
        return null;
    model.config.show_status_bar = status_bar.enabled;
    return commands.save_config ();
}

private Elmish.Cmd<Gradio.Message>? update_player_in_header (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var player_in_header = msg as SetPlayerInHeaderMessage;
    if (player_in_header == null ||
            player_in_header.enabled == model.config.player_in_header)
        return null;
    model.config.player_in_header = player_in_header.enabled;
    return commands.save_config ();
}

private Elmish.Cmd<Gradio.Message>? update_volume (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var volume = msg as SetVolumeMessage;
    if (volume == null)
        return null;
    double clamped = volume.volume.clamp (0.0, 1.0);
    model.config.volume = clamped;
    var local = commands.set_volume (clamped);
    // Only an attached session on the cast output accepts SET_VOLUME: mid
    // re-attach the socket is gone, and while CONNECTING no media session
    // exists yet, so the level stays local until the receiver reports its own.
    if (model.playback_target != PlaybackTarget.CAST || !model.cast_attached ||
            model.cast_reconnecting)
        return local;
    return Commands.chain (local, commands.set_cast_volume (clamped));
}

private Elmish.Cmd<Gradio.Message>? update_config_save_failed (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var save_error = msg as ConfigSaveFailedMessage;
    if (save_error == null)
        return null;
    model.status_message = save_error.message;
    return null;
}

private Elmish.Cmd<Gradio.Message>? update_import_stations (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var import = msg as ImportStationsMessage;
    if (import == null || import.path == "")
        return null;
    return commands.import_stations (import.path);
}

private Elmish.Cmd<Gradio.Message>? update_stations_imported (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var imported = msg as StationsImportedMessage;
    if (imported == null)
        return null;
    var summary = model.config.import_stations (imported.stations);
    if (summary.imported == 1)
        model.status_message = _("Imported 1 station, skipped %d").printf (summary.skipped);
    else
        model.status_message = _("Imported %d stations, skipped %d").printf (
            summary.imported, summary.skipped);
    if (summary.imported == 0)
        return null;
    model.invalidate_library_order ();
    return commands.save_config ();
}

private Elmish.Cmd<Gradio.Message>? update_import_failed (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var import_error = msg as ImportFailedMessage;
    if (import_error == null)
        return null;
    model.status_message = import_error.message;
    return null;
}

private Elmish.Cmd<Gradio.Message>? update_export_stations (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var export = msg as ExportStationsMessage;
    if (export == null || export.path == "")
        return null;
    var copy = new GLib.GenericArray<RadioStation> ();
    for (uint i = 0; i < model.config.stations.length; i++)
        copy.add (model.config.stations.get (i));
    return commands.export_stations (copy, export.path);
}

private Elmish.Cmd<Gradio.Message>? update_export_succeeded (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var exported = msg as ExportSucceededMessage;
    if (exported == null)
        return null;
    model.status_message = _("Exported %d stations").printf (exported.count);
    return null;
}

private Elmish.Cmd<Gradio.Message>? update_export_failed (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var export_error = msg as ExportFailedMessage;
    if (export_error == null)
        return null;
    model.status_message = export_error.message;
    return null;
}

private Elmish.Cmd<Gradio.Message>? update_export_playlist (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var playlist = msg as ExportPlaylistMessage;
    if (playlist == null || playlist.path == "")
        return null;
    var playlist_copy = new GLib.GenericArray<RadioStation> ();
    for (uint i = 0; i < model.config.stations.length; i++)
        playlist_copy.add (model.config.stations.get (i));
    return commands.export_playlist (playlist_copy, playlist.path);
}

private Elmish.Cmd<Gradio.Message>? update_filter_options (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var options = msg as FilterOptionsLoadedMessage;
    if (options == null || options.names.length == 0)
        return null;
    switch (options.field) {
        case SearchFilterKind.COUNTRY:
            model.filter_countries = options.names;
            break;
        case SearchFilterKind.LANGUAGE:
            model.filter_languages = options.names;
            break;
        case SearchFilterKind.TAG:
            model.filter_tags = options.names;
            break;
        default:
            break;
    }
    return null;
}

private Elmish.Cmd<Gradio.Message>? update_add_station (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var add = msg as AddStationMessage;
    if (add == null)
        return null;
    if (model.config.find_station_by_url (add.station.url) != null ||
            model.config.find_station_by_url (add.station.original_url) != null) {
        model.status_message = _("Already in library");
        return null;
    }
    if (model.config.add_station (add.station)) {
        model.invalidate_library_order ();
        model.status_message = _("Added %s").printf (add.station.name);
        return commands.save_config ();
    }
    model.status_message = _("Already in library");
    return null;
}

private Elmish.Cmd<Gradio.Message>? update_add_local_station (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var add_local = msg as AddLocalStationMessage;
    if (add_local == null)
        return null;
    string? validation = StationValidation.validate (add_local.station.name,
        add_local.station.url, add_local.station.homepage, model.config);
    if (validation != null) {
        model.status_message = validation;
        return null;
    }
    var local = add_local.station.copy ();
    local.id = RadioStation.new_local_id ();
    local.is_local = true;
    local.orphaned = false;
    local.name = local.name.strip ();
    local.url = local.url.strip ();
    local.original_url = local.original_url.strip ();
    local.homepage = local.homepage.strip ();
    local.country = local.country.strip ();
    local.state = local.state.strip ();
    local.language = local.language.strip ();
    local.tags = local.tags.strip ();
    local.codec = local.codec.strip ();
    if (local.original_url == "")
        local.original_url = local.url;
    model.config.add_station (local);
    model.invalidate_library_order ();
    model.status_message = _("Added %s").printf (local.name);
    return commands.save_config ();
}

private Elmish.Cmd<Gradio.Message>? update_update_local_station (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var update_local = msg as UpdateLocalStationMessage;
    if (update_local == null)
        return null;
    var existing = model.config.find_station (update_local.station.id);
    if (existing == null || !existing.is_local) {
        model.status_message = _("Only local stations can be edited");
        return null;
    }
    string? update_validation = StationValidation.validate (update_local.station.name,
        update_local.station.url, update_local.station.homepage, model.config,
        existing.id);
    if (update_validation != null) {
        model.status_message = update_validation;
        return null;
    }
    existing.name = update_local.station.name.strip ();
    string new_url = update_local.station.url.strip ();
    if (existing.url != new_url)
        existing.original_url = new_url;
    existing.url = new_url;
    existing.homepage = update_local.station.homepage.strip ();
    existing.state = update_local.station.state.strip ();
    existing.language = update_local.station.language.strip ();
    existing.country = update_local.station.country.strip ();
    existing.tags = update_local.station.tags.strip ();
    if (update_local.station.codec.strip () != "")
        existing.codec = update_local.station.codec.strip ();
    if (update_local.station.bitrate > 0)
        existing.bitrate = update_local.station.bitrate;
    model.invalidate_library_order ();
    model.status_message = _("Saved %s").printf (existing.name);
    return commands.save_config ();
}

private Elmish.Cmd<Gradio.Message>? update_remove_station (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var remove = msg as RemoveStationMessage;
    if (remove == null)
        return null;
    bool was_current = model.current_station != null &&
        model.current_station.id == remove.station_id;
    // Removing the casted station stops the cast, and a dropped socket cannot
    // deliver that: the receiver would keep playing a station the app dropped.
    if (was_current && model.cast_reconnecting) {
        model.status_message = _("Waiting for the cast to reconnect");
        return null;
    }
    if (!model.config.remove_station (remove.station_id)) {
        model.status_message = _("Station not found");
        return null;
    }
    model.invalidate_library_order ();

    if (model.details_station != null && model.details_station.id == remove.station_id) {
        model.details_station = null;
        model.details_visible = false;
    }
    if (model.config.last_station_id == remove.station_id)
        model.config.last_station_id = "";

    if (was_current) {
        model.current_station = null;
        model.playing = false;
        model.stream_title = "";
        model.stream_bitrate = 0;
        model.details_station = null;
        model.details_visible = false;
        model.playback_stopped = true;
        model.status_message = _("Station removed");
        if (model.playback_target == PlaybackTarget.CAST &&
                model.cast_device_id != null && model.cast_device_id != "") {
            model.playback_target = PlaybackTarget.LOCAL;
            model.cast_status = CastStatus.STOPPED;
            model.cast_attached = false;
            model.config.cast_mode = false;
            model.cast_resume_pending = false;
            model.cast_retry_on_discovery = false;
            model.cast_remote_label = "";
            model.cast_pending_label = "";
            return Commands.chain (commands.stop_cast (model.cast_device_id,
                cast_host_for (model), cast_port_for (model)),
                Commands.chain (commands.release_sleep (), commands.save_config ()));
        }
        return Commands.chain (commands.stop (),
            Commands.chain (commands.release_sleep (), commands.save_config ()));
    }

    model.status_message = _("Station removed");
    return commands.save_config ();
}

private Elmish.Cmd<Gradio.Message>? update_move_station (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var move = msg as MoveStationMessage;
    if (move == null)
        return null;
    if (!model.config.move_station (move.station_id, move.target_id, move.after))
        return null;
    model.invalidate_library_order ();
    return commands.save_config ();
}

private Elmish.Cmd<Gradio.Message>? update_set_library_sort (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var library_sort = msg as SetLibrarySortMessage;
    if (library_sort == null)
        return null;
    if (library_sort.mode == model.config.library_sort &&
            library_sort.descending == model.config.library_sort_descending)
        return null;
    model.config.library_sort = library_sort.mode;
    model.config.library_sort_descending = library_sort.descending;
    return commands.save_config ();
}

private Elmish.Cmd<Gradio.Message>? update_refresh_library (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var refresh = new GLib.GenericArray<RadioStation> ();
    for (uint i = 0; i < model.config.stations.length; i++) {
        var station = model.config.stations.get (i);
        if (!station.is_local && station.id != "")
            refresh.add (station);
    }
    if (refresh.length == 0)
        return null;
    return commands.refresh_library (refresh);
}

private Elmish.Cmd<Gradio.Message>? update_library_refreshed (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var refreshed = msg as LibraryRefreshedMessage;
    if (refreshed == null)
        return null;
    bool changed = false;
    for (uint i = 0; i < refreshed.updated.length; i++) {
        var incoming = refreshed.updated.get (i);
        var existing = model.config.find_station (incoming.id);
        if (existing == null || existing.is_local)
            continue;
        existing.name = incoming.name;
        existing.url = incoming.url;
        existing.original_url = incoming.original_url;
        existing.favicon = incoming.favicon;
        existing.country = incoming.country;
        existing.countrycode = incoming.countrycode;
        existing.state = incoming.state;
        existing.language = incoming.language;
        existing.tags = incoming.tags;
        existing.codec = incoming.codec;
        existing.bitrate = incoming.bitrate;
        existing.homepage = incoming.homepage;
        existing.broken = incoming.broken;
        existing.votes = incoming.votes;
        existing.clickcount = incoming.clickcount;
        existing.orphaned = false;
        changed = true;
    }
    foreach (string missing_id in refreshed.missing_ids) {
        var existing = model.config.find_station (missing_id);
        if (existing != null && !existing.is_local && !existing.orphaned) {
            existing.orphaned = true;
            changed = true;
        }
    }
    if (changed) {
        model.invalidate_library_order ();
        var save = commands.save_config ();
        if (refreshed.updated.length > 0)
            return Commands.chain (save,
                commands.load_favicons (stations_for_favicons (model)));
        return save;
    }
    return null;
}

private Elmish.Cmd<Gradio.Message>? update_search_requested (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var requested = msg as SearchRequestedMessage;
    if (requested == null)
        return null;
    string query = requested.query.strip ();
    if (query == "" && model.config.search_filters.is_empty ()) {
        model.search_generation++;
        model.search_query = "";
        model.search_active = false;
        model.search_results = new GLib.GenericArray<RadioStation> ();
        model.search_error = null;
        model.searching = false;
        if (model.discover_popular.length == 0 &&
                model.discover_new.length == 0 &&
                !model.discover_loading)
            return begin_discover (model, commands);
        return null;
    }
    model.search_generation++;
    model.searching = true;
    model.search_error = null;
    model.search_active = true;
    model.search_query = query;
    return commands.search (query, model.search_generation);
}

private Elmish.Cmd<Gradio.Message>? update_search_results (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var results = msg as SearchResultsMessage;
    if (results == null || results.generation != model.search_generation)
        return null;
    model.search_results = results.stations;
    model.searching = false;
    model.search_error = null;
    return commands.load_favicons (results.stations);
}

private Elmish.Cmd<Gradio.Message>? update_search_failed (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var failed = msg as SearchFailedMessage;
    if (failed == null || failed.generation != model.search_generation)
        return null;
    model.searching = false;
    model.search_error = failed.message;
    return null;
}

private Elmish.Cmd<Gradio.Message>? update_set_search_sort_mode (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var search_sort = msg as SetSearchSortModeMessage;
    if (search_sort == null || search_sort.mode == model.config.search_sort)
        return null;
    model.config.search_sort = search_sort.mode;
    // Search results are sorted client-side, so changing the order
    // never needs another network request.
    return commands.save_config ();
}

private Elmish.Cmd<Gradio.Message>? update_request_filter_options (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    return commands.load_filter_options ();
}

private Elmish.Cmd<Gradio.Message>? update_request_discover (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    return begin_discover (model, commands);
}

private Elmish.Cmd<Gradio.Message>? update_discover_results (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var discover_results = msg as DiscoverResultsMessage;
    if (discover_results == null ||
            discover_results.generation != model.discover_generation)
        return null;
    if (discover_results.mode == DiscoverMode.POPULAR)
        model.discover_popular = discover_results.stations;
    else
        model.discover_new = discover_results.stations;
    if (model.discover_pending > 0)
        model.discover_pending--;
    model.discover_loading = model.discover_pending > 0;
    return commands.load_favicons (discover_results.stations);
}

private Elmish.Cmd<Gradio.Message>? update_discover_failed (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var discover_failed = msg as DiscoverFailedMessage;
    if (discover_failed == null ||
            discover_failed.generation != model.discover_generation)
        return null;
    model.discover_error = discover_failed.message;
    if (model.discover_pending > 0)
        model.discover_pending--;
    model.discover_loading = model.discover_pending > 0;
    return null;
}

private Elmish.Cmd<Gradio.Message>? update_discover_server (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    model.server_ready = false;
    model.server_error = null;
    return commands.discover_server ();
}

private Elmish.Cmd<Gradio.Message>? update_server_discovered (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var discovered = msg as ServerDiscoveredMessage;
    if (discovered == null)
        return null;
    model.server_ready = true;
    model.server_error = null;
    if (model.search_active && (model.search_error != null || model.searching)) {
        model.search_generation++;
        model.searching = true;
        model.search_error = null;
        return commands.search (model.search_query, model.search_generation);
    }
    if (model.view == ViewMode.ADD_STATION && !model.search_active)
        return begin_discover (model, commands);
    return null;
}

private Elmish.Cmd<Gradio.Message>? update_server_discovery_failed (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var discovery_error = msg as ServerDiscoveryFailedMessage;
    if (discovery_error == null)
        return null;
    model.server_ready = false;
    model.server_error = discovery_error.message;
    model.status_message = _("Using the default radio-browser server");
    return null;
}

private Elmish.Cmd<Gradio.Message>? update_set_search_filter (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var filter = msg as SetSearchFilterMessage;
    if (filter == null)
        return null;
    string value = filter.value.strip ();
    bool changed = false;
    switch (filter.field) {
        case SearchFilterKind.COUNTRY:
            changed = model.config.search_filters.country != value;
            model.config.search_filters.country = value;
            break;
        case SearchFilterKind.STATE:
            changed = model.config.search_filters.state != value;
            model.config.search_filters.state = value;
            break;
        case SearchFilterKind.LANGUAGE:
            changed = model.config.search_filters.language != value;
            model.config.search_filters.language = value;
            break;
        case SearchFilterKind.TAG:
            changed = model.config.search_filters.tag != value;
            model.config.search_filters.tag = value;
            break;
    }
    if (!changed)
        return null;
    var save = commands.save_config ();
    // Filters are Add-view state: changing them elsewhere must not
    // trigger a network search behind the user's back.
    if (model.view != ViewMode.ADD_STATION)
        return save;
    if (model.search_query == "" && model.config.search_filters.is_empty ()) {
        model.search_generation++;
        model.search_active = false;
        model.search_results = new GLib.GenericArray<RadioStation> ();
        model.search_error = null;
        model.searching = false;
        if (model.discover_popular.length == 0 &&
                model.discover_new.length == 0 &&
                !model.discover_loading)
            return Commands.chain (save, begin_discover (model, commands));
        return save;
    }
    model.search_generation++;
    model.searching = true;
    model.search_error = null;
    model.search_active = true;
    return Commands.chain (save,
        commands.search (model.search_query, model.search_generation));
}

private Elmish.Cmd<Gradio.Message>? update_play_station (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var play = msg as PlayStationMessage;
    if (play == null)
        return null;
    model.current_station = play.station;
    model.config.last_station_id = play.station.id;
    model.current_stream_url = play.station.url;
    model.playing = true;
    model.playback_stopped = false;
    model.playback_failed = false;
    model.stream_title = "";
    model.stream_bitrate = 0;
    model.player_status = _("Connecting…");
    model.last_notified_title = "";
    var report = play.station.is_local
        ? null
        : commands.report_click (play.station.id);
    // No notification: the first metadata tick announces the station.
    // last_notified_title is reset above so it always fires.
    if (model.playback_target == PlaybackTarget.CAST &&
            model.cast_device_id != null) {
        model.config.cast_mode = true;
        model.cast_status = CastStatus.CONNECTING;
        model.cast_attached = false;
        model.cast_reconnecting = false;
        model.cast_reconnect_attempts = 0;
        model.cast_device_volume = -1.0;
        model.cast_remote_label = "";
        model.cast_pending_label = "";
        return Commands.chain (commands.stop_cast_metadata (),
            Commands.chain (commands.save_config (),
                Commands.chain (commands.stop (),
                    Commands.chain (commands.cast (model.cast_device_id,
                            cast_host_for (model), cast_port_for (model),
                            model.current_stream_url),
                        Commands.chain (commands.inhibit_sleep (), report)))));
    }
    model.cast_remote_label = "";
    model.cast_pending_label = "";
    return Commands.chain (commands.save_config (),
        Commands.chain (commands.play (play.station),
            Commands.chain (commands.inhibit_sleep (), report)));
}

private Elmish.Cmd<Gradio.Message>? update_toggle_play (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    // No stream yet (cast mode restored from config, nothing played this
    // session): there is nothing to LOAD, so fall through to the local path,
    // which ignores the toggle while no station is selected.
    if (model.playback_target == PlaybackTarget.CAST &&
            model.cast_device_id != null && model.current_stream_url != "") {
        // Nothing can reach the receiver mid-re-attach, and tearing the cast
        // down would orphan a session that may still be playing.
        if (model.cast_reconnecting)
            return null;
        if (model.playing) {
            if (model.cast_attached) {
                // A live session: pause it instead of stopping and restarting.
                // The model commits to PAUSED only when the device reports it.
                return commands.pause_cast (model.cast_device_id);
            }
            model.playing = false;
            model.playback_stopped = true;
            model.playback_failed = false;
            model.stream_title = "";
            model.stream_bitrate = 0;
            model.player_status = "";
            model.cast_status = CastStatus.STOPPED;
            model.cast_attached = false;
            model.cast_remote_label = "";
            model.cast_pending_label = "";
            model.cast_resume_pending = false;
            model.cast_retry_on_discovery = false;
            model.cast_error = "";
            model.playback_target = PlaybackTarget.LOCAL;
            model.config.cast_mode = false;
            return Commands.chain (commands.save_config (),
                Commands.chain (commands.stop_cast_metadata (),
                    Commands.chain (commands.stop_cast (model.cast_device_id,
                        cast_host_for (model), cast_port_for (model)),
                        commands.release_sleep ())));
        }
        if (model.cast_attached) {
            model.playing = true;
            model.playback_stopped = false;
            model.playback_failed = false;
            model.player_status = _("Connecting…");
            model.cast_status = CastStatus.CONNECTING;
            model.cast_device_volume = -1.0;
            return Commands.chain (
                commands.resume_cast (model.cast_device_id),
                commands.inhibit_sleep ());
        }
        model.playing = true;
        model.playback_stopped = false;
        model.playback_failed = false;
        model.player_status = _("Connecting…");
        model.cast_status = CastStatus.CONNECTING;
        model.cast_device_volume = -1.0;
        model.config.cast_mode = true;
        return Commands.chain (commands.save_config (),
            Commands.chain (commands.cast (model.cast_device_id,
                cast_host_for (model), cast_port_for (model),
                model.current_stream_url), commands.inhibit_sleep ()));
    }
    if (model.current_station == null)
        return null;
    model.playing = !model.playing;
    if (model.playing) {
        model.playback_stopped = false;
        model.playback_failed = false;
        model.player_status = _("Connecting…");
        return Commands.chain (commands.play (model.current_station),
            commands.inhibit_sleep ());
    }
    // A toggle from playing is a pause: live radio cannot buffer, so the
    // pipeline stops but MPRIS reports "Paused". STOP_PLAYBACK marks stopped.
    model.playback_failed = false;
    model.stream_title = "";
    model.stream_bitrate = 0;
    model.player_status = "";
    return stop_and_leave_background (model, commands,
        Commands.chain (commands.stop (), commands.release_sleep ()));
}

private Elmish.Cmd<Gradio.Message>? update_stop_playback (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    if (model.cast_reconnecting)
        return null;
    if (model.playback_target == PlaybackTarget.CAST &&
            model.cast_device_id != null) {
        model.playing = false;
        model.playback_stopped = true;
        model.playback_failed = false;
        model.stream_title = "";
        model.stream_bitrate = 0;
        model.player_status = "";
        model.cast_status = CastStatus.STOPPED;
        model.cast_attached = false;
        model.cast_remote_label = "";
        model.cast_pending_label = "";
        model.cast_resume_pending = false;
        model.cast_retry_on_discovery = false;
        model.cast_error = "";
        model.playback_target = PlaybackTarget.LOCAL;
        model.config.cast_mode = false;
        return Commands.chain (commands.save_config (),
            Commands.chain (commands.stop_cast_metadata (),
                Commands.chain (commands.stop_cast (model.cast_device_id,
                    cast_host_for (model), cast_port_for (model)),
                    commands.release_sleep ())));
    }
    model.playing = false;
    model.playback_stopped = true;
    model.playback_failed = false;
    model.stream_title = "";
    model.stream_bitrate = 0;
    model.player_status = "";
    return stop_and_leave_background (model, commands,
        Commands.chain (commands.stop (), commands.release_sleep ()));
}

private Elmish.Cmd<Gradio.Message>? update_player_state_changed (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var state = msg as PlayerStateChangedMessage;
    if (state == null)
        return null;
    // Local player teardown during cast must not release the cast inhibitor.
    if (model.playback_target == PlaybackTarget.CAST)
        return null;
    model.playing = state.playing;
    if (state.playing) {
        model.playback_stopped = false;
        model.playback_failed = false;
        // Steady playback needs no status: the stop icon says it all.
        model.player_status = "";
        return commands.inhibit_sleep ();
    } else {
        model.stream_title = "";
        model.stream_bitrate = 0;
        if (!model.playback_failed)
            model.player_status = "";
        return commands.release_sleep ();
    }
}

private Elmish.Cmd<Gradio.Message>? update_player_metadata_changed (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var metadata = msg as PlayerMetadataChangedMessage;
    // Local player tags describe local output only: the receiver owns the title.
    if (metadata == null || !model.playing ||
            model.playback_target != PlaybackTarget.LOCAL)
        return null;
    model.stream_bitrate = metadata.bitrate;
    return apply_stream_metadata (model, commands, metadata.title);
}

private Elmish.Cmd<Gradio.Message>? update_cast_metadata (Gradio.Message msg,
        Gradio.AppModel model, Gradio.Commands commands) {
    var metadata = msg as CastMetadataMessage;
    if (metadata == null || metadata.device_id != model.cast_device_id)
        return null;
    if (model.cast_reconnecting)
        return null;
    if (!model.config.cast_track_titles)
        return null;
    if (!model.playing || model.playback_target != PlaybackTarget.CAST)
        return null;
    // A status without media.metadata never erases the shown title.
    if (metadata.title == "")
        return null;
    return apply_stream_metadata (model, commands, metadata.title);
}

// Layer 2 is optional: when enabled, a silent local pipeline reads the
// casted stream's ICY tags because the receiver exposes no metadata.
private Elmish.Cmd<Gradio.Message>? start_cast_metadata_if_enabled (
        Gradio.AppModel model, Gradio.Commands commands) {
    if (!model.config.cast_track_titles || model.current_stream_url == "" ||
            model.cast_device_id == null || model.cast_device_id == "")
        return null;
    return commands.start_cast_metadata (model.cast_device_id,
        model.current_stream_url);
}

private Elmish.Cmd<Gradio.Message>? apply_stream_metadata (Gradio.AppModel model,
        Gradio.Commands commands, string title) {
    model.stream_title = title;
    model.track_history = PlaybackLifecycle.push_track_title (
        model.track_history, title, PlaybackLifecycle.TRACK_HISTORY_LIMIT);
    if (model.config.notifications_enabled && model.current_station != null &&
            title != "" && title != model.last_notified_title) {
        model.last_notified_title = title;
        return commands.notify_now_playing (model.current_station.name, title);
    }
    return null;
}

private Elmish.Cmd<Gradio.Message>? update_player_error (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var error = msg as PlayerErrorMessage;
    if (error == null)
        return null;
    if (model.playback_target == PlaybackTarget.CAST)
        return null;
    model.playing = false;
    model.playback_failed = true;
    model.playback_stopped = true;
    model.stream_title = "";
    model.stream_bitrate = 0;
    model.player_status = error.message;
    var release = commands.release_sleep ();
    var notify = model.config.notifications_enabled
        ? commands.notify_error (error.message)
        : null;
    if (model.window_hidden)
        return stop_and_leave_background (model, commands,
            Commands.chain (release, notify));
    return Commands.chain (release, notify);
}

private Elmish.Cmd<Gradio.Message>? update_player_reconnecting (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var reconnecting = msg as PlayerReconnectingMessage;
    if (reconnecting == null)
        return null;
    if (model.playback_target == PlaybackTarget.CAST)
        return null;
    model.playing = false;
    model.playback_failed = false;
    model.stream_title = "";
    model.stream_bitrate = 0;
    model.player_status = reconnecting.message;
    return commands.release_sleep ();
}

private Elmish.Cmd<Gradio.Message>? update_request_favicons (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    return commands.load_favicons (stations_for_favicons (model));
}

private Elmish.Cmd<Gradio.Message>? update_favicon_loaded (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var loaded = msg as FaviconLoadedMessage;
    if (loaded == null)
        return null;
    var station = find_station (model, loaded.station_id);
    if (station == null || station.favicon != loaded.url)
        return null;
    model.favicon_sources.set (loaded.station_id, loaded.url);
    model.favicons.set (loaded.station_id, loaded.path);
    return null;
}

private Elmish.Cmd<Gradio.Message>? update_favicon_discovered (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var discovered = msg as FaviconDiscoveredMessage;
    if (discovered == null)
        return null;
    var known = model.config.find_station (discovered.station_id);
    if (known == null || known.favicon != "" || !Http.is_valid_url (discovered.url))
        return null;
    known.favicon = discovered.url;
    return commands.save_config ();
}

private Elmish.Cmd<Gradio.Message>? update_clear_favicon_cache (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    model.favicons.remove_all ();
    model.favicon_sources.remove_all ();
    model.status_message = _("Favicon cache cleared");
    return Commands.chain (commands.clear_favicon_cache (),
        commands.load_favicons (stations_for_favicons (model)));
}

private Elmish.Cmd<Gradio.Message>? update_show_details (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var show = msg as ShowDetailsMessage;
    if (show == null)
        return null;
    var station = show.station ?? model.current_station;
    model.details_station = station;
    model.details_visible = station != null;
    return null;
}

private Elmish.Cmd<Gradio.Message>? update_hide_details (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    model.details_visible = false;
    return null;
}

private Elmish.Cmd<Gradio.Message>? update_restore_last_station (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    return restore_last_station (model, commands);
}

private Elmish.Cmd<Gradio.Message>? restore_last_station (Gradio.AppModel model,
        Gradio.Commands commands) {
    if (!model.config.resume_playback || model.config.last_station_id == "")
        return null;
    var last_station = model.config.find_station (model.config.last_station_id);
    if (last_station == null)
        return null;
    if (model.playback_target == PlaybackTarget.CAST && model.cast_device_id != null)
        // The startup probe may adopt a live session; if it finds none, this
        // flag makes the restore re-cast once.
        model.cast_resume_pending = true;
    return updateModel (new PlayStationMessage (last_station), model, commands);
}

private Elmish.Cmd<Gradio.Message>? update_sync_cast_session (
        Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    if (model.cast_device_id == null || model.cast_device_id == "" ||
            model.cast_device_host == "")
        return restore_last_station (model, commands);
    model.cast_remote_label = "";
    model.cast_pending_label = "";
    var probe = commands.sync_cast (model.cast_device_id, model.cast_device_host,
        model.cast_port);
    if (model.playback_target != PlaybackTarget.CAST) {
        // Local output does not need to wait for the probe. Start the restore
        // now; a live cast session detected in parallel is shown as remote.
        return Commands.chain (restore_last_station (model, commands), probe);
    }
    return probe;
}

private Elmish.Cmd<Gradio.Message>? update_cast_session_detected (
        Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var detected = msg as CastSessionDetectedMessage;
    if (detected == null || detected.device_id != model.cast_device_id)
        return null;
    // The probe result must resolve the reconnect either way: no controllable
    // session is a real loss, an adoptable one falls through to the adoption
    // below even when the status still reads CONNECTING.
    if (model.cast_reconnecting) {
        bool adoptable = detected.content_id != "" &&
            CastService.is_http_url (detected.content_id);
        if (!adoptable)
            return updateModel (new CastLostMessage (detected.device_id,
                _("Device disconnected")), model, commands);
    } else if (model.cast_attached ||
            (model.playback_target == PlaybackTarget.CAST &&
             model.cast_status == CastStatus.CONNECTING)) {
        // The user started casting while the probe was in flight: never
        // replace the station that is currently connecting with an older
        // detected session.
        return null;
    }
    if (detected.content_id == "") {
        if (detected.player_state == "") {
            // Nothing is playing on the device. Do not restart a local
            // stream that the parallel startup restore already started.
            if (model.playing || model.cast_attached)
                return null;
            return restore_last_station (model, commands);
        }
        // A live session whose URL is not exposed: show it, never re-LOAD.
        model.cast_remote_label = cast_remote_label (detected);
        return null;
    }
    if (!CastService.is_http_url (detected.content_id)) {
        model.cast_remote_label = cast_remote_label (detected);
        return null;
    }
    if (model.playback_target != PlaybackTarget.CAST && model.playing) {
        // Local playback is running: report the session without hijacking it
        // or adding an unrequested station to the library.
        model.cast_remote_label = cast_remote_label (detected);
        return null;
    }
    var station = model.config.find_station_by_url (detected.content_id);
    Elmish.Cmd<Gradio.Message>? add = null;
    if (station == null) {
        station = make_cast_station (detected);
        model.config.add_station (station);
        model.invalidate_library_order ();
        add = commands.save_config ();
    }
    // Nothing is playing locally, so a live session on the configured device
    // is adopted even if the last output was local.
    bool same_stream = model.current_stream_url == detected.content_id;
    model.playback_target = PlaybackTarget.CAST;
    model.config.cast_mode = true;
    model.current_station = station;
    model.current_stream_url = detected.content_id;
    model.config.last_station_id = station.id;
    model.playback_stopped = false;
    model.playback_failed = false;
    // The socket stays down until the adoption lands, so a re-attach must keep
    // saying so instead of dropping back to the station's secondary text.
    if (!model.cast_reconnecting)
        model.player_status = "";
    // Most receivers expose no metadata: an empty probe title never erases the
    // ICY title already shown for the same stream.
    if (detected.title != "") {
        model.stream_title = detected.title;
        model.last_notified_title = detected.title;
    } else if (!same_stream) {
        model.stream_title = "";
        model.last_notified_title = "";
    }
    model.stream_bitrate = 0;
    model.cast_status = CastStatus.CONNECTING;
    model.cast_error = "";
    model.cast_remote_label = "";
    // Promote to the popover label only if adoption actually fails.
    model.cast_pending_label = cast_remote_label (detected);
    model.playing = true;
    var adopt = commands.adopt_cast (model.cast_device_id,
        cast_host_for (model), cast_port_for (model), detected.content_id);
    return Commands.chain (add ?? commands.save_config (),
        Commands.chain (adopt, commands.inhibit_sleep ()));
}

private Elmish.Cmd<Gradio.Message>? update_cast_adopted (
        Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var adopted = msg as CastAdoptedMessage;
    if (adopted == null || adopted.device_id != model.cast_device_id)
        return null;
    model.cast_attached = true;
    // A re-attach stopped the poller, so it must be restarted even when a title
    // is already shown; a running one would not re-emit the title it remembers.
    bool reattached = model.cast_reconnecting;
    model.cast_reconnecting = false;
    model.cast_remote_label = "";
    model.cast_pending_label = "";
    model.cast_resume_pending = false;
    model.cast_retry_on_discovery = false;
    model.playback_stopped = false;
    model.playback_failed = false;
    model.cast_error = "";
    model.player_status = adopted.player_state == "PAUSED"
        ? _("Paused on cast device") : "";
    model.cast_status = cast_status_for_player_state (adopted.player_state);
    model.playing = adopted.player_state != "PAUSED" &&
        adopted.player_state != "IDLE";
    // A live adopted session gets the silent metadata reader right away.
    Elmish.Cmd<Gradio.Message>? metadata = null;
    if (model.playing) {
        var start = start_cast_metadata_if_enabled (model, commands);
        metadata = (reattached || model.stream_title == "")
            ? Commands.chain (commands.stop_cast_metadata (), start)
            : start;
    }
    var sleep = model.playing
        ? commands.inhibit_sleep () : commands.release_sleep ();
    return Commands.chain (sleep, metadata);
}

private Elmish.Cmd<Gradio.Message>? update_cast_adopt_failed (
        Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var failed = msg as CastAdoptFailedMessage;
    if (failed == null || failed.device_id != model.cast_device_id)
        return null;
    if (model.cast_reconnecting)
        return updateModel (new CastLostMessage (failed.device_id,
            _("Cast connection lost")), model, commands);
    bool was_cast = model.playback_target == PlaybackTarget.CAST;
    model.cast_status = CastStatus.READY;
    model.cast_attached = false;
    if (was_cast) {
        model.playing = false;
        model.playback_stopped = true;
        model.player_status = "";
        model.stream_title = "";
        model.stream_bitrate = 0;
        model.last_notified_title = "";
    }
    model.cast_resume_pending = false;
    model.cast_retry_on_discovery = false;
    // The remote session cannot be controlled, so return to the local output.
    // Keep the detection label as show-only; never re-LOAD a stream that may
    // still be playing on the device.
    model.playback_target = PlaybackTarget.LOCAL;
    model.config.cast_mode = false;
    if (model.cast_pending_label != "")
        model.cast_remote_label = model.cast_pending_label;
    model.cast_pending_label = "";
    return Commands.chain (commands.save_config (),
        Commands.chain (commands.stop_cast_metadata (),
            was_cast ? commands.release_sleep () : null));
}

private CastStatus cast_status_for_player_state (string state) {
    switch (state) {
        case "PAUSED":
            return CastStatus.PAUSED;
        case "BUFFERING":
            return CastStatus.BUFFERING;
        default:
            return CastStatus.PLAYING;
    }
}

private RadioStation make_cast_station (CastSessionDetectedMessage detected) {
    var station = new RadioStation ();
    station.id = RadioStation.new_local_id ();
    station.name = detected.title != "" ? detected.title
        : station_name_for_url (detected.content_id);
    station.url = detected.content_id;
    station.original_url = detected.content_id;
    station.is_local = true;
    return station;
}

private string station_name_for_url (string url) {
    try {
        var uri = Uri.parse (url, UriFlags.NONE);
        if (uri != null) {
            var host = uri.get_host ();
            var path = uri.get_path ();
            if (host != "")
                return path == "" || path == "/" ? host : host + path;
        }
    } catch (GLib.Error e) {
    }
    return url;
}

private string cast_remote_label (CastSessionDetectedMessage detected) {
    var app = detected.app_name != "" ? detected.app_name : _("cast device");
    if (detected.title != "")
        return _("%s is casting: %s").printf (app, detected.title);
    if (detected.player_state == "PAUSED")
        return _("%s is casting (paused)").printf (app);
    return _("%s is casting").printf (app);
}

private Elmish.Cmd<Gradio.Message>? update_set_cast_track_titles_interval (
        Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var set = msg as SetCastTrackTitlesIntervalMessage;
    if (set == null)
        return null;
    int seconds = AppConfig.normalize_track_titles_interval (set.seconds);
    if (seconds == model.config.cast_track_titles_interval)
        return null;
    model.config.cast_track_titles_interval = seconds;
    var save = commands.save_config ();
    if (model.config.cast_track_titles && model.cast_attached && model.playing)
        return Commands.chain (save,
            commands.set_cast_metadata_interval (seconds));
    return save;
}

private Elmish.Cmd<Gradio.Message>? update_set_cast_keep_on_quit (
        Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var set = msg as SetCastKeepOnQuitMessage;
    if (set == null || set.enabled == model.config.cast_keep_on_quit)
        return null;
    model.config.cast_keep_on_quit = set.enabled;
    return commands.save_config ();
}

private Elmish.Cmd<Gradio.Message>? update_set_cast_track_titles (
        Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var set = msg as SetCastTrackTitlesMessage;
    if (set == null || set.enabled == model.config.cast_track_titles)
        return null;
    model.config.cast_track_titles = set.enabled;
    var save = commands.save_config ();
    if (!set.enabled) {
        // Do not leave the last ICY title on screen after the poller stops.
        if (model.cast_attached || model.cast_is_active ())
            model.stream_title = "";
        model.last_notified_title = "";
        return Commands.chain (save, commands.stop_cast_metadata ());
    }
    if (model.cast_attached && model.playing)
        return Commands.chain (save, start_cast_metadata_if_enabled (model, commands));
    return save;
}

private Elmish.Cmd<Gradio.Message>? update_window_geometry (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var geometry = msg as WindowGeometryChangedMessage;
    if (geometry == null)
        return null;
    if (geometry.width < AppConfig.MIN_WINDOW_WIDTH ||
            geometry.width > AppConfig.MAX_WINDOW_SIZE ||
            geometry.height < AppConfig.MIN_WINDOW_HEIGHT ||
            geometry.height > AppConfig.MAX_WINDOW_SIZE)
        return null;
    model.config.window_width = geometry.width;
    model.config.window_height = geometry.height;
    model.config.maximized = geometry.maximized;
    return commands.save_config ();
}

private Elmish.Cmd<Gradio.Message>? update_set_icon_size (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var icon_size = msg as SetIconSizeMessage;
    if (icon_size == null)
        return null;
    int size = AppConfig.normalize_icon_size (icon_size.size);
    if (size == model.config.icon_size)
        return null;
    model.config.icon_size = size;
    return commands.save_config ();
}

private Elmish.Cmd<Gradio.Message>? update_window_close_requested (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    if (PlaybackLifecycle.should_background_on_close (
            model.config.background_playback, model.playing)) {
        model.window_hidden = true;
        return commands.background_on_close ();
    }
    model.window_hidden = false;
    return commands.quit_application ();
}

private Elmish.Cmd<Gradio.Message>? update_window_raised (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    model.window_hidden = false;
    return null;
}

private Elmish.Cmd<Gradio.Message>? update_vote_station (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var vote = msg as VoteStationMessage;
    if (vote == null || vote.station_id == "")
        return null;
    if (model.voted_ids.contains (vote.station_id) ||
            model.votes_pending.contains (vote.station_id))
        return null;
    var votable = find_station (model, vote.station_id);
    if (votable == null) {
        model.status_message = _("Station not found");
        return null;
    }
    if (votable.is_local) {
        model.status_message = _("Local stations cannot be voted for");
        return null;
    }
    model.votes_pending.set (vote.station_id, true);
    model.status_message = _("Voting…");
    return commands.vote (vote.station_id);
}

private Elmish.Cmd<Gradio.Message>? update_vote_succeeded (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var voted = msg as VoteSucceededMessage;
    if (voted == null)
        return null;
    model.votes_pending.remove (voted.station_id);
    model.voted_ids.set (voted.station_id, true);
    var voted_station = find_station (model, voted.station_id);
    if (voted_station != null) {
        if (voted.station != null)
            voted_station.votes = voted.station.votes;
        else
            voted_station.votes++;
    }
    model.status_message = _("Thanks for voting");
    return null;
}

private Elmish.Cmd<Gradio.Message>? update_vote_failed (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var vote_error = msg as VoteFailedMessage;
    if (vote_error == null)
        return null;
    model.votes_pending.remove (vote_error.station_id);
    model.status_message = vote_error.message;
    return null;
}

private Elmish.Cmd<Gradio.Message>? update_discover_cast_devices (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    // Do not replace a live cast state with DISCOVERING: the results and the
    // failure path would otherwise make an audible session look inactive.
    if (model.cast_is_active () || model.cast_attached)
        return null;
    model.cast_status = CastStatus.DISCOVERING;
    model.cast_error = "";
    return commands.discover_cast ();
}

private Elmish.Cmd<Gradio.Message>? update_cast_devices_discovered (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var discovered = msg as CastDevicesDiscoveredMessage;
    if (discovered == null)
        return null;
    model.cast_devices = discovered.devices;
    if (model.cast_retry_on_discovery) {
        model.cast_retry_on_discovery = false;
        // The user switched to local playback while discovery was in flight.
        if (model.playback_target != PlaybackTarget.CAST) {
            model.cast_resume_pending = false;
            return null;
        }
        CastDevice? device = null;
        foreach (var candidate in model.cast_devices) {
            if (candidate.id == model.cast_device_id) {
                device = candidate;
                break;
            }
        }
        if (device != null && model.current_stream_url != "") {
            model.cast_device_host = device.host;
            model.cast_port = device.port > 0 ? device.port : 8009;
            model.config.cast_host = model.cast_device_host;
            model.config.cast_port = model.cast_port;
            model.cast_status = CastStatus.CONNECTING;
            model.cast_error = "";
            model.cast_attached = false;
            // A fresh cast connects again, so a stale re-attach flag would keep
            // the controls inert.
            model.cast_reconnecting = false;
            model.playing = true;
            model.playback_stopped = false;
            model.playback_failed = false;
            model.player_status = _("Connecting…");
            return Commands.chain (commands.save_config (),
                Commands.chain (commands.cast (device.id, device.host,
                    model.cast_port, model.current_stream_url),
                    commands.inhibit_sleep ()));
        }
        model.cast_status = CastStatus.FAILED;
        model.cast_error = device != null
            ? _("Nothing is playing") : _("Cast device not found");
        model.playing = false;
        model.playback_stopped = true;
        model.player_status = model.cast_error;
        return commands.release_sleep ();
    }
    // A preserved state (PLAYING, PAUSED, BUFFERING, CONNECTING, LOST) keeps
    // its reason; only a recomputed state clears it.
    if (model.cast_status != CastStatus.PLAYING &&
            model.cast_status != CastStatus.BUFFERING &&
            model.cast_status != CastStatus.CONNECTING &&
            model.cast_status != CastStatus.PAUSED &&
            model.cast_status != CastStatus.LOST) {
        model.cast_status = model.cast_devices.length > 0
            ? CastStatus.READY : CastStatus.IDLE;
        model.cast_error = "";
    }
    return null;
}

private Elmish.Cmd<Gradio.Message>? update_cast_discovery_failed (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var failed = msg as CastDiscoveryFailedMessage;
    if (model.cast_is_active () || model.cast_attached)
        return null;
    bool retry = model.cast_retry_on_discovery;
    model.cast_status = CastStatus.FAILED;
    model.cast_error = failed != null ? failed.error : _("Cast discovery failed");
    model.cast_retry_on_discovery = false;
    model.cast_resume_pending = false;
    // A failed auto-resume holds the inhibitor for the retry; release it now.
    if (retry)
        return commands.release_sleep ();
    return null;
}

private Elmish.Cmd<Gradio.Message>? update_select_cast_device (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var selected = msg as SelectCastDeviceMessage;
    if (selected == null)
        return null;
    // Changing the identity mid-cast would drop later loss messages from the
    // device that is actually playing.
    if (model.cast_is_active () || model.cast_attached)
        return null;
    model.cast_device_id = selected.device_id;
    model.cast_device_name = selected.device_name;
    model.cast_device_host = selected.device_host;
    model.cast_port = selected.device_port > 0 ? selected.device_port : 8009;
    model.cast_attached = false;
    model.cast_device_volume = -1.0;
    model.cast_remote_label = "";
    model.config.cast_device_id = model.cast_device_id;
    model.config.cast_device_name = model.cast_device_name;
    model.config.cast_host = model.cast_device_host;
    model.config.cast_port = model.cast_port;
    if (model.cast_status != CastStatus.PLAYING &&
            model.playback_target != PlaybackTarget.CAST)
        model.cast_status = CastStatus.READY;
    return commands.save_config ();
}

private Elmish.Cmd<Gradio.Message>? update_cast_to_selected (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    if (model.cast_device_id == null || model.cast_device_id == "") {
        model.cast_status = CastStatus.FAILED;
        model.cast_error = _("Select a device first");
        return null;
    }
    if (model.current_stream_url == "") {
        model.cast_status = CastStatus.FAILED;
        model.cast_error = _("Nothing is playing");
        return null;
    }
    var host = cast_host_for (model);
    var port = cast_port_for (model);
    if (host == "") {
        model.cast_status = CastStatus.FAILED;
        model.cast_error = _("Device address is unknown. Discover devices again.");
        return null;
    }
    model.playback_target = PlaybackTarget.CAST;
    model.config.cast_mode = true;
    model.cast_status = CastStatus.CONNECTING;
    model.cast_reconnecting = false;
    model.cast_reconnect_attempts = 0;
    model.cast_device_volume = -1.0;
    model.cast_error = "";
    model.cast_remote_label = "";
    model.cast_pending_label = "";
    model.playing = true;
    model.playback_stopped = false;
    model.playback_failed = false;
    model.player_status = _("Connecting…");
    return Commands.chain (commands.save_config (),
        Commands.chain (commands.stop (),
            Commands.chain (commands.cast (model.cast_device_id, host, port,
                model.current_stream_url), commands.inhibit_sleep ())));
}

private Elmish.Cmd<Gradio.Message>? update_cast_started (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var started = msg as CastStartedMessage;
    if (started == null || started.device_id != model.cast_device_id)
        return null;
    model.cast_status = CastStatus.PLAYING;
    model.playing = true;
    model.player_status = "";
    model.cast_attached = true;
    model.cast_resume_pending = false;
    model.cast_retry_on_discovery = false;
    model.cast_reconnecting = false;
    return Commands.chain (commands.inhibit_sleep (),
        start_cast_metadata_if_enabled (model, commands));
}

private Elmish.Cmd<Gradio.Message>? update_cast_stopped (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    // A stop from an earlier session must not tear down the current one.
    var stopped = msg as CastStoppedMessage;
    if (stopped == null || stopped.device_id != model.cast_device_id)
        return null;
    bool was_cast = model.playback_target == PlaybackTarget.CAST;
    bool had_cast_mode = model.config.cast_mode;
    model.cast_status = CastStatus.STOPPED;
    model.cast_attached = false;
    model.cast_reconnecting = false;
    model.cast_reconnect_attempts = 0;
    model.cast_device_volume = -1.0;
    model.cast_remote_label = "";
    model.cast_pending_label = "";
    model.cast_resume_pending = false;
    model.cast_retry_on_discovery = false;
    model.cast_error = "";
    // The stop command can complete after PlayLocal already started the local
    // player; only tear down playback when the cast was still the target.
    if (was_cast) {
        model.playing = false;
        model.playback_stopped = true;
        model.stream_title = "";
        model.stream_bitrate = 0;
        model.player_status = "";
    }
    // Stopped is a stop, not a loss: return to local output so Play starts
    // locally instead of reviving the finished cast.
    model.playback_target = PlaybackTarget.LOCAL;
    model.config.cast_mode = false;
    var save = had_cast_mode ? commands.save_config () : null;
    var stop_meta = commands.stop_cast_metadata ();
    if (was_cast)
        return Commands.chain (save,
            Commands.chain (stop_meta, commands.release_sleep ()));
    return Commands.chain (save, stop_meta);
}

private Elmish.Cmd<Gradio.Message>? update_cast_failed (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    // A failure from an earlier session must not clear the current one's state.
    var failed = msg as CastFailedMessage;
    if (failed == null || failed.device_id != model.cast_device_id)
        return null;
    bool casting = model.playback_target == PlaybackTarget.CAST;
    model.cast_status = CastStatus.FAILED;
    model.cast_attached = false;
    model.cast_reconnecting = false;
    model.cast_reconnect_attempts = 0;
    model.cast_device_volume = -1.0;
    model.cast_error = failed.error;
    if (casting) {
        model.playing = false;
        model.playback_stopped = true;
        model.stream_title = "";
        model.stream_bitrate = 0;
        model.player_status = "";
        model.cast_remote_label = "";
        model.cast_pending_label = "";
    }
    bool retry = model.cast_resume_pending;
    model.cast_resume_pending = false;
    Elmish.Cmd<Gradio.Message> stop_meta = commands.stop_cast_metadata ();
    if (casting && retry && model.cast_device_id != null) {
        model.cast_retry_on_discovery = true;
        model.cast_status = CastStatus.DISCOVERING;
        model.cast_error = "";
        return Commands.chain (stop_meta, commands.discover_cast ());
    }
    if (casting)
        return Commands.chain (stop_meta, commands.release_sleep ());
    return stop_meta;
}

private Elmish.Cmd<Gradio.Message>? update_cast_lost (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var lost = msg as CastLostMessage;
    if (lost == null || model.playback_target != PlaybackTarget.CAST ||
            lost.device_id != model.cast_device_id)
        return null;
    model.cast_status = CastStatus.LOST;
    model.cast_attached = false;
    model.cast_reconnecting = false;
    model.cast_reconnect_attempts = 0;
    model.cast_device_volume = -1.0;
    model.cast_error = lost.error;
    // The auto-resume attempt is over: a later cast failure must not trigger
    // another discovery round.
    model.cast_resume_pending = false;
    model.cast_retry_on_discovery = false;
    if (model.config.cast_loss_action == CastLossAction.PLAY_LOCAL &&
            model.current_station != null) {
        model.playback_target = PlaybackTarget.LOCAL;
        model.config.cast_mode = false;
        model.playing = true;
        model.playback_stopped = false;
        model.playback_failed = false;
        model.stream_title = "";
        model.stream_bitrate = 0;
        model.player_status = _("Connecting…");
        model.cast_remote_label = "";
        model.cast_pending_label = "";
        return Commands.chain (commands.stop_cast_metadata (),
            Commands.chain (commands.save_config (),
                Commands.chain (commands.play (model.current_station),
                    commands.inhibit_sleep ())));
    }
    model.playing = false;
    model.playback_stopped = true;
    model.playback_failed = false;
    model.stream_title = "";
    model.stream_bitrate = 0;
    model.player_status = lost.error;
    model.cast_remote_label = "";
    model.cast_pending_label = "";
    return Commands.chain (commands.stop_cast_metadata (),
        commands.release_sleep ());
}

// The sender socket dropped, but the receiver may still be playing: probe and
// re-attach instead of tearing the cast down.
private Elmish.Cmd<Gradio.Message>? update_cast_sender_lost (
        Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var lost = msg as CastSenderLostMessage;
    if (lost == null || model.playback_target != PlaybackTarget.CAST ||
            lost.device_id != model.cast_device_id ||
            !(model.cast_is_active () || model.cast_attached))
        return null;
    // Count quick consecutive drops: a receiver that kills each new sender is
    // not coming back, and retrying would leave every control inert.
    int64 now = lost.at_us;
    if (now - model.cast_reconnect_last_us > CAST_RECONNECT_STREAK_US)
        model.cast_reconnect_attempts = 0;
    model.cast_reconnect_last_us = now;
    model.cast_reconnect_attempts++;
    if (model.cast_reconnect_attempts > MAX_CAST_RECONNECTS) {
        model.cast_reconnect_attempts = 0;
        return updateModel (new CastLostMessage (lost.device_id,
            _("Device disconnected")), model, commands);
    }
    model.cast_attached = false;
    model.cast_device_volume = -1.0;
    model.cast_reconnecting = true;
    model.cast_error = "";
    model.player_status = _("Reconnecting…");
    // Stop the reader on the old URL: the receiver may switch streams, and the
    // poller would otherwise publish a stale title. Adoption restarts it.
    return Commands.chain (commands.stop_cast_metadata (),
        commands.sync_cast (model.cast_device_id, cast_host_for (model),
            cast_port_for (model)));
}

private Elmish.Cmd<Gradio.Message>? update_cast_volume (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var volume = msg as CastVolumeMessage;
    if (volume == null || volume.device_id != model.cast_device_id)
        return null;
    if (!(model.cast_is_active () || model.cast_attached))
        return null;
    double level = volume.volume.clamp (0.0, 1.0);
    // A duplicate report carries no new information. Everything else is the
    // receiver's truth: comparing against what we asked for would silently drop
    // a one-step change made on another sender.
    bool repeat = model.cast_attached && model.cast_device_volume >= 0.0 &&
        Math.fabs (level - model.cast_device_volume) < CAST_VOLUME_REPEAT_EPSILON &&
        Math.fabs (model.config.volume - level) < CAST_VOLUME_REPEAT_EPSILON;
    model.cast_device_volume = level;
    if (repeat)
        return null;
    model.config.volume = level;
    // Keep the local player in step, but never push it back to the receiver.
    return commands.set_volume (level);
}

private Elmish.Cmd<Gradio.Message>? update_cast_paused (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var paused = msg as CastPausedMessage;
    if (paused == null || model.playback_target != PlaybackTarget.CAST ||
            paused.device_id != model.cast_device_id)
        return null;
    model.cast_attached = true;
    model.cast_reconnecting = false;
    model.cast_status = CastStatus.PAUSED;
    model.playing = false;
    model.playback_stopped = false;
    model.player_status = _("Paused on cast device");
    var stop_meta = commands.stop_cast_metadata ();
    return Commands.chain (stop_meta, commands.release_sleep ());
}

private Elmish.Cmd<Gradio.Message>? update_cast_buffering (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    var buffering = msg as CastBufferingMessage;
    if (buffering == null || model.playback_target != PlaybackTarget.CAST ||
            buffering.device_id != model.cast_device_id)
        return null;
    model.cast_status = CastStatus.BUFFERING;
    model.cast_attached = true;
    model.cast_reconnecting = false;
    model.playing = true;
    model.playback_stopped = false;
    model.player_status = _("Buffering…");
    // The media session is live again (possibly after a pause), so keep the
    // inhibitor held and resume the metadata reader.
    model.cast_resume_pending = false;
    return Commands.chain (commands.inhibit_sleep (),
        start_cast_metadata_if_enabled (model, commands));
}

private Elmish.Cmd<Gradio.Message>? update_stop_cast (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    // Nothing reaches the receiver mid-re-attach: a teardown would orphan it.
    if (model.cast_reconnecting)
        return null;
    if (model.cast_device_id == null || model.cast_device_id == "")
        return null;
    model.playing = false;
    model.playback_stopped = true;
    model.playback_failed = false;
    model.stream_title = "";
    model.stream_bitrate = 0;
    model.player_status = "";
    model.cast_status = CastStatus.STOPPED;
    model.cast_attached = false;
    model.cast_remote_label = "";
    model.cast_pending_label = "";
    model.cast_resume_pending = false;
    model.cast_retry_on_discovery = false;
    model.cast_error = "";
    model.playback_target = PlaybackTarget.LOCAL;
    model.config.cast_mode = false;
    return Commands.chain (commands.stop_cast_metadata (),
        Commands.chain (commands.save_config (),
            Commands.chain (commands.stop_cast (model.cast_device_id,
                cast_host_for (model), cast_port_for (model)),
                commands.release_sleep ())));
}

private string cast_host_for (Gradio.AppModel model) {
    if (model.cast_device_host != "")
        return model.cast_device_host;
    foreach (var device in model.cast_devices) {
        if (device.id == model.cast_device_id)
            return device.host;
    }
    return "";
}

private int cast_port_for (Gradio.AppModel model) {
    if (model.cast_device_host != "")
        return model.cast_port;
    foreach (var device in model.cast_devices) {
        if (device.id == model.cast_device_id && device.port > 0)
            return device.port;
    }
    return model.cast_port;
}

private Elmish.Cmd<Gradio.Message>? update_play_local (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    // Nothing reaches the receiver mid-re-attach: local playback would double up.
    if (model.cast_reconnecting)
        return null;
    var was_cast = model.playback_target == PlaybackTarget.CAST;
    bool had_cast_mode = model.config.cast_mode;
    model.playback_target = PlaybackTarget.LOCAL;
    model.config.cast_mode = false;
    model.cast_status = CastStatus.IDLE;
    model.cast_attached = false;
    model.cast_resume_pending = false;
    model.cast_retry_on_discovery = false;
    model.cast_remote_label = "";
    model.cast_pending_label = "";
    model.cast_error = "";
    var save = had_cast_mode ? commands.save_config () : null;
    var stop_meta = commands.stop_cast_metadata ();
    var stop_cast_cmd = was_cast && model.cast_device_id != null
        ? commands.stop_cast (model.cast_device_id, cast_host_for (model),
            cast_port_for (model)) : null;
    if (model.current_station == null)
        return Commands.chain (stop_meta, Commands.chain (save, stop_cast_cmd));
    model.playing = true;
    model.playback_stopped = false;
    model.playback_failed = false;
    model.player_status = _("Connecting…");
    return Commands.chain (stop_meta,
        Commands.chain (save,
            Commands.chain (stop_cast_cmd,
                Commands.chain (commands.play (model.current_station),
                    commands.inhibit_sleep ()))));
}
