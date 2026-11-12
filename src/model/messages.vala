// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Sergii Fesenko

public enum Gradio.ViewMode {
    LIBRARY,
    ADD_STATION
}

public enum Gradio.DiscoverMode {
    POPULAR,
    NEW
}

public enum Gradio.CastStatus {
    IDLE,
    DISCOVERING,
    READY,
    CONNECTING,
    PLAYING,
    STOPPED,
    FAILED
}

public enum Gradio.PlaybackTarget {
    LOCAL,
    CAST
}

public class Gradio.CastDevice {
    public string id;
    public string name;
    public string host;
    public int port;
    public string model;

    public CastDevice (string id, string name, string host, int port, string model) {
        this.id = id;
        this.name = name;
        this.host = host;
        this.port = port;
        this.model = model;
    }
}

public enum Gradio.MessageKind {
    SET_VIEW,
    SEARCH_REQUESTED,
    SEARCH_RESULTS,
    SEARCH_FAILED,
    ADD_STATION,
    ADD_LOCAL_STATION,
    UPDATE_LOCAL_STATION,
    SET_LIBRARY_SORT,
    REFRESH_LIBRARY,
    LIBRARY_REFRESHED,
    REMOVE_STATION,
    MOVE_STATION,
    PLAY_STATION,
    TOGGLE_PLAY,
    PLAYER_STATE_CHANGED,
    PLAYER_METADATA_CHANGED,
    PLAYER_ERROR,
    PLAYER_RECONNECTING,
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
    FAVICON_DISCOVERED,
    VOTE_STATION,
    VOTE_SUCCEEDED,
    VOTE_FAILED,
    STOP_PLAYBACK,
    IMPORT_STATIONS,
    STATIONS_IMPORTED,
    IMPORT_FAILED,
    EXPORT_STATIONS,
    EXPORT_SUCCEEDED,
    EXPORT_FAILED,
    EXPORT_PLAYLIST,
    SET_RESUME_PLAYBACK,
    RESTORE_LAST_STATION,
    REQUEST_FILTER_OPTIONS,
    FILTER_OPTIONS_LOADED,
    DISCOVER_SERVER,
    SERVER_DISCOVERED,
    SERVER_DISCOVERY_FAILED,
    REQUEST_DISCOVER,
    DISCOVER_RESULTS,
    DISCOVER_FAILED,
    SET_BACKGROUND_PLAYBACK,
    WINDOW_CLOSE_REQUESTED,
    WINDOW_RAISED,
    SET_NOTIFICATIONS,
    SET_SHOW_STATUS_BAR,
    SET_PLAYER_IN_HEADER,
    DISCOVER_CAST_DEVICES,
    CAST_DEVICES_DISCOVERED,
    CAST_DISCOVERY_FAILED,
    SELECT_CAST_DEVICE,
    CAST_TO_SELECTED,
    CAST_STARTED,
    CAST_STOPPED,
    CAST_FAILED,
    STOP_CAST,
    PLAY_LOCAL
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

public class Gradio.AddLocalStationMessage : Gradio.Message {
    public RadioStation station;

    public AddLocalStationMessage (RadioStation station) { this.station = station; }

    public override MessageKind kind { get { return MessageKind.ADD_LOCAL_STATION; } }
}

public class Gradio.UpdateLocalStationMessage : Gradio.Message {
    public RadioStation station;

    public UpdateLocalStationMessage (RadioStation station) { this.station = station; }

    public override MessageKind kind { get { return MessageKind.UPDATE_LOCAL_STATION; } }
}

public class Gradio.SetLibrarySortMessage : Gradio.Message {
    public LibrarySortMode mode;
    public bool descending;

    public SetLibrarySortMessage (LibrarySortMode mode, bool descending) {
        this.mode = mode;
        this.descending = descending;
    }

    public override MessageKind kind { get { return MessageKind.SET_LIBRARY_SORT; } }
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

public class Gradio.RefreshLibraryMessage : Gradio.Message {
    public override MessageKind kind { get { return MessageKind.REFRESH_LIBRARY; } }
}

public class Gradio.LibraryRefreshedMessage : Gradio.Message {
    public GLib.GenericArray<RadioStation> updated;
    public string[] missing_ids;

    public LibraryRefreshedMessage (GLib.GenericArray<RadioStation> updated,
            string[] missing_ids) {
        this.updated = updated;
        this.missing_ids = missing_ids;
    }

    public override MessageKind kind { get { return MessageKind.LIBRARY_REFRESHED; } }
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

public class Gradio.PlayerReconnectingMessage : Gradio.Message {
    public string message;
    public PlayerReconnectingMessage (string message) { this.message = message; }
    public override MessageKind kind { get { return MessageKind.PLAYER_RECONNECTING; } }
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

public class Gradio.VoteStationMessage : Gradio.Message {
    public string station_id;

