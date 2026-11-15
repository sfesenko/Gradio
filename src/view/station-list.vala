// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public enum StationListMode {
        LIBRARY,
        BROWSE
    }

    // Renders a station array into rows. Owns the row signature and, in
    // library mode, drag-and-drop reordering, so callers only pass data in.
    public class StationList : Gtk.Box {
        private Gtk.ListBox list;
        private unowned Elmish.Dispatch<Message> dispatch;
        private StationListMode mode;
        private string signature = "";
        private bool reorderable = false;

        public StationList (Elmish.Dispatch<Message> dispatch, StationListMode mode) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
            this.dispatch = dispatch;
            this.mode = mode;
            hexpand = true;
            list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE,
                show_separators = true
            };
            append (list);
        }

        public void update (GLib.GenericArray<RadioStation> stations, AppModel model) {
            bool show_technical_info = model.config.show_technical_info;
            int icon_size = model.config.icon_size;
            reorderable = mode == StationListMode.LIBRARY &&
                model.config.library_sort == LibrarySortMode.CUSTOM;

            string next = signature_for (stations, show_technical_info, icon_size);
            if (next != signature) {
                signature = next;
                list.remove_all ();
                for (uint i = 0; i < stations.length; i++) {
                    var station = stations.get (i);
                    var row = new StationRow (station,
                        mode == StationListMode.LIBRARY
                            ? StationRowMode.LIBRARY : StationRowMode.BROWSE,
                        show_technical_info, icon_size, dispatch);
                    list.append (row);
                    if (mode == StationListMode.LIBRARY)
                        attach_drag (row);
                    row.set_drag_enabled (reorderable);
                }
            }

            for (uint i = 0; i < stations.length; i++) {
                var station = stations.get (i);
                var row = list.get_row_at_index ((int) i) as StationRow;
                if (row == null)
                    continue;
                row.set_favicon (model.favicon_for (station));
                if (mode == StationListMode.LIBRARY) {
                    bool is_current = model.current_station != null &&
                        model.current_station.id == station.id;
                    row.set_state (is_current, model.playing, false,
                        model.stream_title);
                } else {
                    row.set_state (false, false,
                        model.config.contains_station (station.id));
                }
            }
        }

        private static string signature_for (GLib.GenericArray<RadioStation> stations,
                bool show_technical_info, int icon_size) {
            var builder = new GLib.StringBuilder ();
            for (uint i = 0; i < stations.length; i++) {
                var station = stations.get (i);
                builder.append_printf ("%s\x1f%s\x1f%s\x1f%s\x1f%d\x1f%s\x1e",
                    station.id, station.name, station.country, station.codec,
                    station.bitrate, station.url);
            }
            builder.append_printf ("%s\x1f%d",
                show_technical_info ? "tech" : "plain", icon_size);
            return builder.str;
        }

        private void attach_drag (StationRow row) {
            string station_id = row.station_id;
            var source = new Gtk.DragSource () {
                actions = Gdk.DragAction.MOVE
            };
            source.prepare.connect ((x, y) => {
                var value = GLib.Value (typeof (string));
                value.set_string (station_id);
                return new Gdk.ContentProvider.for_value (value);
            });
            source.drag_begin.connect ((drag) => {
                row.set_dragging (true);
            });
            source.drag_end.connect ((drag, delete_data) => {
                row.set_dragging (false);
                clear_drop_marks ();
            });
            row.attach_drag_source (source);

            var target = new Gtk.DropTarget (typeof (string), Gdk.DragAction.MOVE);
            target.enter.connect ((x, y) => {
                if (!reorderable)
                    return (Gdk.DragAction) 0;
                mark_drop (row, y >= row.get_height () / 2.0);
                return Gdk.DragAction.MOVE;
            });
            target.motion.connect ((x, y) => {
                if (!reorderable)
                    return (Gdk.DragAction) 0;
                mark_drop (row, y >= row.get_height () / 2.0);
                return Gdk.DragAction.MOVE;
            });
            target.leave.connect (() => {
                row.set_drop_mark (StationDropSide.NONE);
            });
            target.drop.connect ((value, x, y) => {
                if (!reorderable)
                    return false;
                string source_id = (string) value;
                bool after = y >= row.get_height () / 2.0;
                clear_drop_marks ();
                if (source_id != "" && source_id != station_id)
                    dispatch (new MoveStationMessage (source_id, station_id, after));
                return true;
            });
            row.add_controller (target);
        }

        private void mark_drop (StationRow row, bool after) {
            clear_drop_marks ();
            row.set_drop_mark (after ? StationDropSide.AFTER : StationDropSide.BEFORE);
        }

        private void clear_drop_marks () {
            for (int i = 0; ; i++) {
                var row = list.get_row_at_index (i) as StationRow;
                if (row == null)
                    break;
                row.set_drop_mark (StationDropSide.NONE);
            }
        }
    }
}
