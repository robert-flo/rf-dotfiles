#!/usr/bin/env bash
# Statusline de agy. Lee el JSON de la sesión por stdin e imprime tres renglones.
set -euo pipefail
export LC_ALL=C.UTF-8

input=$(cat)

round_nearest() {
  awk -v x="$1" 'BEGIN {
    n = x + 0
    if (n < 0) n = 0
    if (n > 100) n = 100
    printf "%d", int(n + 0.5)
  }'
}

used_percent() {
  awk -v r="$1" 'BEGIN {
    n = 100 - (r + 0) * 100
    if (n < 0) n = 0
    if (n > 100) n = 100
    printf "%d", int(n + 0.5)
  }'
}

reset_label() {
  local seconds=${1%%.*}
  if ((seconds < 48 * 3600)); then
    printf '%dh' $((seconds / 3600))
  else
    printf '%dd' $((seconds / 86400))
  fi
}

bar() {
  local pct=$1 width=10 filled i out=""
  if ((pct > 100)); then pct=100; fi
  if ((pct < 0)); then pct=0; fi
  filled=$((pct * width / 100))
  for ((i = 0; i < width; i++)); do
    if ((i < filled)); then
      out+="▓"
    else
      out+="░"
    fi
  done
  printf '%s' "$out"
}

IFS=$'\x1f' read -r display effort ctx_raw dir gemini_5h_remaining gemini_5h_reset gemini_week_remaining gemini_week_reset p3_5h_remaining p3_week_remaining < <(
  jq -r '[
    .model.display_name // "",
    .model.effort // "",
    (.context_window.used_percentage // 0 | tostring),
    .workspace.current_dir // "",
    (.quota["gemini-5h"].remaining_fraction // 1 | tostring),
    (.quota["gemini-5h"].reset_in_seconds // 0 | tostring),
    (.quota["gemini-weekly"].remaining_fraction // 1 | tostring),
    (.quota["gemini-weekly"].reset_in_seconds // 0 | tostring),
    (.quota["3p-5h"].remaining_fraction // 1 | tostring),
    (.quota["3p-weekly"].remaining_fraction // 1 | tostring)
  ] | join("\u001f")' <<<"$input"
)

dir=${dir%/}
base=${dir##*/}
pct=$(round_nearest "$ctx_raw")
branch=""
if [[ -n $dir && -d $dir ]] && b=$(git -C "$dir" branch --show-current 2>/dev/null); then
  if [[ -z $b ]]; then
    b=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || true)
  fi
  if [[ -n $(git -C "$dir" status --porcelain --untracked-files=no 2>/dev/null) ]]; then
    b+="*"
  fi
  branch=$b
fi

line=$display
if [[ -n $effort ]]; then
  line+=" $effort"
fi
line+=" $(bar "$pct") ${pct}%"
if [[ -n $base ]]; then
  line+=" $base"
fi
if [[ -n $branch ]]; then
  line+=" ⎇ $branch"
fi
printf '%s\n' "$line"
printf '  Gemini 5h: %s%% usado · reset en %s | Gemini semanal: %s%% usado · reset en %s\n' \
  "$(used_percent "$gemini_5h_remaining")" "$(reset_label "$gemini_5h_reset")" \
  "$(used_percent "$gemini_week_remaining")" "$(reset_label "$gemini_week_reset")"
printf '  3p 5h: %s%% usado. | 3p semanal: %s%% usado.\n' \
  "$(used_percent "$p3_5h_remaining")" "$(used_percent "$p3_week_remaining")"
