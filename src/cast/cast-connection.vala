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
        // A short cause, logged by the service when the socket drops.
        public signal void closed (string reason);

        // Unique per connection: reusing a sender id makes the receiver drop the
        // older, live socket.
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
        // Bounds the drain: the socket timeout is disabled, so a write that
        // never completes would otherwise keep the socket open forever.
        private uint drain_timeout_id = 0;
        private const int DRAIN_TIMEOUT_SECONDS = 5;

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

        public async bool connect (string host, int port) throws GLib.Error {
            var client = new SocketClient ();
            // Bound the TCP connect: the OS timeout is ~2 min on Linux.
            client.timeout = 5;
            var conn = yield client.connect_to_host_async (host, (uint16) port,
                cancellable);
            // GSocketClient also applies its timeout to the returned socket,
            // which would race the receiver's heartbeat.
            var socket = conn.get_socket ();
            if (socket != null)
                socket.timeout = 0;
            var tls_conn = TlsClientConnection.@new (conn, null);
            // Self-signed certificate on the local network; the address comes
            // from mDNS, so accept it.
            tls_conn.accept_certificate.connect ((cert, errors) => true);
            yield tls_conn.handshake_async (GLib.Priority.DEFAULT, cancellable);

            if (closing) {
                // close_async() ran while the handshake was in flight: release the
                // socket instead of installing it on a dead connection.
                try {
                    yield conn.close_async (GLib.Priority.DEFAULT, null);
                } catch (GLib.Error e) {
                    // The peer is already gone.
                }
                throw new IOError.CANCELLED ("closed during connect");
            }

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

        // Replies must leave immediately, even behind queued frames.
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
            drain_timeout_id = GLib.Timeout.add_seconds (DRAIN_TIMEOUT_SECONDS,
                () => {
                    drain_timeout_id = 0;
                    if (!closed_emitted)
                        finish_close_async.begin ();
                    return false;
                });
            if (!writing && write_queue.is_empty ())
                finish_close_async.begin ();
            else
                pump_writes ();
        }

        private async void finish_close_async () {
            if (closed_emitted || finishing)
                return;
            finishing = true;
            if (drain_timeout_id != 0) {
                GLib.Source.remove (drain_timeout_id);
                drain_timeout_id = 0;
            }

            cancellable.cancel ();
            if (tls != null) {
                GLib.IOStream base_stream = tls.base_io_stream;
                var close_cancellable = new GLib.Cancellable ();
                uint guard_id = 0;
                guard_id = GLib.Timeout.add_seconds (1, () => {
                    guard_id = 0;
                    close_cancellable.cancel ();
                    return false;
                });
                try {
                    yield tls.close_async (GLib.Priority.DEFAULT, close_cancellable);
                } catch (GLib.Error e) {
                    // A peer that already vanished is not a failure here.
                    trace ("tls close: %s".printf (e.message));
                }
                if (guard_id != 0) {
                    GLib.Source.remove (guard_id);
                    guard_id = 0;
                }
                // A cancelled TLS close skips the base close. Release the socket here
                // instead of leaving it to finalization, which closes synchronously.
                if (!base_stream.is_closed ()) {
                    try {
                        yield base_stream.close_async (GLib.Priority.DEFAULT, null);
                    } catch (GLib.Error e) {
                        trace ("socket close: %s".printf (e.message));
                    }
                }
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
                        if (closing) {
                            finish_close_async.begin ();
                            return;
                        }
                        GLib.debug ("cast: write failed: %s", e.message);
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
                    // close_async() cancels the read loop; that is a normal
                    // shutdown, not a failure worth a warning.
                    if (!closing)
                        GLib.debug ("cast: read failed: %s", e.message);
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
                    if (!closing)
                        GLib.debug ("cast: read failed: %s", e.message);
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