    public VoteStationMessage (string station_id) { this.station_id = station_id; }

    public override MessageKind kind { get { return MessageKind.VOTE_STATION; } }
}

public class Gradio.VoteSucceededMessage : Gradio.Message {
    public string station_id;
    public RadioStation? station;

    public VoteSucceededMessage (string station_id, RadioStation? station) {
        this.station_id = station_id;
        this.station = station;
    }

    public override MessageKind kind { get { return MessageKind.VOTE_SUCCEEDED; } }
}

public class Gradio.VoteFailedMessage : Gradio.Message {
    public string station_id;
    public string message;

    public VoteFailedMessage (string station_id, string message) {
        this.station_id = station_id;
        this.message = message;
    }

    public override MessageKind kind { get { return MessageKind.VOTE_FAILED; } }
}

public class Gradio.StopPlaybackMessage : Gradio.Message {
    public override MessageKind kind { get { return MessageKind.STOP_PLAYBACK; } }
}

public class Gradio.ImportStationsMessage : Gradio.Message {
    public string path;

    public ImportStationsMessage (string path) { this.path = path; }

    public override MessageKind kind { get { return MessageKind.IMPORT_STATIONS; } }
}

public class Gradio.StationsImportedMessage : Gradio.Message {
    public GLib.GenericArray<RadioStation> stations;

    public StationsImportedMessage (GLib.GenericArray<RadioStation> stations) {
        this.stations = stations;
    }

    public override MessageKind kind { get { return MessageKind.STATIONS_IMPORTED; } }
}

public class Gradio.ImportFailedMessage : Gradio.Message {
    public string message;

    public ImportFailedMessage (string message) { this.message = message; }

    public override MessageKind kind { get { return MessageKind.IMPORT_FAILED; } }
}

public class Gradio.ExportStationsMessage : Gradio.Message {
    public string path;

    public ExportStationsMessage (string path) { this.path = path; }

    public override MessageKind kind { get { return MessageKind.EXPORT_STATIONS; } }
}

public class Gradio.ExportSucceededMessage : Gradio.Message {
    public string path;
    public int count;

    public ExportSucceededMessage (string path, int count) {
        this.path = path;
        this.count = count;
    }

    public override MessageKind kind { get { return MessageKind.EXPORT_SUCCEEDED; } }
}

public class Gradio.ExportFailedMessage : Gradio.Message {
    public string message;

    public ExportFailedMessage (string message) { this.message = message; }

    public override MessageKind kind { get { return MessageKind.EXPORT_FAILED; } }
}

public class Gradio.ExportPlaylistMessage : Gradio.Message {
    public string path;

    public ExportPlaylistMessage (string path) { this.path = path; }

    public override MessageKind kind { get { return MessageKind.EXPORT_PLAYLIST; } }
}

public class Gradio.SetResumePlaybackMessage : Gradio.Message {
    public bool enabled;

    public SetResumePlaybackMessage (bool enabled) { this.enabled = enabled; }

    public override MessageKind kind { get { return MessageKind.SET_RESUME_PLAYBACK; } }
}

public class Gradio.RestoreLastStationMessage : Gradio.Message {
    public override MessageKind kind { get { return MessageKind.RESTORE_LAST_STATION; } }
}

public class Gradio.RequestFilterOptionsMessage : Gradio.Message {
    public override MessageKind kind { get { return MessageKind.REQUEST_FILTER_OPTIONS; } }
}

public class Gradio.FilterOptionsLoadedMessage : Gradio.Message {
    public SearchFilterKind field;
    public string[] names;

    public FilterOptionsLoadedMessage (SearchFilterKind field, string[] names) {
        this.field = field;
        this.names = names;
    }

    public override MessageKind kind { get { return MessageKind.FILTER_OPTIONS_LOADED; } }
}

public class Gradio.RequestDiscoverMessage : Gradio.Message {
    public override MessageKind kind { get { return MessageKind.REQUEST_DISCOVER; } }
}

public class Gradio.DiscoverServerMessage : Gradio.Message {
    public override MessageKind kind { get { return MessageKind.DISCOVER_SERVER; } }
}

public class Gradio.ServerDiscoveredMessage : Gradio.Message {
    public string api_base;

    public ServerDiscoveredMessage (string api_base) { this.api_base = api_base; }

    public override MessageKind kind { get { return MessageKind.SERVER_DISCOVERED; } }
}

public class Gradio.ServerDiscoveryFailedMessage : Gradio.Message {
    public string message;

    public ServerDiscoveryFailedMessage (string message) { this.message = message; }

