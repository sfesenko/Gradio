[CCode (lower_case_c_prefix = "cast_", cheader_filename = "cast.pb-c.h")]
namespace Cast {
    [CCode (cname = "CastMessage", has_type_id = false)]
    public class Message {
        public int protocol_version;
        public string source_id;
        public string destination_id;
        public string @namespace;
        public int payload_type;
        public string payload_utf8;
        public uint8[] payload_binary;

        public Message ();
        public void pack (GLib.Buffer buffer);
        public static Cast.Message unpack (uint8[] data, out int length);
    }
}

[CCode (lower_case_c_prefix = "cast_message_")]
namespace Cast {
    public static int write_frame (GLib.Buffer buffer, string json);
    public static string read_frame (uint8[] data, int offset, out int frame_length);
}
