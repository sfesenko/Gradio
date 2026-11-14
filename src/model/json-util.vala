// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {
    // Best-effort helpers for untrusted frames (Chromecast) where an unusable
    // input means "ignore this frame". object_from() returns null on bad JSON
    // or a non-object root; callers must ignore the frame in that case.
    // Config and station-transfer parsing keep their explicit errors;
    // radio-browser station parsing also treats a missing field as empty.
    public class JsonUtil {
        public static Json.Object? object_from (string json) {
            var parser = new Json.Parser ();
            try {
                parser.load_from_data (json, -1);
            } catch (GLib.Error e) {
                return null;
            }
            var root = parser.get_root ();
            if (root == null || root.get_node_type () != Json.NodeType.OBJECT)
                return null;
            return root.get_object ();
        }

        public static string string_member (Json.Object obj, string name) {
            if (!obj.has_member (name))
                return "";
            var node = obj.get_member (name);
            if (node == null || node.get_value_type () != typeof (string))
                return "";
            return node.get_string () ?? "";
        }

        public static Json.Object? object_member (Json.Object obj, string name) {
            if (!obj.has_member (name))
                return null;
            var node = obj.get_member (name);
            if (node == null || node.get_node_type () != Json.NodeType.OBJECT)
                return null;
            return node.get_object ();
        }

        public static int int_member (Json.Object obj, string name) {
            if (!obj.has_member (name))
                return 0;
            var node = obj.get_member (name);
            if (node == null)
                return 0;
            var type = node.get_value_type ();
            if (type == typeof (int64))
                return (int) node.get_int ();
            if (type == typeof (double))
                return (int) node.get_double ();
            if (type == typeof (string)) {
                int value;
                if (int.try_parse (node.get_string () ?? "", out value))
                    return value;
            }
            return 0;
        }
    }
}