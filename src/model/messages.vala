// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Sergii Fesenko

public enum Gradio.ViewMode {
    LIBRARY,
    ADD_STATION
}

public enum Gradio.MessageKind {
    SET_VIEW,
    SEARCH_REQUESTED,
    SEARCH_RESULTS,
    SEARCH_FAILED,
    ADD_STATION,
    REMOVE_STATION,
    PLAY_STATION,
    TOGGLE_PLAY,
    PLAYER_STATE_CHANGED,
    PLAYER_METADATA_CHANGED,
    PLAYER_ERROR,
    SHOW_DETAILS,
    HIDE_DETAILS,
    SET_VOLUME,
    SET_SHOW_TECHNICAL_INFO,
    CONFIG_SAVE_FAILED
}

public abstract class Gradio.Message {
    public abstract MessageKind kind { get; }
}

public class Gradio.SetViewMessage : Gradio.Message {
    public ViewMode view;
    public SetViewMessage (ViewMode view) { this.view = view; }
    public override MessageKind kind { get { return MessageKind.SET_VIEW; } }
}

public class Gradio.SearchRequestedMessage : Gradio.Message {
    public string query;
    public SearchRequestedMessage (string query) { this.query = query; }
    public override MessageKind kind { get { return MessageKind.SEARCH_REQUESTED; } }
}

public class Gradio.SearchResultsMessage : Gradio.Message {
    public GLib.GenericArray<RadioStation> stations;
    public uint generation;
    public SearchResultsMessage (GLib.GenericArray<RadioStation> stations, uint generation) {
        this.stations = stations;
        this.generation = generation;
    }
    public override MessageKind kind { get { return MessageKind.SEARCH_RESULTS; } }
}

public class Gradio.SearchFailedMessage : Gradio.Message {
    public string message;
    public uint generation;
    public SearchFailedMessage (string message, uint generation) {
        this.message = message;
        this.generation = generation;
    }
    public override MessageKind kind { get { return MessageKind.SEARCH_FAILED; } }
}

public class Gradio.AddStationMessage : Gradio.Message {
    public RadioStation station;
    public AddStationMessage (RadioStation station) { this.station = station; }
    public override MessageKind kind { get { return MessageKind.ADD_STATION; } }
}

public class Gradio.RemoveStationMessage : Gradio.Message {
    public string station_id;
    public RemoveStationMessage (string station_id) { this.station_id = station_id; }
    public override MessageKind kind { get { return MessageKind.REMOVE_STATION; } }
}

public class Gradio.PlayStationMessage : Gradio.Message {
    public RadioStation station;
    public PlayStationMessage (RadioStation station) { this.station = station; }
    public override MessageKind kind { get { return MessageKind.PLAY_STATION; } }
}

public class Gradio.TogglePlayMessage : Gradio.Message {
    public override MessageKind kind { get { return MessageKind.TOGGLE_PLAY; } }
}

public class Gradio.PlayerStateChangedMessage : Gradio.Message {
    public bool playing;
    public PlayerStateChangedMessage (bool playing) { this.playing = playing; }
    public override MessageKind kind { get { return MessageKind.PLAYER_STATE_CHANGED; } }
}

public class Gradio.PlayerMetadataChangedMessage : Gradio.Message {
    public string title;
    public int bitrate;
    public PlayerMetadataChangedMessage (string title, int bitrate) {
        this.title = title;
        this.bitrate = bitrate;
    }
    public override MessageKind kind { get { return MessageKind.PLAYER_METADATA_CHANGED; } }
}

public class Gradio.PlayerErrorMessage : Gradio.Message {
    public string message;
    public PlayerErrorMessage (string message) { this.message = message; }
    public override MessageKind kind { get { return MessageKind.PLAYER_ERROR; } }
}

public class Gradio.ShowDetailsMessage : Gradio.Message {
    public RadioStation? station;
    public ShowDetailsMessage (RadioStation? station) { this.station = station; }
    public override MessageKind kind { get { return MessageKind.SHOW_DETAILS; } }
}

public class Gradio.HideDetailsMessage : Gradio.Message {
    public override MessageKind kind { get { return MessageKind.HIDE_DETAILS; } }
}

public class Gradio.SetVolumeMessage : Gradio.Message {
    public double volume;
    public SetVolumeMessage (double volume) { this.volume = volume; }
    public override MessageKind kind { get { return MessageKind.SET_VOLUME; } }
}

public class Gradio.SetShowTechnicalInfoMessage : Gradio.Message {
    public bool enabled;
    public SetShowTechnicalInfoMessage (bool enabled) { this.enabled = enabled; }
    public override MessageKind kind { get { return MessageKind.SET_SHOW_TECHNICAL_INFO; } }
}

public class Gradio.ConfigSaveFailedMessage : Gradio.Message {
    public string message;
    public ConfigSaveFailedMessage (string message) { this.message = message; }
    public override MessageKind kind { get { return MessageKind.CONFIG_SAVE_FAILED; } }
}

public class Gradio.AppModel {
    public ViewMode view = ViewMode.LIBRARY;
    public AppConfig config;
    public GLib.GenericArray<RadioStation> search_results = new GLib.GenericArray<RadioStation> ();
    public string search_query = "";
    public bool searching = false;
    public string? search_error = null;
    public uint search_generation = 0;
    public RadioStation? current_station = null;
    public bool playing = false;
    public bool playback_failed = false;
    public string stream_title = "";
    public int stream_bitrate = 0;
    public bool details_visible = false;
    public RadioStation? details_station = null;
    public string status_message = _("Ready");

    public AppModel (AppConfig config) {
        this.config = config;
    }
}
