// SPDX-License-Identifier: GPL-3.0-or-later

string make_tmp_dir () {
    return GLib.DirUtils.make_tmp ("gradio-runtime-test-XXXXXX");
}

void cleanup_dir (string dir) {
    GLib.FileUtils.remove (GLib.Path.build_filename (dir, "config.json"));
    GLib.FileUtils.remove (GLib.Path.build_filename (dir, "config.json.tmp"));
    GLib.FileUtils.remove (GLib.Path.build_filename (dir, "config.json.corrupt"));
    GLib.FileUtils.remove (GLib.Path.build_filename (dir, "blocker"));
    GLib.DirUtils.remove (dir);
}

void wait_for_save () {
    var loop = new GLib.MainLoop ();
    GLib.Timeout.add (1500, () => { loop.quit (); return false; });
    loop.run ();
}

Gradio.AppConfig load_config (string path) {
    try {
        return Gradio.AppConfig.load (path);
    } catch (GLib.Error e) {
        assert_not_reached ();
    }
    return new Gradio.AppConfig (path);
}

void test_save_schedules_write () {
    string dir = make_tmp_dir ();
    string path = GLib.Path.build_filename (dir, "config.json");
    var config = new Gradio.AppConfig (path);
    var station = new Gradio.RadioStation ();
    station.id = "u1";
    station.name = "Jazz FM";
    station.url = "https://example.test/jazz";
    config.add_station (station);

    var runtime = new Gradio.AppRuntime (config);
    runtime.attach ((msg) => {});
    var cmd = runtime.save_config ();
    assert (cmd != null);
    Elmish.Cmd.exec<Gradio.Message> ((msg) => {}, cmd);

    wait_for_save ();

    assert (GLib.FileUtils.test (path, GLib.FileTest.EXISTS));
    var loaded = load_config (path);
    assert (loaded.stations.length == 1);
    cleanup_dir (dir);
}

void test_volume_schedules_save () {
    string dir = make_tmp_dir ();
    string path = GLib.Path.build_filename (dir, "config.json");
    var config = new Gradio.AppConfig (path);
    config.volume = 0.4;

    var runtime = new Gradio.AppRuntime (config);
    runtime.attach ((msg) => {});
    var cmd = runtime.set_volume (0.4);
    assert (cmd != null);
    Elmish.Cmd.exec<Gradio.Message> ((msg) => {}, cmd);

    wait_for_save ();

    assert (runtime.player.volume == 0.4);
    var loaded = load_config (path);
    assert (loaded.volume == 0.4);
    cleanup_dir (dir);
}

void test_save_failure_dispatches_error () {
    string dir = make_tmp_dir ();
    string blocker = GLib.Path.build_filename (dir, "blocker");
    GLib.FileUtils.set_contents (blocker, "not a directory");
    string path = GLib.Path.build_filename (blocker, "config.json");

    var config = new Gradio.AppConfig (path);
    var runtime = new Gradio.AppRuntime (config);
    Gradio.Message? last = null;
    runtime.attach ((msg) => { last = msg; });

    runtime.save_now ();

    assert (last != null);
    assert (last is Gradio.ConfigSaveFailedMessage);
    cleanup_dir (dir);
}

void test_corrupt_config_survives_shutdown () {
    string dir = make_tmp_dir ();
    string path = GLib.Path.build_filename (dir, "config.json");
    GLib.FileUtils.set_contents (path, "{not json");

    bool load_failed = false;
    try {
        Gradio.AppConfig.load (path);
    } catch (GLib.Error e) {
        load_failed = true;
    }
    assert (load_failed);

    var config = new Gradio.AppConfig (path);
    var runtime = new Gradio.AppRuntime (config, true);
    runtime.attach ((msg) => {});
    runtime.save_now ();

    string contents;
    GLib.FileUtils.get_contents (path, out contents);
    assert (contents == "{not json");
    assert (!GLib.FileUtils.test (path + ".corrupt", GLib.FileTest.EXISTS));
    cleanup_dir (dir);
}