    public override MessageKind kind { get { return MessageKind.SERVER_DISCOVERY_FAILED; } }
}

public class Gradio.DiscoverResultsMessage : Gradio.Message {
    public DiscoverMode mode;
    public GLib.GenericArray<RadioStation> stations;
    public uint generation;

    public DiscoverResultsMessage (DiscoverMode mode,
            GLib.GenericArray<RadioStation> stations, uint generation) {
        this.mode = mode;
        this.stations = stations;
        this.generation = generation;
    }

    public override MessageKind kind { get { return MessageKind.DISCOVER_RESULTS; } }
}

public class Gradio.DiscoverFailedMessage : Gradio.Message {
    public DiscoverMode mode;
    public string message;
    public uint generation;

    public DiscoverFailedMessage (DiscoverMode mode, string message, uint generation) {
        this.mode = mode;
        this.message = message;
        this.generation = generation;
    }

    public override MessageKind kind { get { return MessageKind.DISCOVER_FAILED; } }
}

public class Gradio.SetBackgroundPlaybackMessage : Gradio.Message {
    public bool enabled;

    public SetBackgroundPlaybackMessage (bool enabled) { this.enabled = enabled; }

    public override MessageKind kind { get { return MessageKind.SET_BACKGROUND_PLAYBACK; } }
}

public class Gradio.WindowCloseRequestedMessage : Gradio.Message {
    public override MessageKind kind { get { return MessageKind.WINDOW_CLOSE_REQUESTED; } }
}

public class Gradio.WindowRaisedMessage : Gradio.Message {
    public override MessageKind kind { get { return MessageKind.WINDOW_RAISED; } }
}

public class Gradio.SetNotificationsMessage : Gradio.Message {
    public bool enabled;

    public SetNotificationsMessage (bool enabled) { this.enabled = enabled; }

    public override MessageKind kind { get { return MessageKind.SET_NOTIFICATIONS; } }
}

public class Gradio.SetShowStatusBarMessage : Gradio.Message {
    public bool enabled;

    public SetShowStatusBarMessage (bool enabled) { this.enabled = enabled; }

    public override MessageKind kind { get { return MessageKind.SET_SHOW_STATUS_BAR; } }
}

public class Gradio.SetPlayerInHeaderMessage : Gradio.Message {
    public bool enabled;

    public SetPlayerInHeaderMessage (bool enabled) { this.enabled = enabled; }

    public override MessageKind kind { get { return MessageKind.SET_PLAYER_IN_HEADER; } }
}

public class Gradio.DiscoverCastDevicesMessage : Gradio.Message {
    public override MessageKind kind { get { return MessageKind.DISCOVER_CAST_DEVICES; } }
}

public class Gradio.CastDevicesDiscoveredMessage : Gradio.Message {
    public CastDevice[] devices;

    public CastDevicesDiscoveredMessage (CastDevice[] devices) { this.devices = devices; }

    public override MessageKind kind { get { return MessageKind.CAST_DEVICES_DISCOVERED; } }
}

public class Gradio.CastDiscoveryFailedMessage : Gradio.Message {
    public string error;

    public CastDiscoveryFailedMessage (string error) { this.error = error; }

    public override MessageKind kind { get { return MessageKind.CAST_DISCOVERY_FAILED; } }
}

public class Gradio.SelectCastDeviceMessage : Gradio.Message {
    public string device_id;
    public string device_name;
    public string device_host;
    public int device_port;

    public SelectCastDeviceMessage (string device_id, string device_name,
            string device_host, int device_port) {
        this.device_id = device_id;
        this.device_name = device_name;
        this.device_host = device_host;
        this.device_port = device_port;
    }

    public override MessageKind kind { get { return MessageKind.SELECT_CAST_DEVICE; } }
}

public class Gradio.CastToSelectedMessage : Gradio.Message {
    public override MessageKind kind { get { return MessageKind.CAST_TO_SELECTED; } }
}

public class Gradio.CastStartedMessage : Gradio.Message {
    public string device_id;

    public CastStartedMessage (string device_id) { this.device_id = device_id; }

    public override MessageKind kind { get { return MessageKind.CAST_STARTED; } }
}

public class Gradio.CastStoppedMessage : Gradio.Message {
    public override MessageKind kind { get { return MessageKind.CAST_STOPPED; } }
}

public class Gradio.CastFailedMessage : Gradio.Message {
    public string error;

    public CastFailedMessage (string error) { this.error = error; }

