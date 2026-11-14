#!/usr/bin/env bash
# Translation template checks.
#
#   ./po/check-pot.sh             regenerate po/gradio.pot and fail if it drifted
#   ./po/check-pot.sh --coverage  fail if a source file with translatable
#                                 strings is missing from po/POTFILES.in
#
# --coverage runs as part of `meson test`; --drift needs a configured builddir
# and is also the check CI runs.
set -euo pipefail

po_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$po_dir")"
potfiles="$po_dir/POTFILES.in"
pot="$po_dir/gradio.pot"

usage() {
    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
}

# Strip comments and blank lines so the list can be compared as-is.
listed_files() {
    sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$potfiles" | sort
}

check_coverage() {
    local candidates missing
    candidates="$(
        cd "$root"
        grep -rlE '(_|C_|N_)\([[:space:]]*"' --include='*.vala' src |
            sort
    )"
    missing="$(comm -23 <(printf '%s\n' "$candidates") <(listed_files))"
    if [ -n "$missing" ]; then
        echo "error: po/POTFILES.in is missing these files:" >&2
        while IFS= read -r file; do
            echo "  $file" >&2
        done <<<"$missing"
        return 1
    fi

    local file
    while IFS= read -r file; do
        [ -e "$root/$file" ] || {
            echo "error: po/POTFILES.in lists a missing file: $file" >&2
            return 1
        }
    done < <(listed_files)

    echo "po/POTFILES.in covers every source file with translatable strings"
}

# Location comments and the timestamp change on every run, so ignore them.
normalize() {
    grep -vE '^#: |^"POT-Creation-Date:' "$1" || true
}

check_drift() {
    local builddir="${BUILDDIR:-$root/builddir}"
    if [ ! -d "$builddir" ]; then
        echo "configure a build first: meson setup builddir" >&2
        return 2
    fi

    local tmp
    tmp="$(mktemp -d)"

    cp "$pot" "$tmp/old.pot"
    meson compile -C "$builddir" gradio-pot >/dev/null

    normalize "$tmp/old.pot" >"$tmp/old"
    normalize "$pot" >"$tmp/new"
    if ! diff -u --label 'po/gradio.pot (committed)' \
        --label 'po/gradio.pot (extracted)' "$tmp/old" "$tmp/new"; then
        rm -rf "$tmp"
        echo >&2
        echo "error: po/gradio.pot is stale" >&2
        echo "the file above was just regenerated; commit it" >&2
        return 1
    fi
    rm -rf "$tmp"

    echo "po/gradio.pot is up to date"
}

case "${1:-}" in
--coverage) check_coverage ;;
--drift | "") check_drift ;;
-h | --help) usage ;;
*)
    usage >&2
    exit 2
    ;;
esac
