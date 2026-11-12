// SPDX-License-Identifier: GPL-3.0-or-later

using Gradio;

string make_tmp_dir () {
    return GLib.DirUtils.make_tmp ("gradio-favicon-test-XXXXXX");
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

uint8[] make_png (int width, int height, string compression = "1") {
    var pixbuf = new Gdk.Pixbuf (Gdk.Colorspace.RGB, true, 8, width, height);
    pixbuf.fill (0x336699ff);
    uint8[] buffer;
    pixbuf.save_to_buffer (out buffer, "png", "compression", compression, null);
    return buffer;
}

uint8[] make_noisy_png (int width, int height) {
    uint8[] raw = new uint8[width * height * 3];
    uint32 state = 1;
    for (int i = 0; i < raw.length; i++) {
        state = state * 1664525 + 1013904223;
        raw[i] = (uint8) (state >> 16);
    }
    var pixbuf = new Gdk.Pixbuf.from_data (raw, Gdk.Colorspace.RGB, false, 8,
        width, height, width * 3);
    uint8[] buffer;
    pixbuf.save_to_buffer (out buffer, "png", "compression", "0", null);
    return buffer;
}

void test_hash_is_stable () {
    string a = FaviconCache.hash_url ("https://example.test/a.png");
    string b = FaviconCache.hash_url ("https://example.test/a.png");
    string c = FaviconCache.hash_url ("https://example.test/b.png");
    assert (a.length == 64);
    assert (a == b);
    assert (a != c);
}

void test_path_uses_directory () {
    string dir = make_tmp_dir ();
    var cache = new FaviconCache (dir);
    string path = cache.path_for ("https://example.test/a.png");
    assert (path.has_prefix (dir + "/"));
    assert (path.has_suffix (".png"));
    assert (path == cache.path_for ("https://example.test/a.png"));
    remove_dir (dir);
}

void test_store_writes_and_lookup_finds () {
    string dir = make_tmp_dir ();
    var cache = new FaviconCache (dir);
    string url = "https://example.test/a.png";

    string? stored = cache.store (url, make_png (32, 32));
    assert (stored != null);
    assert (GLib.FileUtils.test (stored, GLib.FileTest.EXISTS));
    assert (cache.lookup (url) == stored);
    remove_dir (dir);
}

void test_store_resizes_large_image () {
    string dir = make_tmp_dir ();
    var cache = new FaviconCache (dir);
    string? stored = cache.store ("https://example.test/big.png", make_png (512, 256));
    assert (stored != null);

    try {
        var pixbuf = new Gdk.Pixbuf.from_file (stored);
        assert (pixbuf.get_width () == 128);
        assert (pixbuf.get_height () == 64);
    } catch (GLib.Error e) {
        assert_not_reached ();
    }
    remove_dir (dir);
}

void test_store_rejects_invalid_data () {
    string dir = make_tmp_dir ();
    var cache = new FaviconCache (dir);
    uint8[] junk = { 1, 2, 3, 4 };
    assert (cache.store ("https://example.test/junk", junk) == null);
    assert (cache.lookup ("https://example.test/junk") == null);
    remove_dir (dir);
}

void test_store_rejects_oversize_data () {
    string dir = make_tmp_dir ();
    var cache = new FaviconCache (dir);
    uint8[] huge = new uint8[FaviconCache.MAX_BYTES + 1];
    assert (cache.store ("https://example.test/huge", huge) == null);
    assert (cache.lookup ("https://example.test/huge") == null);
    remove_dir (dir);
}

void test_store_accepts_images_above_the_old_cap () {
    string dir = make_tmp_dir ();
    var cache = new FaviconCache (dir);
    uint8[] png = make_noisy_png (512, 512);
    assert (png.length > 256 * 1024);
    assert (png.length < FaviconCache.MAX_BYTES);
    assert (cache.store ("https://example.test/large.png", png) != null);
    remove_dir (dir);
}

void test_origin_icon_url () {
    assert (FaviconResolver.origin_icon_url ("https://example.test/page") ==
        "https://example.test/favicon.ico");
    assert (FaviconResolver.origin_icon_url ("http://example.test:8080/a/b") ==
        "http://example.test:8080/favicon.ico");
    assert (FaviconResolver.origin_icon_url ("ftp://example.test/a") == null);
    assert (FaviconResolver.origin_icon_url ("") == null);
}

void test_icon_url_from_html_absolute () {
    string html = "<html><head><link rel=\"icon\" href=\"https://cdn.test/icon.png\"></head></html>";
    assert (FaviconResolver.icon_url_from_html (html, "https://example.test/") ==
        "https://cdn.test/icon.png");
}

void test_icon_url_from_html_relative () {
    string html = "<link rel='shortcut icon' href='/static/favicon.png'>";
    assert (FaviconResolver.icon_url_from_html (html, "https://example.test/page") ==
        "https://example.test/static/favicon.png");

    string relative = "<LINK REL=\"apple-touch-icon\" HREF=\"icons/touch.png\">";
    assert (FaviconResolver.icon_url_from_html (relative, "https://example.test/a/page.html") ==
        "https://example.test/a/icons/touch.png");
}

void test_icon_url_from_html_protocol_relative () {
    string html = "<link rel=\"icon\" href=\"//cdn.test/icon.png\">";
    assert (FaviconResolver.icon_url_from_html (html, "https://example.test/") ==
        "https://cdn.test/icon.png");
}

void test_icon_url_from_html_skips_non_icons () {
    string html = "<link rel=\"stylesheet\" href=\"/style.css\"><link rel=\"icon\" href=\"/icon.png\">";
    assert (FaviconResolver.icon_url_from_html (html, "https://example.test/") ==
        "https://example.test/icon.png");

    assert (FaviconResolver.icon_url_from_html ("<html></html>", "https://example.test/") == null);
}

void test_cooldown_blocks_until_ttl () {
    var cooldown = new FaviconCooldown ();
    int64 now = 1000;
    assert (!cooldown.is_blocked ("u:https://example.test/a.png", now));
    cooldown.record_failure ("u:https://example.test/a.png", now);
    assert (cooldown.is_blocked ("u:https://example.test/a.png", now + 1));
    assert (!cooldown.is_blocked ("u:https://example.test/a.png",
        now + FaviconCooldown.TTL_USEC + 1));
}

void test_cooldown_clear () {
    var cooldown = new FaviconCooldown ();
    cooldown.record_failure ("h:https://example.test/", 0);
    cooldown.clear ();
    assert (!cooldown.is_blocked ("h:https://example.test/", 1));
}

void test_clear_removes_cache () {
    string dir = make_tmp_dir ();
    var cache = new FaviconCache (dir);
    assert (cache.store ("https://example.test/a.png", make_png (16, 16)) != null);
    assert (cache.store ("https://example.test/b.png", make_png (16, 16)) != null);

    cache.clear ();
    assert (cache.lookup ("https://example.test/a.png") == null);
    assert (cache.lookup ("https://example.test/b.png") == null);
    remove_dir (dir);
}

void test_lookup_async_finds_cached () {
    string dir = make_tmp_dir ();
    var cache = new FaviconCache (dir);
    string url = "https://example.test/async.png";
    string? stored = cache.store (url, make_png (16, 16));
    assert (stored != null);

    var loop = new GLib.MainLoop ();
    string? found = null;
    cache.lookup_async (url, (path) => {
        found = path;
        loop.quit ();
    });
    loop.run ();

    assert (found == stored);
    remove_dir (dir);
}

void test_store_async_writes_and_lookup () {
    string dir = make_tmp_dir ();
    var cache = new FaviconCache (dir);
    string url = "https://example.test/async-store.png";
    var loop = new GLib.MainLoop ();
    string? stored = null;
    cache.store_async (url, make_png (24, 24), (path) => {
        stored = path;
        loop.quit ();
    });
    loop.run ();

    assert (stored != null);
    assert (GLib.FileUtils.test (stored, GLib.FileTest.EXISTS));
    assert (cache.lookup (url) == stored);
    remove_dir (dir);
}

void test_store_async_rejects_invalid () {
    string dir = make_tmp_dir ();
    var cache = new FaviconCache (dir);
    var loop = new GLib.MainLoop ();
    string? stored = "not-called";
    uint8[] junk = { 1, 2, 3, 4 };
    cache.store_async ("https://example.test/junk-async", junk, (path) => {
        stored = path;
        loop.quit ();
    });
    loop.run ();

    assert (stored == null);
    remove_dir (dir);
}

void test_clear_async_removes_cache () {
    string dir = make_tmp_dir ();
    var cache = new FaviconCache (dir);
    assert (cache.store ("https://example.test/a.png", make_png (16, 16)) != null);
    assert (cache.store ("https://example.test/b.png", make_png (16, 16)) != null);

    var loop = new GLib.MainLoop ();
    cache.clear_async (() => { loop.quit (); });
    loop.run ();

    assert (cache.lookup ("https://example.test/a.png") == null);
    assert (cache.lookup ("https://example.test/b.png") == null);
    remove_dir (dir);
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/favicon/hash_is_stable", test_hash_is_stable);
    Test.add_func ("/favicon/path_uses_directory", test_path_uses_directory);
    Test.add_func ("/favicon/store_writes_and_lookup_finds", test_store_writes_and_lookup_finds);
    Test.add_func ("/favicon/store_resizes_large_image", test_store_resizes_large_image);
    Test.add_func ("/favicon/store_rejects_invalid_data", test_store_rejects_invalid_data);
    Test.add_func ("/favicon/store_rejects_oversize_data", test_store_rejects_oversize_data);
    Test.add_func ("/favicon/store_accepts_images_above_old_cap", test_store_accepts_images_above_the_old_cap);
    Test.add_func ("/favicon/origin_icon_url", test_origin_icon_url);
    Test.add_func ("/favicon/icon_url_from_html_absolute", test_icon_url_from_html_absolute);
    Test.add_func ("/favicon/icon_url_from_html_relative", test_icon_url_from_html_relative);
    Test.add_func ("/favicon/icon_url_from_html_protocol_relative", test_icon_url_from_html_protocol_relative);
    Test.add_func ("/favicon/icon_url_from_html_skips_non_icons", test_icon_url_from_html_skips_non_icons);
    Test.add_func ("/favicon/cooldown_blocks_until_ttl", test_cooldown_blocks_until_ttl);
    Test.add_func ("/favicon/cooldown_clear", test_cooldown_clear);
    Test.add_func ("/favicon/clear_removes_cache", test_clear_removes_cache);
    Test.add_func ("/favicon/lookup_async_finds_cached", test_lookup_async_finds_cached);
    Test.add_func ("/favicon/store_async_writes_and_lookup", test_store_async_writes_and_lookup);
    Test.add_func ("/favicon/store_async_rejects_invalid", test_store_async_rejects_invalid);
    Test.add_func ("/favicon/clear_async_removes_cache", test_clear_async_removes_cache);
    return Test.run ();
}
