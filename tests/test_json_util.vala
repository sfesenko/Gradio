// SPDX-License-Identifier: GPL-3.0-or-later

using Gradio;

void test_object_from_valid () {
    var obj = JsonUtil.object_from ("{\"a\":\"b\",\"n\":3}");
    assert (obj != null);
    assert (obj.get_string_member ("a") == "b");
    assert (obj.get_int_member ("n") == 3);
}

void test_object_from_invalid () {
    assert (JsonUtil.object_from ("not json") == null);
    assert (JsonUtil.object_from ("[1,2]") == null);
    assert (JsonUtil.object_from ("") == null);
}

void test_string_member () {
    var obj = JsonUtil.object_from ("{\"a\":\"b\",\"n\":3}");
    assert (JsonUtil.string_member (obj, "a") == "b");
    assert (JsonUtil.string_member (obj, "missing") == "");
    assert (JsonUtil.string_member (obj, "n") == "");
}

void test_int_member () {
    var obj = JsonUtil.object_from ("{\"n\":3,\"d\":2.5,\"s\":\"7\",\"x\":\"no\"}");
    assert (JsonUtil.int_member (obj, "n") == 3);
    assert (JsonUtil.int_member (obj, "d") == 2);
    assert (JsonUtil.int_member (obj, "s") == 7);
    assert (JsonUtil.int_member (obj, "x") == 0);
    assert (JsonUtil.int_member (obj, "missing") == 0);
}

void test_object_member () {
    var obj = JsonUtil.object_from ("{\"o\":{\"a\":\"b\"},\"n\":3,\"nil\":null}");
    var nested = JsonUtil.object_member (obj, "o");
    assert (nested != null);
    assert (JsonUtil.string_member (nested, "a") == "b");
    assert (JsonUtil.object_member (obj, "missing") == null);
    assert (JsonUtil.object_member (obj, "n") == null);
    assert (JsonUtil.object_member (obj, "nil") == null);
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/json/object_from", test_object_from_valid);
    Test.add_func ("/json/object_from_invalid", test_object_from_invalid);
    Test.add_func ("/json/string_member", test_string_member);
    Test.add_func ("/json/int_member", test_int_member);
    Test.add_func ("/json/object_member", test_object_member);
    return Test.run ();
}