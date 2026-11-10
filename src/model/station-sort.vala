// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public enum SearchSortMode {
        RELEVANCE,
        CLICKS,
        VOTES,
        BITRATE
    }

    public enum LibrarySortMode {
        CUSTOM,
        NAME,
        COUNTRY,
        STATE,
        LANGUAGE,
        BITRATE
    }

    // Pure search-result ordering helpers. Sorting works on a copy so the
    // radio-browser result order is never lost.
    public class StationSort {
        public static string search_to_string (SearchSortMode mode) {
            switch (mode) {
                case SearchSortMode.CLICKS:
                    return "clicks";
                case SearchSortMode.VOTES:
                    return "votes";
                case SearchSortMode.BITRATE:
                    return "bitrate";
                default:
                    return "relevance";
            }
        }

        public static SearchSortMode search_from_string (string value) {
            switch (value) {
                case "clicks":
                    return SearchSortMode.CLICKS;
                case "votes":
                    return SearchSortMode.VOTES;
                case "bitrate":
                    return SearchSortMode.BITRATE;
                default:
                    return SearchSortMode.RELEVANCE;
            }
        }

        public static GLib.GenericArray<RadioStation> sort_search (
                GLib.GenericArray<RadioStation> stations, SearchSortMode mode) {
            var result = copy (stations);
            switch (mode) {
                case SearchSortMode.CLICKS:
                    result.sort (compare_clicks);
                    break;
                case SearchSortMode.VOTES:
                    result.sort (compare_votes);
                    break;
                case SearchSortMode.BITRATE:
                    result.sort (compare_bitrate);
                    break;
                default:
                    break;
            }
            return result;
        }

        public static GLib.GenericArray<RadioStation> sort_library (
                GLib.GenericArray<RadioStation> stations, LibrarySortMode mode, bool descending) {
            var result = copy (stations);
            switch (mode) {
                case LibrarySortMode.NAME:
                    result.sort (compare_name);
                    break;
                case LibrarySortMode.COUNTRY:
                    result.sort (compare_country);
                    break;
                case LibrarySortMode.STATE:
                    result.sort (compare_state);
                    break;
                case LibrarySortMode.LANGUAGE:
                    result.sort (compare_language);
                    break;
                case LibrarySortMode.BITRATE:
                    result.sort (compare_bitrate_ascending);
                    break;
                default:
                    return result;
            }
            if (descending) {
                var reversed = new GLib.GenericArray<RadioStation> ();
                for (uint i = result.length; i > 0; i--)
                    reversed.add (result.get (i - 1));
                return reversed;
            }
            return result;
        }

        public static string library_sort_to_string (LibrarySortMode mode) {
            switch (mode) {
                case LibrarySortMode.NAME:
                    return "name";
                case LibrarySortMode.COUNTRY:
                    return "country";
                case LibrarySortMode.STATE:
                    return "state";
                case LibrarySortMode.LANGUAGE:
                    return "language";
                case LibrarySortMode.BITRATE:
                    return "bitrate";
                default:
                    return "custom";
            }
        }

        public static LibrarySortMode library_sort_from_string (string value) {
            switch (value) {
                case "name":
                    return LibrarySortMode.NAME;
                case "country":
                    return LibrarySortMode.COUNTRY;
                case "state":
                    return LibrarySortMode.STATE;
                case "language":
                    return LibrarySortMode.LANGUAGE;
                case "bitrate":
                    return LibrarySortMode.BITRATE;
                default:
                    return LibrarySortMode.CUSTOM;
            }
        }

        private static int compare_country (RadioStation a, RadioStation b) {
            return compare_library (a, b, LibrarySortMode.COUNTRY);
        }

        private static int compare_state (RadioStation a, RadioStation b) {
            return compare_library (a, b, LibrarySortMode.STATE);
        }

        private static int compare_language (RadioStation a, RadioStation b) {
            return compare_library (a, b, LibrarySortMode.LANGUAGE);
        }

        private static int compare_bitrate_ascending (RadioStation a, RadioStation b) {
            return compare_library (a, b, LibrarySortMode.BITRATE);
        }

        private static int compare_library (RadioStation a, RadioStation b, LibrarySortMode mode) {
            int result = 0;
            switch (mode) {
                case LibrarySortMode.NAME:
                    result = compare_name (a, b);
                    break;
                case LibrarySortMode.COUNTRY:
                    result = compare_text (a.country, b.country);
                    break;
                case LibrarySortMode.STATE:
                    result = compare_text (a.state, b.state);
                    break;
                case LibrarySortMode.LANGUAGE:
                    result = compare_text (a.language, b.language);
                    break;
                case LibrarySortMode.BITRATE:
                    if (a.bitrate != b.bitrate)
                        result = a.bitrate < b.bitrate ? -1 : 1;
                    break;
                default:
                    break;
            }
            if (result != 0)
                return result;
            return compare_name (a, b);
        }

        private static GLib.GenericArray<RadioStation> copy (GLib.GenericArray<RadioStation> stations) {
            var result = new GLib.GenericArray<RadioStation> ();
            for (uint i = 0; i < stations.length; i++)
                result.add (stations.get (i));
            return result;
        }

        private static int compare_text (string a, string b) {
            int result = a.down ().collate (b.down ());
            if (result != 0)
                return result;
            return a.collate (b);
        }

        private static int compare_name (RadioStation a, RadioStation b) {
            int result = compare_text (a.name, b.name);
            if (result != 0)
                return result;
            return a.id.collate (b.id);
        }

        private static int compare_bitrate (RadioStation a, RadioStation b) {
            if (a.bitrate != b.bitrate)
                return a.bitrate > b.bitrate ? -1 : 1;
            return compare_name (a, b);
        }

        private static int compare_clicks (RadioStation a, RadioStation b) {
            if (a.clickcount != b.clickcount)
                return a.clickcount > b.clickcount ? -1 : 1;
            return compare_name (a, b);
        }

        private static int compare_votes (RadioStation a, RadioStation b) {
            if (a.votes != b.votes)
                return a.votes > b.votes ? -1 : 1;
            return compare_name (a, b);
        }
    }
}