void test_user_save_after_load_failure_backs_up_and_writes () {
    string dir = make_tmp_dir ();
    string path = GLib.Path.build_filename (dir, "config.json");
    GLib.FileUtils.set_contents (path, "{not json");

    var config = new Gradio.AppConfig (path);
    var station = new Gradio.RadioStation ();
    station.id = "u1";
    station.name = "Jazz FM";
    station.url = "https://example.test/jazz";
    config.add_station (station);

    var runtime = new Gradio.AppRuntime (config, true);
    runtime.attach ((msg) => {});
    var cmd = runtime.save_config ();
    Elmish.Cmd.exec<Gradio.Message> ((msg) => {}, cmd);
    runtime.save_now ();

    string backup;
    GLib.FileUtils.get_contents (path + ".corrupt", out backup);
    assert (backup == "{not json");

    var loaded = load_config (path);
    assert (loaded.stations.length == 1);
    cleanup_dir (dir);
}

void test_newer_config_is_preserved_read_only () {
    string dir = make_tmp_dir ();
    string path = GLib.Path.build_filename (dir, "config.json");
    string original = "{\"version\": 2, \"stations\": [{\"stationuuid\":\"f1\",\"name\":\"Future FM\",\"url_resolved\":\"https://example.test/future\"}]}";
    GLib.FileUtils.set_contents (path, original);

    bool newer = false;
    try {
        Gradio.AppConfig.load (path);
    } catch (Gradio.ConfigError e) {
        newer = true;
    }
    assert (newer);

    var config = new Gradio.AppConfig (path);
    var runtime = new Gradio.AppRuntime (config, false, true);
    runtime.attach ((msg) => {});
    var cmd = runtime.save_config ();
    Elmish.Cmd.exec<Gradio.Message> ((msg) => {}, cmd);
    runtime.save_now ();

    string contents;
    GLib.FileUtils.get_contents (path, out contents);
    assert (contents == original);
    assert (!GLib.FileUtils.test (path + ".corrupt", GLib.FileTest.EXISTS));
    cleanup_dir (dir);
}

void test_config_store_writes_async () {
    string dir = make_tmp_dir ();
    string path = GLib.Path.build_filename (dir, "config.json");
    var config = new Gradio.AppConfig (path);
    config.volume = 0.25;
    var store = new Gradio.ConfigStore (config);
    var loop = new GLib.MainLoop ();
    bool saved = false;
    store.save_failed.connect ((message) => {
        Test.message ("unexpected save failure: %s", message);
        loop.quit ();
    });
    store.saved.connect (() => {
        saved = true;
        loop.quit ();
    });

    store.save ();
    loop.run ();

    assert (saved);
    var loaded = load_config (path);
    assert (loaded.volume == 0.25);
    cleanup_dir (dir);
}

void test_config_store_latest_snapshot_wins () {
    string dir = make_tmp_dir ();
    string path = GLib.Path.build_filename (dir, "config.json");
    var config = new Gradio.AppConfig (path);
    config.volume = 0.1;
    var store = new Gradio.ConfigStore (config);
    var loop = new GLib.MainLoop ();
    bool saw_latest = false;
    store.save_failed.connect ((message) => {
        Test.message ("unexpected save failure: %s", message);
        loop.quit ();
    });
    store.saved.connect (() => {
        var loaded = load_config (path);
        if (loaded.volume == 0.9) {
            saw_latest = true;
            loop.quit ();
        }
    });

    store.save ();
    config.volume = 0.9;
    store.save ();
    loop.run ();

    assert (saw_latest);
    var loaded = load_config (path);
    assert (loaded.volume == 0.9);
    cleanup_dir (dir);
}

void test_config_store_reports_failure () {
    string dir = make_tmp_dir ();
    string blocker = GLib.Path.build_filename (dir, "blocker");
    GLib.FileUtils.set_contents (blocker, "not a directory");
    string path = GLib.Path.build_filename (blocker, "config.json");
    var config = new Gradio.AppConfig (path);
    var store = new Gradio.ConfigStore (config);
    var loop = new GLib.MainLoop ();
    bool failed = false;
    store.save_failed.connect ((message) => {
        failed = true;
        loop.quit ();
    });

    store.save ();
    loop.run ();

    assert (failed);
    cleanup_dir (dir);
}

