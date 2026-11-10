// SPDX-License-Identifier: GPL-3.0-or-later

namespace Gradio {

    public enum LibrarySortMode {
        MANUAL,
        NAME,
        COUNTRY,
        BITRATE
    }

    public enum SearchSortMode {
        RELEVANCE,
        CLICKS,
        VOTES,
        BITRATE
    }

    // Pure station ordering helpers. Sorting always works on a copy so the
    // model's insertion order (Manual) is never lost.
    public class StationSort {
        public static string library_to_string (LibrarySortMode mode) {
            switch (mode) {
                case LibrarySortMode.NAME:
                    return "name";
                case LibrarySortMode.COUNTRY:
                    return "country";
                case LibrarySortMode.BITRATE:
                    return "bitrate";
                default:
                    return "manual";
            }
        }

        public static LibrarySortMode library_from_string (string value) {
            switch (value) {
                case "name":
                    return LibrarySortMode.NAME;
                case "country":
                    return LibrarySortMode.COUNTRY;
                case "bitrate":
                    return LibrarySortMode.BITRATE;
                default:
                    return LibrarySortMode.MANUAL;
            }
        }

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

        public static GLib.GenericArray<RadioStation> sort_library (
                GLib.GenericArray<RadioStation> stations, LibrarySortMode mode) {
            var result = copy (stations);
            switch (mode) {
                case LibrarySortMode.NAME:
                    result.sort (compare_name);
                    break;
                case LibrarySortMode.COUNTRY:
                    result.sort (compare_country);
                    break;
                case LibrarySortMode.BITRATE:
                    result.sort (compare_bitrate);
                    break;
                default:
                    break;
            }
            return result;
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

        private static int compare_country (RadioStation a, RadioStation b) {
            int result = compare_text (a.country, b.country);
            if (result != 0)
                return result;
            return compare_name (a, b);
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
