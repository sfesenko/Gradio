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
    MOVE_STATION,
    PLAY_STATION,
    TOGGLE_PLAY,
    PLAYER_STATE_CHANGED,
    PLAYER_METADATA_CHANGED,
    PLAYER_ERROR,
    SHOW_DETAILS,
    HIDE_DETAILS,
    SET_VOLUME,
    SET_SHOW_TECHNICAL_INFO,
    CONFIG_SAVE_FAILED,
    REQUEST_FAVICONS,
    FAVICON_LOADED,
    CLEAR_FAVICON_CACHE,
    WINDOW_GEOMETRY_CHANGED,
    SET_ICON_SIZE,
    SET_SEARCH_SORT_MODE,
    SET_SEARCH_FILTER,
    FAVICON_DISCOVERED
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

public class Gradio.MoveStationMessage : Gradio.Message {
    public string station_id;
    public string target_id;
    public bool after;

    public MoveStationMessage (string station_id, string target_id, bool after) {
        this.station_id = station_id;
        this.target_id = target_id;
        this.after = after;
    }

    public override MessageKind kind { get { return MessageKind.MOVE_STATION; } }
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

public class Gradio.RequestFaviconsMessage : Gradio.Message {
    public override MessageKind kind { get { return MessageKind.REQUEST_FAVICONS; } }
}

public class Gradio.FaviconLoadedMessage : Gradio.Message {
    public string station_id;
    public string url;
    public string path;

    public FaviconLoadedMessage (string station_id, string url, string path) {
        this.station_id = station_id;
        this.url = url;
        this.path = path;
    }

    public override MessageKind kind { get { return MessageKind.FAVICON_LOADED; } }
}

public class Gradio.FaviconDiscoveredMessage : Gradio.Message {
    public string station_id;
    public string url;

    public FaviconDiscoveredMessage (string station_id, string url) {
        this.station_id = station_id;
        this.url = url;
    }

    public override MessageKind kind { get { return MessageKind.FAVICON_DISCOVERED; } }
}

public class Gradio.ClearFaviconCacheMessage : Gradio.Message {
    public override MessageKind kind { get { return MessageKind.CLEAR_FAVICON_CACHE; } }
}

public class Gradio.WindowGeometryChangedMessage : Gradio.Message {
    public int width;
    public int height;
    public bool maximized;

    public WindowGeometryChangedMessage (int width, int height, bool maximized) {
        this.width = width;
        this.height = height;
        this.maximized = maximized;
    }

    public override MessageKind kind { get { return MessageKind.WINDOW_GEOMETRY_CHANGED; } }
}

public class Gradio.SetIconSizeMessage : Gradio.Message {
    public int size;

    public SetIconSizeMessage (int size) { this.size = size; }

    public override MessageKind kind { get { return MessageKind.SET_ICON_SIZE; } }
}

public class Gradio.SetSearchSortModeMessage : Gradio.Message {
    public SearchSortMode mode;

    public SetSearchSortModeMessage (SearchSortMode mode) { this.mode = mode; }

    public override MessageKind kind { get { return MessageKind.SET_SEARCH_SORT_MODE; } }
}

public class Gradio.SetSearchFilterMessage : Gradio.Message {
    public SearchFilterKind field;
    public string value;

    public SetSearchFilterMessage (SearchFilterKind field, string value) {
        this.field = field;
        this.value = value;
    }

    public override MessageKind kind { get { return MessageKind.SET_SEARCH_FILTER; } }
}

public class Gradio.AppModel {
    public ViewMode view = ViewMode.LIBRARY;
    public AppConfig config;
    public GLib.GenericArray<RadioStation> search_results = new GLib.GenericArray<RadioStation> ();
    public string search_query = "";
    public bool search_active = false;
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
    public GLib.HashTable<string, string> favicons = new GLib.HashTable<string, string> (str_hash, str_equal);
    public GLib.HashTable<string, string> favicon_sources = new GLib.HashTable<string, string> (str_hash, str_equal);

    public AppModel (AppConfig config) {
        this.config = config;
    }

    public string? favicon_for (RadioStation station) {
        if (station.favicon == "")
            return null;
        unowned string? source = favicon_sources.lookup (station.id);
        if (source == null || source != station.favicon)
            return null;
        unowned string? path = favicons.lookup (station.id);
        if (path == null || path == "")
            return null;
        return path;
    }
}