void test_import_missing_dispatches_failure () {
    string dir = make_tmp_dir ();
    string path = GLib.Path.build_filename (dir, "missing.json");
    var config = new Gradio.AppConfig (GLib.Path.build_filename (dir, "config.json"));
    var runtime = new Gradio.AppRuntime (config);
    Gradio.Message? last = null;
    runtime.attach ((msg) => { last = msg; });
    var cmd = runtime.import_stations (path);
    assert (cmd != null);
    Elmish.Cmd.exec<Gradio.Message> ((msg) => { last = msg; }, cmd);
    wait_for_save ();

    assert (last is Gradio.ImportFailedMessage);
    cleanup_dir (dir);
}

void test_export_unwritable_dispatches_failure () {
    string dir = make_tmp_dir ();
    string blocker = GLib.Path.build_filename (dir, "blocker");
    GLib.FileUtils.set_contents (blocker, "not a directory");
    string path = GLib.Path.build_filename (blocker, "export.json");
    var config = new Gradio.AppConfig (GLib.Path.build_filename (dir, "config.json"));
    var station = new Gradio.RadioStation ();
    station.id = "u1";
    station.name = "Jazz FM";
    station.url = "https://example.test/jazz";
    config.add_station (station);

    var runtime = new Gradio.AppRuntime (config);
    Gradio.Message? last = null;
    runtime.attach ((msg) => { last = msg; });
    var cmd = runtime.export_stations (config.stations, path);
    assert (cmd != null);
    Elmish.Cmd.exec<Gradio.Message> ((msg) => { last = msg; }, cmd);
    wait_for_save ();

    assert (last is Gradio.ExportFailedMessage);
    cleanup_dir (dir);
}

void test_export_writes_stations () {
    string dir = make_tmp_dir ();
    string path = GLib.Path.build_filename (dir, "export.json");
    var config = new Gradio.AppConfig (GLib.Path.build_filename (dir, "config.json"));
    var station = new Gradio.RadioStation ();
    station.id = "u1";
    station.name = "Jazz FM";
    station.url = "https://example.test/jazz";
    config.add_station (station);

    var runtime = new Gradio.AppRuntime (config);
    runtime.attach ((msg) => {});
    var cmd = runtime.export_stations (config.stations, path);
    assert (cmd != null);
    Elmish.Cmd.exec<Gradio.Message> ((msg) => {}, cmd);
    wait_for_save ();

    string contents;
    GLib.FileUtils.get_contents (path, out contents);
    assert (contents.contains ("Jazz FM"));
    GLib.FileUtils.remove (path);
    cleanup_dir (dir);
}

void test_import_dispatches_stations () {
    string dir = make_tmp_dir ();
    string path = GLib.Path.build_filename (dir, "import.json");
    GLib.FileUtils.set_contents (path,
        "[{\"stationuuid\":\"u1\",\"name\":\"Jazz FM\",\"url_resolved\":\"https://example.test/jazz\"}]");

    var config = new Gradio.AppConfig (GLib.Path.build_filename (dir, "config.json"));
    var runtime = new Gradio.AppRuntime (config);
    Gradio.Message? last = null;
    runtime.attach ((msg) => { last = msg; });
    var cmd = runtime.import_stations (path);
    assert (cmd != null);
    Elmish.Cmd.exec<Gradio.Message> ((msg) => {}, cmd);
    wait_for_save ();

    assert (last != null);
    assert (last is Gradio.StationsImportedMessage);
    var imported = (Gradio.StationsImportedMessage) last;
    assert (imported.stations.length == 1);
    GLib.FileUtils.remove (path);
    cleanup_dir (dir);
}

void test_report_click_failure_is_silent () {
    string dir = make_tmp_dir ();
    var config = new Gradio.AppConfig (GLib.Path.build_filename (dir, "config.json"));
    var runtime = new Gradio.AppRuntime (config);
    Gradio.Message? last = null;
    runtime.attach ((msg) => { last = msg; });

    Gradio.RadioBrowser.api_base = "not a url";
    var cmd = runtime.report_click ("u1");
    assert (cmd != null);
    Elmish.Cmd.exec<Gradio.Message> ((msg) => { last = msg; }, cmd);
    wait_for_save ();

    assert (last == null);
    Gradio.RadioBrowser.api_base = Gradio.RadioBrowser.radio_browser;
    cleanup_dir (dir);
}

