// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public class SettingsDialog : Gtk.Window {
        public SettingsDialog (Gtk.Window parent, AppConfig config, Elmish.Dispatch<Message> dispatch) {
            Object (transient_for: parent, modal: true, title: _("Preferences"), default_width: 360);

            var header = new Gtk.HeaderBar ();
            set_titlebar (header);

            var list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE,
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12
            };

            var technical_toggle = new Gtk.Switch () {
                active = config.show_technical_info,
                valign = Gtk.Align.CENTER
            };
            technical_toggle.state_set.connect ((state) => {
                dispatch (new SetShowTechnicalInfoMessage (state));
                return false;
            });
            list.append (build_row (_("Show technical information"), technical_toggle));

            var resume_toggle = new Gtk.Switch () {
                active = config.resume_playback,
                valign = Gtk.Align.CENTER
            };
            resume_toggle.state_set.connect ((state) => {
                dispatch (new SetResumePlaybackMessage (state));
                return false;
            });
            list.append (build_row (_("Resume playback on startup"), resume_toggle));

            var background_toggle = new Gtk.Switch () {
                active = config.background_playback,
                valign = Gtk.Align.CENTER
            };
            background_toggle.state_set.connect ((state) => {
                dispatch (new SetBackgroundPlaybackMessage (state));
                return false;
            });
            list.append (build_row (_("Keep playing when the window is closed"), background_toggle));

            var cast_quit_toggle = new Gtk.Switch () {
                active = config.cast_keep_on_quit,
                valign = Gtk.Align.CENTER
            };
            cast_quit_toggle.state_set.connect ((state) => {
                dispatch (new SetCastKeepOnQuitMessage (state));
                return false;
            });
            list.append (build_row (_("Keep casting when Gradio quits"),
                cast_quit_toggle));

            var cast_titles_toggle = new Gtk.Switch () {
                active = config.cast_track_titles,
                valign = Gtk.Align.CENTER
            };
            int[] intervals = Gradio.AppConfig.track_titles_interval_choices ();
            var interval_labels = new string[intervals.length];
            for (int i = 0; i < intervals.length; i++)
                interval_labels[i] = _("%d seconds").printf (intervals[i]);
            var cast_titles_interval =
                new Gtk.DropDown.from_strings (interval_labels);
            uint selected_interval = 1;
            for (int i = 0; i < intervals.length; i++) {
                if (intervals[i] == config.cast_track_titles_interval)
                    selected_interval = (uint) i;
            }
            cast_titles_interval.selected = selected_interval;
            cast_titles_interval.sensitive = config.cast_track_titles;
            cast_titles_interval.notify["selected"].connect (() => {
                uint index = cast_titles_interval.selected;
                if (index < intervals.length)
                    dispatch (new SetCastTrackTitlesIntervalMessage (
                        intervals[index]));
            });
            cast_titles_toggle.state_set.connect ((state) => {
                dispatch (new SetCastTrackTitlesMessage (state));
                cast_titles_interval.sensitive = state;
                return false;
            });
            list.append (build_row (_("Show track titles while casting"),
                cast_titles_toggle));
            list.append (build_row (_("Check for new titles every"),
                cast_titles_interval));

            var notifications_toggle = new Gtk.Switch () {
                active = config.notifications_enabled,
                valign = Gtk.Align.CENTER
            };
            notifications_toggle.state_set.connect ((state) => {
                dispatch (new SetNotificationsMessage (state));
                return false;
            });
            list.append (build_row (_("Show notifications"), notifications_toggle));

            var cast_loss_dropdown = new Gtk.DropDown.from_strings ({
                _("Stop playback"), _("Play on this computer")
            });
            cast_loss_dropdown.selected =
                config.cast_loss_action == CastLossAction.PLAY_LOCAL ? 1 : 0;
            cast_loss_dropdown.notify["selected"].connect (() => {
                dispatch (new SetCastLossActionMessage (
                    cast_loss_dropdown.selected == 1
                        ? CastLossAction.PLAY_LOCAL : CastLossAction.WAIT));
            });
            list.append (build_row (_("When a cast is lost"), cast_loss_dropdown));

            var status_bar_toggle = new Gtk.Switch () {
                active = config.show_status_bar,
                valign = Gtk.Align.CENTER
            };
            status_bar_toggle.state_set.connect ((state) => {
                dispatch (new SetShowStatusBarMessage (state));
                return false;
            });
            list.append (build_row (_("Show app feedback in the status bar"), status_bar_toggle));

            var player_in_header_toggle = new Gtk.Switch () {
                active = config.player_in_header,
                valign = Gtk.Align.CENTER
            };
            player_in_header_toggle.state_set.connect ((state) => {
                dispatch (new SetPlayerInHeaderMessage (state));
                return false;
            });
            list.append (build_row (_("Player in the header bar"), player_in_header_toggle));

            int[] icon_sizes = { 32, 48, 64, 96 };
            var icon_size = new Gtk.DropDown.from_strings ({ "32", "48", "64", "96" });
            uint selected = 0;
            for (int i = 0; i < icon_sizes.length; i++) {
                if (icon_sizes[i] == config.icon_size)
                    selected = (uint) i;
            }
            icon_size.selected = selected;
            icon_size.notify["selected"].connect (() => {
                uint index = icon_size.selected;
                if (index < icon_sizes.length)
                    dispatch (new SetIconSizeMessage (icon_sizes[index]));
            });
            list.append (build_row (_("Station icon size"), icon_size));

            var clear_favicons = new Gtk.Button.with_label (_("Clear")) {
                valign = Gtk.Align.CENTER
            };
            clear_favicons.clicked.connect (() => dispatch (new ClearFaviconCacheMessage ()));
            list.append (build_row (_("Favicon cache"), clear_favicons));

            set_child (list);
        }

        private Gtk.ListBoxRow build_row (string label, Gtk.Widget control) {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
                margin_top = 8,
                margin_bottom = 8
            };
            var text = new Gtk.Label (label) {
                halign = Gtk.Align.START,
                hexpand = true
            };
            box.append (text);
            box.append (control);

            var row = new Gtk.ListBoxRow ();
            row.set_child (box);
            return row;
        }
    }
}
