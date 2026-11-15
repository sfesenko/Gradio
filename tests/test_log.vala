// SPDX-License-Identifier: GPL-3.0-or-later

using Gradio;

string make_path () {
    return GLib.Path.build_filename (GLib.Environment.get_tmp_dir (),
        "gradio-log-%d.log".printf (GLib.Random.int_range (0, int.MAX)));
}

string read_file (string path) {
    string content;
    try {
        GLib.FileUtils.get_contents (path, out content);
    } catch (GLib.Error e) {
        GLib.error ("cannot read %s: %s", path, e.message);
    }
    return content;
}

void test_file_duplicates_log () {
    var path = make_path ();
    Gradio.Log.set_file (path);
    GLib.log_structured ("gradio", GLib.LogLevelFlags.LEVEL_MESSAGE,
        "MESSAGE", "duplicate: 7", null);

    assert ("[INFO] gradio: duplicate: 7" in read_file (path));

    Gradio.Log.set_file (null);
    GLib.FileUtils.remove (path);
}

void test_debug_needs_messages_debug () {
    var path = make_path ();
    Gradio.Log.set_file (path);
    GLib.log_structured ("gradio", GLib.LogLevelFlags.LEVEL_DEBUG,
        "MESSAGE", "hidden: 7", null);

    assert (!("hidden: 7" in read_file (path)));

    Gradio.Log.set_file (null);
    GLib.FileUtils.remove (path);
}

void test_creates_parent_dirs () {
    var dir = GLib.Path.build_filename (GLib.Environment.get_tmp_dir (),
        "gradio-log-dir-%d".printf (GLib.Random.int_range (0, int.MAX)));
    var path = GLib.Path.build_filename (dir, "nested", "gradio.log");
    Gradio.Log.set_file (path);
    GLib.log_structured ("gradio", GLib.LogLevelFlags.LEVEL_MESSAGE,
        "MESSAGE", "nested: 7", null);

    assert (GLib.FileUtils.test (path, GLib.FileTest.EXISTS));
    assert ("nested: 7" in read_file (path));

    Gradio.Log.set_file (null);
    GLib.FileUtils.remove (path);
    GLib.DirUtils.remove (GLib.Path.get_dirname (path));
    GLib.DirUtils.remove (dir);
}

int main (string[] args) {
    GLib.Environment.unset_variable ("G_MESSAGES_DEBUG");
    Test.init (ref args);
    Test.add_func ("/log/file_duplicates", test_file_duplicates_log);
    Test.add_func ("/log/debug_gated", test_debug_needs_messages_debug);
    Test.add_func ("/log/parent_dirs", test_creates_parent_dirs);
    return Test.run ();
}