void test_notify_without_application_is_noop () {    string dir = make_tmp_dir ();
    var config = new Gradio.AppConfig (GLib.Path.build_filename (dir, "config.json"));
    var runtime = new Gradio.AppRuntime (config);
    runtime.attach ((msg) => {});

    var cmd = runtime.notify_error ("boom");
    assert (cmd != null);
    Elmish.Cmd.exec<Gradio.Message> ((msg) => {}, cmd);
    cleanup_dir (dir);
}

void test_export_playlist_writes_m3u () {
    string dir = make_tmp_dir ();
    string path = GLib.Path.build_filename (dir, "export.m3u");
    var config = new Gradio.AppConfig (GLib.Path.build_filename (dir, "config.json"));
    var station = new Gradio.RadioStation ();
    station.id = "u1";
    station.name = "Jazz FM";
    station.url = "https://example.test/jazz";
    config.add_station (station);

    var runtime = new Gradio.AppRuntime (config);
    runtime.attach ((msg) => {});
    var cmd = runtime.export_playlist (config.stations, path);
    assert (cmd != null);
    Elmish.Cmd.exec<Gradio.Message> ((msg) => {}, cmd);
    wait_for_save ();

    string contents;
    GLib.FileUtils.get_contents (path, out contents);
    assert (contents.has_prefix ("#EXTM3U\n"));
    assert (contents.contains ("#EXTINF:-1,Jazz FM\nhttps://example.test/jazz\n"));
    GLib.FileUtils.remove (path);
    cleanup_dir (dir);
}

void test_background_commands_without_application_are_noop () {
    string dir = make_tmp_dir ();
    var config = new Gradio.AppConfig (GLib.Path.build_filename (dir, "config.json"));
    var runtime = new Gradio.AppRuntime (config);
    var background = runtime.background_on_close ();
    var quit = runtime.quit_application ();
    var release = runtime.release_background ();
    assert (background != null);
    assert (quit != null);
    assert (release != null);
    Elmish.Cmd.exec<Gradio.Message> ((msg) => {}, background);
    Elmish.Cmd.exec<Gradio.Message> ((msg) => {}, quit);
    Elmish.Cmd.exec<Gradio.Message> ((msg) => {}, release);
    cleanup_dir (dir);
}

int main (string[] args) {
    Gst.init (ref args);
    Test.init (ref args);

    Test.add_func ("/app-runtime/save_schedules_write", test_save_schedules_write);
    Test.add_func ("/app-runtime/config_store_writes_async", test_config_store_writes_async);
    Test.add_func ("/app-runtime/config_store_latest_snapshot_wins", test_config_store_latest_snapshot_wins);
    Test.add_func ("/app-runtime/config_store_reports_failure", test_config_store_reports_failure);
    Test.add_func ("/app-runtime/volume_schedules_save", test_volume_schedules_save);
    Test.add_func ("/app-runtime/save_failure_dispatches_error", test_save_failure_dispatches_error);
    Test.add_func ("/app-runtime/corrupt_config_survives_shutdown", test_corrupt_config_survives_shutdown);
    Test.add_func ("/app-runtime/user_save_after_load_failure_backs_up", test_user_save_after_load_failure_backs_up_and_writes);
    Test.add_func ("/app-runtime/newer_config_read_only", test_newer_config_is_preserved_read_only);
    Test.add_func ("/app-runtime/export_writes_stations", test_export_writes_stations);
    Test.add_func ("/app-runtime/export_playlist_writes_m3u", test_export_playlist_writes_m3u);
    Test.add_func ("/app-runtime/import_dispatches_stations", test_import_dispatches_stations);
    Test.add_func ("/app-runtime/import_missing_fails", test_import_missing_dispatches_failure);
    Test.add_func ("/app-runtime/export_unwritable_fails", test_export_unwritable_dispatches_failure);
    Test.add_func ("/app-runtime/notify_without_app", test_notify_without_application_is_noop);
    Test.add_func ("/app-runtime/report_click_failure_silent", test_report_click_failure_is_silent);
    Test.add_func ("/app-runtime/background_noop", test_background_commands_without_application_are_noop);

    return Test.run ();
}
