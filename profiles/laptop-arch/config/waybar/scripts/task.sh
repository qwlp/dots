#!/usr/bin/env sh
set -eu

TASK_FILE="${TASK_FILE:-/tmp/current_task.txt}"
TASK="Idle..."

if [ -s "$TASK_FILE" ]; then
    IFS= read -r TASK < "$TASK_FILE" || true
fi

jq -nc --arg text "$TASK" '{text: $text, tooltip: $text}'
