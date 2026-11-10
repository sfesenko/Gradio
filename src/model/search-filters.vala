// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    // Optional radio-browser search filters. All values are trimmed on write
    // so an empty value means "no filter".
    public class SearchFilters : GLib.Object {
        private string _country = "";
        private string _state = "";
        private string _language = "";
        private string _tag = "";

        public string country {
            get { return _country; }
            set { _country = value.strip (); }
        }

        public string state {
            get { return _state; }
            set { _state = value.strip (); }
        }

        public string language {
            get { return _language; }
            set { _language = value.strip (); }
        }

        public string tag {
            get { return _tag; }
            set { _tag = value.strip (); }
        }

        public bool is_empty () {
            return country == "" && state == "" && language == "" && tag == "";
        }
    }

    public enum SearchFilterKind {
        COUNTRY,
        STATE,
        LANGUAGE,
        TAG
    }
}