    public override MessageKind kind { get { return MessageKind.CAST_FAILED; } }
}

public class Gradio.StopCastMessage : Gradio.Message {
    public override MessageKind kind { get { return MessageKind.STOP_CAST; } }
}

public class Gradio.PlayLocalMessage : Gradio.Message {
    public override MessageKind kind { get { return MessageKind.PLAY_LOCAL; } }
}

public class Gradio.AppModel {
    public ViewMode view = ViewMode.LIBRARY;
    public AppConfig config;
    // Sorted view of config.stations. config.stations stays in custom order
    // (the persisted source of truth); this array is rebuilt only when the
    // library or the sort settings change.
    public GLib.GenericArray<RadioStation> library_order =
        new GLib.GenericArray<RadioStation> ();
    public uint library_revision = 0;
    private uint library_order_revision = 0;
    private LibrarySortMode library_order_sort = LibrarySortMode.CUSTOM;
    private bool library_order_descending = false;
    public GLib.GenericArray<RadioStation> search_results = new GLib.GenericArray<RadioStation> ();
    public string search_query = "";
    public bool search_active = false;
    public bool searching = false;
    public string? search_error = null;
    public uint search_generation = 0;
    public RadioStation? current_station = null;
    public bool playing = false;
    // True after an explicit stop (stop button, MPRIS Stop, station removal)
    // as opposed to a pause/toggle; MPRIS reports "Stopped" for this state.
    public bool playback_stopped = false;
    public bool playback_failed = false;
    public bool window_hidden = false;
    public string last_notified_title = "";
    public string[] track_history = {};
    public string stream_title = "";
    public int stream_bitrate = 0;
    public bool details_visible = false;
    public RadioStation? details_station = null;
    // Transient playback text shown on the player's track line
    // ("Connecting…", "Reconnecting…", error messages).
    public string player_status = "";
    // App-wide feedback ("Exported 10 stations", …) shown in the status bar.
    public string status_message = "";
    public GLib.HashTable<string, string> favicons = new GLib.HashTable<string, string> (str_hash, str_equal);
    public GLib.HashTable<string, string> favicon_sources = new GLib.HashTable<string, string> (str_hash, str_equal);
    public GLib.HashTable<string, bool> voted_ids = new GLib.HashTable<string, bool> (str_hash, str_equal);
    public GLib.HashTable<string, bool> votes_pending = new GLib.HashTable<string, bool> (str_hash, str_equal);
    public string[] filter_countries = {};
    public string[] filter_languages = {};
    public string[] filter_tags = {};
    public bool server_ready = false;
    public string? server_error = null;
    public GLib.GenericArray<RadioStation> discover_popular =
        new GLib.GenericArray<RadioStation> ();
    public GLib.GenericArray<RadioStation> discover_new =
        new GLib.GenericArray<RadioStation> ();
    public bool discover_loading = false;
    public string? discover_error = null;
    public uint discover_generation = 0;
    public int discover_pending = 0;
    public PlaybackTarget playback_target = PlaybackTarget.LOCAL;
    public CastStatus cast_status = CastStatus.IDLE;
    public string? cast_device_id = null;
    public string? cast_device_name = null;
    public string cast_device_host = "";
    public int cast_port = 8009;
    public CastDevice[] cast_devices = {};
    public string cast_error = "";
    public string current_stream_url = "";

    public AppModel (AppConfig config) {
        this.config = config;
        this.cast_device_id = config.cast_device_id != ""
            ? config.cast_device_id : null;
        this.cast_device_name = config.cast_device_name != ""
            ? config.cast_device_name : null;
        this.cast_device_host = config.cast_host;
        this.cast_port = config.cast_port;
        ensure_library_order ();
    }

    // Call whenever the library contents or any field used by
    // StationSort.sort_library() change. config.stations itself is never
    // reordered by sorting; custom order stays intact for drag-and-drop.
    public void invalidate_library_order () {
        library_revision++;
    }

    // Kept O(1) for unrelated messages: the cached array is reused unless the
    // revision, the sort mode, or the descending flag changed. The length
    // check also catches direct config mutations made by tests.
    public void ensure_library_order () {
        if (library_order_revision == library_revision &&
                library_order_sort == config.library_sort &&
                library_order_descending == config.library_sort_descending &&
                library_order.length == config.stations.length)
            return;
        library_order = StationSort.sort_library (config.stations,
            config.library_sort, config.library_sort_descending);
        library_order_revision = library_revision;
        library_order_sort = config.library_sort;
        library_order_descending = config.library_sort_descending;
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

    public bool discover_has_results () {
        return discover_popular.length > 0 || discover_new.length > 0;
    }

    public bool discover_should_show_error () {
        return discover_error != null && !discover_has_results ();
    }

    public string[] filter_options (SearchFilterKind field) {
        switch (field) {
            case SearchFilterKind.COUNTRY:
                return filter_countries;
            case SearchFilterKind.LANGUAGE:
                return filter_languages;
            case SearchFilterKind.TAG:
                return filter_tags;
            default:
                return {};
        }
    }
}
