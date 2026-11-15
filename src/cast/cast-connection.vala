// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {
    [CCode (lower_case_c_prefix = "cast_")]
    private struct CastMessage {
        public int protocol_version;
        public string source_id;
        public string destination_id;
        public string namespace_;
        public int payload_type;
        public string payload_utf8;
    }

    [CCode (cname = "cast_message_write_frame")]
    private extern static void cast_message_write_frame (GLib.ByteArray buffer, CastMessage msg);
    [CCode (cname = "cast_message_decode_json")]
    private extern static string cast_message_decode_json (uint8[] data, out int length);

    public class CastConnection : GLib.Object {
        public signal void message_received (string json);
        // The reason is a short, human-readable cause ("eof", "read: ...",
        // "write: ..."). The service logs it when the socket drops.
        public signal void closed (string reason);

        // A sender id identifies the transport. It must be unique per
        // connection: reusing one id makes the receiver treat a new socket as
        // the same sender and it can drop the older, live connection.
        public string source_id { get; private set; }

        private TlsClientConnection? tls = null;
        private DataInputStream? input = null;
        private DataOutputStream? output = null;
        private GLib.Cancellable cancellable = new GLib.Cancellable ();
        private GLib.Queue<GLib.Bytes> write_queue =
            new GLib.Queue<GLib.Bytes> ();
        // Keeps the frame alive until the asynchronous write completes.
        private GLib.Bytes? in_flight = null;
        private bool writing = false;
        private bool closing = false;
        private bool draining = false;
        private bool finishing = false;
        private bool closed_emitted = false;
        private string close_reason = "";

        public CastConnection () {
            source_id = GLib.Uuid.string_random ();
        }

        private static int trace_state = 0;

        private static bool trace_enabled () {
            if (trace_state == 0)
                trace_state = GLib.Environment.get_variable (
                    "GRADIO_CAST_TRACE") != null ? 1 : -1;
            return trace_state == 1;
        }

        private static void trace (string text) {
            if (trace_enabled ())
                GLib.message ("cast: " + text);
        }

        public async bool connect (string host, int port,
                GLib.Cancellable? session_cancellable = null) throws GLib.Error {
            if (session_cancellable != null)
                cancellable = session_cancellable;

            var client = new SocketClient ();
            // Bound the TCP connect. Without this the OS timeout (~2 min on
            // Linux) can block a startup probe against a stale device IP.
            client.timeout = 5;
            var conn = yield client.connect_to_host_async (host, (uint16) port,
                cancellable);
            // GSocketClient applies its timeout to the returned socket as well.
            // A 5 s I/O timeout races the receiver's 5 s heartbeat and drops the
            // connection with "Socket I/O timed out"; the connect is already
            // done, so the long-lived socket must not have one.
            var socket = conn.get_socket ();
            if (socket != null)
                socket.timeout = 0;
            var tls_conn = TlsClientConnection.@new (conn, null);
            // Self-signed certificate on the local network; the address comes
            // from mDNS, so accept it.
            tls_conn.accept_certificate.connect ((cert, errors) => true);
            yield tls_conn.handshake_async (GLib.Priority.DEFAULT, cancellable);

            tls = tls_conn;
            input = new DataInputStream (tls_conn.get_input_stream ());
            output = new DataOutputStream (tls_conn.get_output_stream ());
            trace ("connected to %s:%u as %s".printf (host, port, source_id));
            read_loop_async.begin ();
            return true;
        }

        public void send_json (string @namespace, string destination, string json) throws GLib.Error {
            if (output == null || closing)
                throw new IOError.FAILED ("not connected");

            var frame = new GLib.Bytes (
                build_frame (@namespace, destination, json).data);
            write_queue.push_tail (frame);
            trace ("-> %s %s %s".printf (@namespace, destination, json));
            pump_writes ();
        }

        // Heartbeat replies must leave immediately, even when other frames are
        // queued: the receiver drops the socket ~5 s after a missed PONG.
        public void send_pong (string destination) throws GLib.Error {
            if (output == null || closing)
                throw new IOError.FAILED ("not connected");

            var frame = new GLib.Bytes (
                build_frame (CastService.HEARTBEAT_NAMESPACE, destination,
                    "{\"type\":\"PONG\"}").data);
            write_queue.push_head (frame);
            trace ("-> %s %s {\"type\":\"PONG\"}".printf (
                CastService.HEARTBEAT_NAMESPACE, destination));
            pump_writes ();
        }

        private ByteArray build_frame (string @namespace, string destination,
                string json) {
            var buffer = new ByteArray ();
            var msg = CastMessage ();
            msg.source_id = source_id;
            msg.destination_id = destination;
            msg.namespace_ = @namespace;
            msg.payload_type = 0;
            msg.payload_utf8 = json;
            cast_message_write_frame (buffer, msg);
            return buffer;
        }

        public async void close_async (string reason = "local close") {
            if (closing) {
                yield finish_close_async ();
                return;
            }
            closing = true;
            close_reason = reason;
            draining = false;
            cancellable.cancel ();
            write_queue.clear ();
            yield finish_close_async ();
        }

        // Used by STOP: queue the request first, then close once the write has
        // drained. This keeps the UI non-blocking without dropping the command.
        public void close_after_drain () {
            if (closing) {
                if (!draining)
                    finish_close_async.begin ();
                return;
            }
            closing = true;
            close_reason = "drain";
            draining = true;
            if (!writing && write_queue.is_empty ())
                finish_close_async.begin ();
            else
                pump_writes ();
        }

        private async void finish_close_async () {
            if (closed_emitted || finishing)
                return;
            finishing = true;

            cancellable.cancel ();
            try {
                if (tls != null)
                    yield tls.close_async (GLib.Priority.DEFAULT, null);
            } catch (GLib.Error e) {
                // The peer usually closed first; that is not a failure here.
                trace ("tls close: %s".printf (e.message));
            }

            tls = null;
            input = null;
            output = null;
            emit_closed ();
        }

        private void pump_writes () {
            if (writing || output == null || write_queue.is_empty ())
                return;
            if (closing && !draining)
                return;

            writing = true;
            var frame = write_queue.pop_head ();
            in_flight = frame;
            // Do not copy: the pointer must stay valid for the whole
            // asynchronous write, which is why `in_flight` holds a reference.
            unowned uint8[] data = in_flight.get_data ();
            var stream = output;
            stream.write_all_async.begin (data, GLib.Priority.DEFAULT, cancellable,
                (obj, res) => {
                    try {
                        size_t written;
                        stream.write_all_async.end (res, out written);
                    } catch (GLib.Error e) {
                        writing = false;
                        in_flight = null;
                        GLib.warning ("cast: write failed: %s", e.message);
                        close_async.begin ("write: " + e.message);
                        return;
                    }
                    writing = false;
                    in_flight = null;
                    if (!write_queue.is_empty ())
                        pump_writes ();
                    else if (closing && draining)
                        finish_close_async.begin ();
                });
        }

        private async void read_loop_async () {
            string reason = "eof";
            while (!closing) {
                var len_bytes = new uint8[4];
                size_t read = 0;
                try {
                    var stream = input;
                    yield stream.read_all_async (len_bytes, GLib.Priority.DEFAULT,
                        cancellable, out read);
                } catch (GLib.Error e) {
                    reason = "read: " + e.message;
                    GLib.warning ("cast: read failed: %s", e.message);
                    break;
                }

                if (closing)
                    break;
                if (read < 4) {
                    reason = read == 0 ? "eof" : "short read";
                    break;
                }

                uint32 length = ((uint32) len_bytes[0] << 24) |
                                ((uint32) len_bytes[1] << 16) |
                                ((uint32) len_bytes[2] << 8) |
                                (uint32) len_bytes[3];
                if (length == 0) {
                    reason = "empty frame";
                    GLib.warning ("cast: receiver sent an empty frame");
                    break;
                }
                if (length > 1024 * 1024) {
                    reason = "frame too large: %u".printf (length);
                    GLib.warning ("cast: receiver sent a %u byte frame", length);
                    break;
                }

                var frame = new uint8[length];
                try {
                    var stream = input;
                    yield stream.read_all_async (frame, GLib.Priority.DEFAULT,
                        cancellable, out read);
                } catch (GLib.Error e) {
                    reason = "read: " + e.message;
                    GLib.warning ("cast: read failed: %s", e.message);
                    break;
                }
                if (closing)
                    break;
                if (read < length) {
                    reason = "short frame";
                    break;
                }

                int out_len;
                string? decoded = cast_message_decode_json (frame, out out_len);
                if (decoded == null || decoded == "") {
                    trace ("<- unparsed frame of %u bytes".printf (length));
                    continue;
                }

                trace ("<- %s".printf (decoded));
                string captured = decoded;
                message_received (captured);
            }

            if (draining) {
                if (!writing && write_queue.is_empty ())
                    finish_close_async.begin ();
            } else if (!closing) {
                trace ("closing: %s".printf (reason));
                close_async.begin (reason);
            }
        }

        private void emit_closed () {
            if (closed_emitted)
                return;
            closed_emitted = true;
            trace ("closed: %s".printf (close_reason));
            closed (close_reason);
        }
    }
}