#!/usr/bin/env sh
set -eu

PD_BIN="${PD_BIN:-/home/tsp/projects/pd/pd}"

if [ ! -x "$PD_BIN" ]; then
  jq -nc --arg text "pd" --arg tooltip "pd binary not found at $PD_BIN" '{text:$text, tooltip:$tooltip, class:["error"]}'
  exit 0
fi

if ! status_json="$($PD_BIN status --json --require-daemon 2>/dev/null)"; then
  jq -nc --arg text "pd" --arg tooltip "pd status failed" '{text:$text, tooltip:$tooltip, class:["error"]}'
  exit 0
fi

printf '%s\n' "$status_json" | jq -c '
  . as $pd
  | ($pd.remaining_seconds / 60 | floor) as $mins
  | ($pd.remaining_seconds % 60) as $secs
  | {
      text: (($mins | tostring | if length == 1 then "0" + . else . end) + "\n" + ($secs | tostring | if length == 1 then "0" + . else . end)),
      alt: $pd.phase,
      tooltip: (
        "pd"
        + "\nphase: " + $pd.phase
        + "\nstate: " + $pd.state
        + "\ncycle: " + ($pd.cycle | tostring)
        + "\nnext: " + $pd.next_phase
        + "\nremaining: "
        + ($mins | tostring | if length == 1 then "0" + . else . end)
        + ":"
        + ($secs | tostring | if length == 1 then "0" + . else . end)
        + "\n\nleft click: start"
        + "\nright click: pause"
        + "\nmiddle click: skip"
      ),
      class: [$pd.state, $pd.phase]
    }
'
