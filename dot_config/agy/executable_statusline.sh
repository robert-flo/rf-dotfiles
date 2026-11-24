#!/usr/bin/env bash
# Statusline de agy. Lee el JSON de la sesión por stdin e imprime tres renglones.
# El JSON no se escribe a disco.
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

remaining_percent() {
  local scaled
  scaled=$(awk -v r="$1" 'BEGIN { printf "%.12f", (r + 0) * 100 }')
  round_nearest "$scaled"
}

# Nd Nh si falta al menos un día; Nh Nm si faltan horas; si no, Nm.
reset_label() {
  local seconds=${1%%.*}
  local days hours minutes
  if ((seconds < 0)); then
    seconds=0
  fi
  days=$((seconds / 86400))
  hours=$(((seconds % 86400) / 3600))
  minutes=$(((seconds % 3600) / 60))
  if ((days >= 1)); then
    printf '%dd %dh' "$days" "$hours"
  elif ((hours >= 1)); then
    printf '%dh %dm' "$hours" "$minutes"
  else
    printf '%dm' "$minutes"
  fi
}

# Verde ≥50, amarillo ≥20, rojo por debajo. El texto queda contiguo para poder buscarlo.
remain_color() {
  local pct=$1
  if ((pct >= 50)); then
    printf 32
  elif ((pct >= 20)); then
    printf 33
  else
    printf 31
  fi
}

paint() {
  printf '\033[%sm%s\033[0m' "$1" "$2"
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

week_pct=$(remaining_percent "$gemini_week_remaining")
window_pct=$(remaining_percent "$gemini_5h_remaining")
p3_5h_pct=$(remaining_percent "$p3_5h_remaining")
p3_week_pct=$(remaining_percent "$p3_week_remaining")

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
printf '  📅 %s (renueva en %s) │ ⚡ %s (renueva en %s)\n' \
  "$(paint "$(remain_color "$week_pct")" "Semanal disp.: ${week_pct}%")" \
  "$(reset_label "$gemini_week_reset")" \
  "$(paint "$(remain_color "$window_pct")" "Ventana (5h) disp.: ${window_pct}%")" \
  "$(reset_label "$gemini_5h_reset")"
printf '  3p 5h: %s%% disp. | 3p semanal: %s%% disp.\n' \
  "$p3_5h_pct" "$p3_week_pct"
