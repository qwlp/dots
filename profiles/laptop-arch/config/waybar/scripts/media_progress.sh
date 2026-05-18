#!/usr/bin/env sh
set -eu

MODE="${1:-text}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
STATE_DIR="$RUNTIME_DIR/waybar-media-progress"
STATE_FILE="$STATE_DIR/position-state"
PROGRESS_FILE="/home/tsp/.config/waybar/music-progress.css"
PLAYER_ID=""
STATUS="stopped"
TITLE="Nothing playing"
ARTIST="Start a player"
POSITION_RAW="0"
LENGTH_US="0"
TRACK_ID=""

mkdir -p "$STATE_DIR"

resolve_player() {
    fallback_player=""

    for candidate in com.github.th_ch.youtube_music YoutubeMusic youtube-music; do
        status="$(playerctl -p "$candidate" status 2>/dev/null || true)"

        if [ -z "$status" ]; then
            continue
        fi

        if [ -z "$fallback_player" ]; then
            fallback_player="$candidate"
        fi

        if [ "$status" = "Playing" ]; then
            printf '%s' "$candidate"
            return 0
        fi
    done

    if [ -n "$fallback_player" ]; then
        printf '%s' "$fallback_player"
        return 0
    fi

    return 1
}

PLAYER_ID="$(resolve_player || true)"

if [ -n "$PLAYER_ID" ] && playerctl -p "$PLAYER_ID" status >/dev/null 2>&1; then
    STATUS="$(playerctl -p "$PLAYER_ID" status 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    TITLE="$(playerctl -p "$PLAYER_ID" metadata --format '{{title}}' 2>/dev/null || printf '%s' "$TITLE")"
    ARTIST="$(playerctl -p "$PLAYER_ID" metadata --format '{{artist}}' 2>/dev/null || printf '%s' "$ARTIST")"
    TRACK_ID="$(playerctl -p "$PLAYER_ID" metadata mpris:trackid 2>/dev/null || true)"
    POSITION_RAW="$(playerctl -p "$PLAYER_ID" position 2>/dev/null || printf '0')"
    LENGTH_US="$(playerctl -p "$PLAYER_ID" metadata mpris:length 2>/dev/null || printf '0')"

    [ -n "$TITLE" ] || TITLE="Nothing playing"
    [ -n "$ARTIST" ] || ARTIST="Unknown artist"
fi

[ -n "$TRACK_ID" ] || TRACK_ID="${PLAYER_ID}:${ARTIST}:${TITLE}"

SAFE_TITLE="$(printf '%s' "$TITLE" | jq -Rr @html)"
SAFE_ARTIST="$(printf '%s' "$ARTIST" | jq -Rr @html)"
POSITION_INT="${POSITION_RAW%%.*}"
PERCENTAGE=0
NOW_TS="$(date +%s)"
LAST_TRACK_ID=""
LAST_STATUS="stopped"
LAST_TS=0
LAST_POSITION=0

if [ -f "$STATE_FILE" ]; then
    {
        IFS= read -r LAST_TRACK_ID || true
        IFS= read -r LAST_STATUS || true
        IFS= read -r LAST_TS || true
        IFS= read -r LAST_POSITION || true
    } < "$STATE_FILE"
fi

if [ -z "$POSITION_INT" ]; then
    POSITION_INT=0
fi

if [ "$TRACK_ID" = "$LAST_TRACK_ID" ]; then
    if [ "$STATUS" = "playing" ]; then
        ELAPSED=$((NOW_TS - LAST_TS))

        if [ "$ELAPSED" -lt 0 ]; then
            ELAPSED=0
        fi

        EXPECTED_POSITION=$((LAST_POSITION + ELAPSED))

        if [ "$POSITION_INT" -lt "$EXPECTED_POSITION" ] 2>/dev/null; then
            POSITION_INT=$EXPECTED_POSITION
        fi
    elif [ "$STATUS" = "paused" ] && [ "$POSITION_INT" -lt "$LAST_POSITION" ] 2>/dev/null; then
        POSITION_INT=$LAST_POSITION
    fi
fi

if [ "$LENGTH_US" -gt 0 ] 2>/dev/null; then
    LENGTH_SECONDS=$((LENGTH_US / 1000000))

    if [ "$LENGTH_SECONDS" -gt 0 ]; then
        if [ "$POSITION_INT" -gt "$LENGTH_SECONDS" ]; then
            POSITION_INT=$LENGTH_SECONDS
        fi

        PERCENTAGE=$((POSITION_INT * 100 / LENGTH_SECONDS))
    fi
fi

if [ "$PERCENTAGE" -lt 0 ]; then
    PERCENTAGE=0
fi

if [ "$PERCENTAGE" -gt 100 ]; then
    PERCENTAGE=100
fi

TMP_STATE_FILE="${STATE_FILE}.tmp"

printf '%s\n%s\n%s\n%s\n' "$TRACK_ID" "$STATUS" "$NOW_TS" "$POSITION_INT" > "$TMP_STATE_FILE"
mv "$TMP_STATE_FILE" "$STATE_FILE"

PROGRESS_CSS="$(printf '%s\n%s\n%s' \
    '#media {' \
    "    background-size: ${PERCENTAGE}% 2px, 100% 2px, 100% 100%;" \
    '}')"
TMP_PROGRESS_FILE="${PROGRESS_FILE}.tmp"

printf '%s\n' "$PROGRESS_CSS" > "$TMP_PROGRESS_FILE"

if [ ! -f "$PROGRESS_FILE" ] || ! cmp -s "$TMP_PROGRESS_FILE" "$PROGRESS_FILE"; then
    mv "$TMP_PROGRESS_FILE" "$PROGRESS_FILE"
else
    rm -f "$TMP_PROGRESS_FILE"
fi

TEXT="<span size='small' weight='600'>${SAFE_ARTIST} - ${SAFE_TITLE}</span>"

case "$MODE" in
    cover)
        ICON=""
        [ "$STATUS" = "paused" ] && ICON="󰏤"
        jq -nc --arg text "$ICON" --arg status "$STATUS" '{text: $text, class: [$status]}'
        ;;
    text)
        jq -nc \
            --arg text "$TEXT" \
            --arg tooltip "$ARTIST - $TITLE" \
            --arg status "$STATUS" \
            --arg progress "progress-${PERCENTAGE}" \
            '{text: $text, tooltip: $tooltip, class: [$status, $progress]}'
        ;;
    *)
        exit 1
        ;;
esac
