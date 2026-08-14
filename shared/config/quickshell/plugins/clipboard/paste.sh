#!/bin/bash

# Put a history entry back on the clipboard and, unless requested otherwise,
# paste it after the picker has released keyboard focus.

set -euo pipefail

copy_only=false
if [[ ${1:-} == --copy-only ]]; then
  copy_only=true
  shift
fi

case "${1:-}" in
text)
  history_path=${2:?missing clipboard history path}
  history_index=${3:?missing clipboard history index}
  [[ $history_index =~ ^[0-9]+$ ]] || exit 2
  jq -j --argjson index "$history_index" '.[$index].text // empty' "$history_path" |
    wl-copy --type text/plain
  ;;
image)
  mime=${2:?missing image MIME type}
  image_path=${3:?missing image path}
  [[ -f $image_path ]] || exit 2
  wl-copy --type "$mime" <"$image_path"
  ;;
*)
  exit 2
  ;;
esac

if [[ $copy_only == false ]]; then
  # Give the layer-shell window time to release exclusive keyboard focus.
  # 150ms was occasionally too short on Niri during an animation/frame miss.
  sleep 0.25
  wtype -M shift -k Insert -m shift
fi
