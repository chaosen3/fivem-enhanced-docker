#!/bin/sh
# FXServer launcher for the fivem-enhanced image.
#
# The Cfx.re server artifact is NOT shipped in this image. On first start (or
# when CFX_URL changes) this script downloads the artifact you point it at into
# /opt/cfx, then execs cfx-server through the artifact's own musl loader with
# the `citizen_dir` setting that GTA V Enhanced needs.
set -eu

CFX_DIR="${CFX_DIR:-/opt/cfx}"
SERVER="$CFX_DIR/alpine/opt/cfx-server/cfx-server"
STAMP="$CFX_DIR/.artifact-url"

log() { printf '[fivem-enhanced] %s\n' "$*" >&2; }

need_fetch() {
    [ "${CFX_FORCE_FETCH:-0}" = "1" ] && return 0
    [ -x "$SERVER" ] || return 0
    # A URL that differs from the one recorded on the last fetch means a new
    # build was requested; a pre-populated volume with no stamp is left alone.
    if [ -n "${CFX_URL:-}" ] && [ -f "$STAMP" ] && [ "$(cat "$STAMP")" != "$CFX_URL" ]; then
        return 0
    fi
    return 1
}

fetch() {
    if [ -z "${CFX_URL:-}" ]; then
        log "no server artifact at $SERVER and CFX_URL is not set."
        log "set CFX_URL to the Linux server artifact link from the Cfx.re Server Download page"
        log "(https://docs.fivem.net/docs/server-download/) and start again."
        exit 64
    fi
    tmp="$(mktemp -d)"
    log "fetching $CFX_URL"
    curl -fSL --retry 3 --retry-delay 5 -o "$tmp/cfx-server.tar.xz" "$CFX_URL"
    if [ -n "${CFX_SHA256:-}" ]; then
        echo "$CFX_SHA256  $tmp/cfx-server.tar.xz" | sha256sum -c - >/dev/null \
            || { log "sha256 of the download does not match CFX_SHA256"; exit 65; }
        log "sha256 verified"
    fi
    mkdir -p "$tmp/x"
    tar -xJf "$tmp/cfx-server.tar.xz" -C "$tmp/x"
    [ -f "$tmp/x/alpine/opt/cfx-server/cfx-server" ] \
        || { log "archive did not contain alpine/opt/cfx-server/cfx-server; not an FXServer linux artifact?"; exit 66; }
    # Replace the old tree only after the new one extracted cleanly.
    rm -rf "$CFX_DIR/alpine" "$CFX_DIR/run.sh"
    mv "$tmp/x/alpine" "$CFX_DIR/alpine"
    [ -f "$tmp/x/run.sh" ] && mv "$tmp/x/run.sh" "$CFX_DIR/run.sh"
    chmod 0755 "$SERVER"
    printf '%s\n' "$CFX_URL" > "$STAMP"
    rm -rf "$tmp"
    log "artifact installed in $CFX_DIR"
}

if need_fetch; then
    fetch
fi

cd "${TXHOST_DATA_PATH:-/txData}"

# This is what the artifact's own run.sh does, inlined so the container needs
# no bash. `+set citizen_dir` is the Enhanced trap: without it the server
# cannot find its own citizen/ tree and segfaults on start.
exec "$CFX_DIR/alpine/lib/ld-musl-x86_64.so.1" \
    --library-path "$CFX_DIR/alpine/lib/:$CFX_DIR/alpine/usr/lib/" \
    -- "$CFX_DIR/alpine/opt/cfx-server/cfx-server" \
    +set citizen_dir "$CFX_DIR/alpine/opt/cfx-server/citizen/" \
    "$@"
