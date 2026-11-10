// SPDX-License-Identifier: GPL-3.0-or-later

using Gradio;

public Elmish.Cmd<Gradio.Message>? updateModel (Gradio.Message msg, Gradio.AppModel model, Gradio.Commands commands) {
    switch (msg.kind) {
        case MessageKind.SET_VIEW:
            var set_view = msg as SetViewMessage;
            if (set_view == null)
                break;
            bool view_changed = set_view.view != model.view;
            model.view = set_view.view;
            if (view_changed) {
                model.search_generation++;
                if (set_view.view == ViewMode.ADD_STATION) {
                    model.search_query = "";
                    model.search_results = new GLib.GenericArray<RadioStation> ();
                    model.search_error = null;
                    model.searching = false;
                }
            }
            model.details_visible = false;
            break;

        case MessageKind.SEARCH_REQUESTED:
            var requested = msg as SearchRequestedMessage;
            if (requested == null)
                break;
            string query = requested.query.strip ();
            if (query == "") {
                model.search_generation++;
                model.search_query = "";
                model.search_results = new GLib.GenericArray<RadioStation> ();
                model.search_error = null;
                model.searching = false;
                break;
            }
            model.search_generation++;
            model.searching = true;
            model.search_error = null;
            model.search_query = query;
            return commands.search (query, model.search_generation);

        case MessageKind.SEARCH_RESULTS:
            var results = msg as SearchResultsMessage;
            if (results == null || results.generation != model.search_generation)
                break;
            model.search_results = results.stations;
            model.searching = false;
            model.search_error = null;
            break;

        case MessageKind.SEARCH_FAILED:
            var failed = msg as SearchFailedMessage;
            if (failed == null || failed.generation != model.search_generation)
                break;
            model.searching = false;
            model.search_error = failed.message;
            break;

        case MessageKind.ADD_STATION:
            var add = msg as AddStationMessage;
            if (add == null)
                break;
            if (model.config.add_station (add.station)) {
                model.status_message = _("Added %s").printf (add.station.name);
                return commands.save_config ();
            }
            model.status_message = _("Already in library");
            break;

        case MessageKind.REMOVE_STATION:
            var remove = msg as RemoveStationMessage;
            if (remove == null)
                break;
            if (!model.config.remove_station (remove.station_id)) {
                model.status_message = _("Station not found");
                break;
            }

            if (model.details_station != null && model.details_station.id == remove.station_id) {
                model.details_station = null;
                model.details_visible = false;
            }

            bool was_current = model.current_station != null && model.current_station.id == remove.station_id;
            if (was_current) {
                model.current_station = null;
                model.playing = false;
                model.stream_title = "";
                model.stream_bitrate = 0;
                model.details_station = null;
                model.details_visible = false;
                model.status_message = _("Station removed");
                return Commands.chain (commands.stop (), commands.save_config ());
            }

            model.status_message = _("Station removed");
            return commands.save_config ();

        case MessageKind.PLAY_STATION:
            var play = msg as PlayStationMessage;
            if (play == null)
                break;
            model.current_station = play.station;
            model.playing = true;
            model.playback_failed = false;
            model.stream_title = "";
            model.stream_bitrate = 0;
            model.status_message = _("Connecting…");
            return commands.play (play.station);

        case MessageKind.TOGGLE_PLAY:
            if (model.current_station == null)
                break;
            model.playing = !model.playing;
            if (model.playing) {
                model.playback_failed = false;
                model.status_message = _("Connecting…");
                return commands.play (model.current_station);
            }
            model.playback_failed = false;
            model.stream_title = "";
            model.stream_bitrate = 0;
            model.status_message = _("Stopped");
            return commands.stop ();

        case MessageKind.PLAYER_STATE_CHANGED:
            var state = msg as PlayerStateChangedMessage;
            if (state == null)
                break;
            model.playing = state.playing;
            if (state.playing) {
                model.playback_failed = false;
                model.status_message = _("Connected");
            } else {
                model.stream_title = "";
                model.stream_bitrate = 0;
                if (!model.playback_failed)
                    model.status_message = _("Stopped");
            }
            break;

        case MessageKind.PLAYER_METADATA_CHANGED:
            var metadata = msg as PlayerMetadataChangedMessage;
            if (metadata == null)
                break;
            model.stream_title = metadata.title;
            model.stream_bitrate = metadata.bitrate;
            break;

        case MessageKind.PLAYER_ERROR:
            var error = msg as PlayerErrorMessage;
            if (error == null)
                break;
            model.playing = false;
            model.playback_failed = true;
            model.stream_title = "";
            model.stream_bitrate = 0;
            model.status_message = error.message;
            break;

        case MessageKind.SHOW_DETAILS:
            var show = msg as ShowDetailsMessage;
            if (show == null)
                break;
            var station = show.station ?? model.current_station;
            model.details_station = station;
            model.details_visible = station != null;
            break;

        case MessageKind.HIDE_DETAILS:
            model.details_visible = false;
            break;

        case MessageKind.SET_VOLUME:
            var volume = msg as SetVolumeMessage;
            if (volume == null)
                break;
            double clamped = volume.volume.clamp (0.0, 1.0);
            model.config.volume = clamped;
            return commands.set_volume (clamped);

        case MessageKind.SET_SHOW_TECHNICAL_INFO:
            var technical = msg as SetShowTechnicalInfoMessage;
            if (technical == null)
                break;
            model.config.show_technical_info = technical.enabled;
            return commands.save_config ();

        case MessageKind.CONFIG_SAVE_FAILED:
            var save_error = msg as ConfigSaveFailedMessage;
            if (save_error == null)
                break;
            model.status_message = save_error.message;
            break;

        default:
            break;
    }

    return null;
}
