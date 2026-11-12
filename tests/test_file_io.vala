// SPDX-License-Identifier: GPL-3.0-or-later

using Gradio;

string make_tmp_dir () {
    return GLib.DirUtils.make_tmp ("gradio-fileio-test-XXXXXX");
}

void remove_dir (string dir) {
    try {
        var d = GLib.Dir.open (dir, 0);
        string? name;
        while ((name = d.read_name ()) != null)
            GLib.FileUtils.remove (GLib.Path.build_filename (dir, name));
    } catch (GLib.Error e) {
    }
    GLib.DirUtils.remove (dir);
}

void test_save_then_load_async () {
    string dir = make_tmp_dir ();
    string path = GLib.Path.build_filename (dir, "nested", "file.txt");
    var loop = new GLib.MainLoop ();
    string? loaded = null;
    bool failed = false;

    FileIO.save_text_atomic_async.begin (path, "hello async", (obj, res) => {
        try {
            FileIO.save_text_atomic_async.end (res);
            FileIO.load_text_async.begin (path, (obj2, res2) => {
                try {
                    loaded = FileIO.load_text_async.end (res2);
                } catch (GLib.Error e) {
                    Test.message ("load failed: %s", e.message);
                    failed = true;
                }
                loop.quit ();
            });
        } catch (GLib.Error e) {
            Test.message ("save failed: %s", e.message);
            failed = true;
            loop.quit ();
        }
    });
    loop.run ();

    assert (!failed);
    assert (loaded == "hello async");
    remove_dir (dir);
}

void test_load_missing_file_fails () {
    string dir = make_tmp_dir ();
    string path = GLib.Path.build_filename (dir, "missing.txt");
    var loop = new GLib.MainLoop ();
    bool got_error = false;

    FileIO.load_text_async.begin (path, (obj, res) => {
        try {
            FileIO.load_text_async.end (res);
        } catch (GLib.Error e) {
            got_error = true;
        }
        loop.quit ();
    });
    loop.run ();

    assert (got_error);
    remove_dir (dir);
}

void test_save_failure_reports_error () {
    string dir = make_tmp_dir ();
    string blocker = GLib.Path.build_filename (dir, "blocker");
    GLib.FileUtils.set_contents (blocker, "not a directory");
    string path = GLib.Path.build_filename (blocker, "config.json");
    var loop = new GLib.MainLoop ();
    bool got_error = false;

    FileIO.save_text_atomic_async.begin (path, "data", (obj, res) => {
        try {
            FileIO.save_text_atomic_async.end (res);
        } catch (GLib.Error e) {
            got_error = true;
        }
        loop.quit ();
    });
    loop.run ();

    assert (got_error);
    remove_dir (dir);
}

void test_remove_and_rename_async () {
    string dir = make_tmp_dir ();
    string from = GLib.Path.build_filename (dir, "from.txt");
    string to = GLib.Path.build_filename (dir, "to.txt");
    GLib.FileUtils.set_contents (from, "data");
    var loop = new GLib.MainLoop ();
    bool failed = false;

    FileIO.rename_async.begin (from, to, (obj, res) => {
        try {
            FileIO.rename_async.end (res);
            FileIO.remove_async.begin (to, (obj2, res2) => {
                try {
                    FileIO.remove_async.end (res2);
                } catch (GLib.Error e) {
                    failed = true;
                }
                loop.quit ();
            });
        } catch (GLib.Error e) {
            failed = true;
            loop.quit ();
        }
    });
    loop.run ();

    assert (!failed);
    assert (!GLib.FileUtils.test (from, GLib.FileTest.EXISTS));
    assert (!GLib.FileUtils.test (to, GLib.FileTest.EXISTS));
    remove_dir (dir);
}

int main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/file-io/save_then_load_async", test_save_then_load_async);
    Test.add_func ("/file-io/load_missing_file_fails", test_load_missing_file_fails);
    Test.add_func ("/file-io/save_failure_reports_error", test_save_failure_reports_error);
    Test.add_func ("/file-io/remove_and_rename_async", test_remove_and_rename_async);

    return Test.run ();
}