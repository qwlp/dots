#!/usr/bin/env sh
set -eu

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
CACHE_DIR="$RUNTIME_DIR/waybar-album-art"
CACHE_FILE="$CACHE_DIR/current-cover"
URL_FILE="$CACHE_DIR/current-url"
PLACEHOLDER="/home/tsp/.config/waybar/music-placeholder.svg"
COLOR_FILE="/home/tsp/.config/waybar/music-colors.css"
PLAYER_ID=""

mkdir -p "$CACHE_DIR"

resolve_player() {
    for candidate in com.github.th_ch.youtube_music YoutubeMusic youtube-music; do
        if playerctl -p "$candidate" status >/dev/null 2>&1; then
            printf '%s' "$candidate"
            return 0
        fi
    done

    return 1
}

write_colors() {
    image_path="$1"
    rgb="$(ffmpeg -v error -i "$image_path" -vf "scale=1:1,format=rgb24" -frames:v 1 -f rawvideo - 2>/dev/null | od -An -tu1 -N3 || true)"
    set -- $rgb
    r="${1:-88}"
    g="${2:-31}"
    b="${3:-104}"

    bg_r=$((r * 70 / 100))
    bg_g=$((g * 70 / 100))
    bg_b=$((b * 70 / 100))
    new_css="$(printf '%s\n%s\n%s' \
        "@define-color music_bg rgba(${bg_r}, ${bg_g}, ${bg_b}, 0.62);" \
        "@define-color music_border rgba(255, 255, 255, 0.34);" \
        "@define-color music_border_soft rgba(255, 255, 255, 0.22);")"
    tmp_file="$CACHE_DIR/music-colors.tmp"

    printf '%s\n' "$new_css" > "$tmp_file"

    if [ ! -f "$COLOR_FILE" ] || ! cmp -s "$tmp_file" "$COLOR_FILE"; then
        mv "$tmp_file" "$COLOR_FILE"
    else
        rm -f "$tmp_file"
    fi
}

PLAYER_ID="$(resolve_player || true)"
ART_URL=""
TITLE="Nothing playing"
ARTIST="Start a player"

if [ -n "$PLAYER_ID" ]; then
    ART_URL="$(playerctl -p "$PLAYER_ID" metadata mpris:artUrl 2>/dev/null || true)"
    TITLE="$(playerctl -p "$PLAYER_ID" metadata --format '{{title}}' 2>/dev/null || printf 'Nothing playing')"
    ARTIST="$(playerctl -p "$PLAYER_ID" metadata --format '{{artist}}' 2>/dev/null || printf 'Start a player')"
fi

TOOLTIP="$ARTIST - $TITLE"

if [ -z "$ART_URL" ]; then
    write_colors "$PLACEHOLDER"
    printf '%s\n%s\n' "$PLACEHOLDER" "$TOOLTIP"
    exit 0
fi

PREV_URL=""
if [ -f "$URL_FILE" ]; then
    IFS= read -r PREV_URL < "$URL_FILE" || true
fi

if [ "$ART_URL" != "$PREV_URL" ] || [ ! -s "$CACHE_FILE" ]; then
    if curl -Lsf "$ART_URL" -o "$CACHE_FILE.tmp"; then
        mv "$CACHE_FILE.tmp" "$CACHE_FILE"
        printf '%s\n' "$ART_URL" > "$URL_FILE"
    else
        rm -f "$CACHE_FILE.tmp"
    fi
fi

if [ -s "$CACHE_FILE" ]; then
    write_colors "$CACHE_FILE"
    printf '%s\n%s\n' "$CACHE_FILE" "$TOOLTIP"
else
    write_colors "$PLACEHOLDER"
    printf '%s\n%s\n' "$PLACEHOLDER" "$TOOLTIP"
fi
