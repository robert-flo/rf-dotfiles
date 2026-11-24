#!/usr/bin/env bash
# cursor-agent status line: session info + Cursor usage, adapting to render_width_chars.
# One line when everything fits; otherwise session on line 1 and usage on line 2, shortened as needed.
# Spec: ~/.cursor/skills-cursor/statusline/SKILL.md (payload arrives as JSON on stdin).
export LC_ALL=C.UTF-8 # ${#str} must count characters, not bytes
input=$(cat)
E=$'\033'
SEP=" │ "

# \x1f instead of tabs: read collapses consecutive whitespace delimiters, which shifts empty fields.
IFS=$'\x1f' read -r model_id model params pct dir wt width sid < <(jq -r '[
  .model.id // "",
  .model.display_name // .model.id // "?",
  .model.param_summary // "",
  ((.context_window.used_percentage // 0) | floor | tostring),
  .workspace.current_dir // .cwd // "",
  .worktree.name // "",
  (.render_width_chars // 120 | tostring),
  .session_id // ""
] | join("\u001f")' <<<"$input")

# Builds a line in two buffers: $out with ANSI colors, $plain for measuring width.
out="" plain=""
put() { out+="${E}[${1}m${2}${E}[0m"; plain+="$2"; }
raw() { out+="$1"; plain+="$1"; }
sep() { out+="${E}[90m${SEP}${E}[0m"; plain+="$SEP"; }

bar() { # pct width
  local p=$1 w=$2 f i b=""
  ((p > 100)) && p=100
  f=$((p * w / 100))
  for ((i = 0; i < w; i++)); do if ((i < f)); then b+="▓"; else b+="░"; fi; done
  printf '%s' "$b"
}
level_color() { # pct [yellow-from=50] -> green/yellow/red
  if (($1 >= 80)); then echo 31; elif (($1 >= ${2:-50})); then echo 33; else echo 32; fi
}

# Auto hides the real model; only then look up the last served slug in this chat's store.
# A named selection (Grok, GPT, …) comes from the payload — never overwrite it with an old reply.
served=""
if [[ $model_id == default && -n $sid ]]; then
  for db in "$HOME"/.config/cursor/chats/*/"$sid"/store.db; do
    [[ -f $db ]] || continue
    served=$(sqlite3 -readonly "$db" "select data from blobs
      where rowid > (select max(rowid) - 60 from blobs) and instr(data, '\"modelName\":\"') > 0
      order by rowid desc" 2>/dev/null | rg -o -m1 --no-filename '"modelName":"[a-z0-9.\-]+"' | head -1)
    served=${served#\"modelName\":\"}
    served=${served%\"}
  done
fi

pretty_slug() {
  local slug=$1
  slug=${slug#claude-}
  slug=${slug#cursor-}
  slug=$(sed -E 's/([0-9])-([0-9])/\1.\2/g; s/-/ /g' <<<"$slug")
  printf '%s' "${slug^}"
}

effort="" fast=""
take_token() {
  local t
  t=$(tr '[:upper:]' '[:lower:]' <<<"$1")
  t=${t//[()]/}
  case $t in
    none | minimal | low | medium | high | xhigh | max | thinking) effort=$t ;;
    fast) fast=1 ;;
  esac
}

if [[ -n $served ]]; then
  base=()
  IFS=- read -ra parts <<<"$served"
  for p in "${parts[@]}"; do
    case $p in
      none | minimal | low | medium | high | xhigh | max | thinking | fast) take_token "$p" ;;
      *) base+=("$p") ;;
    esac
  done
  model="Auto→$(pretty_slug "$(IFS=-; echo "${base[*]}")")"
else
  # Named model: display_name often already includes effort ("Grok 4.6 High Fast").
  leftover=()
  for w in $model $params; do
    before=$effort$fast
    take_token "$w"
    [[ $effort$fast == "$before" ]] && leftover+=("$w")
  done
  ((${#leftover[@]})) && model="${leftover[*]}"
fi
[[ -z $effort ]] && effort="default"

effort_color() {
  case $effort in
    low | minimal | none) echo 32 ;;
    medium | default) echo 33 ;;
    *) echo 31 ;;
  esac
}

branch=""
if [[ -n $dir ]] && b=$(git -C "$dir" branch --show-current 2>/dev/null); then
  [[ -z $b ]] && b=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)
  [[ -n $(git -C "$dir" status --porcelain --untracked-files=no 2>/dev/null | head -1) ]] && b+="*"
  branch=$b
fi

# --- nixfredOS segment (playbook Chapter 5): cheap local checks, cached 30s and refreshed in the background.
nfos_cache="${XDG_CACHE_HOME:-$HOME/.cache}/cursor-statusline/nixfredos.json"
nfos_helper="$HOME/.config/cursor/statusline-nixfredos.sh"
have_nfos=0
if [[ -x $nfos_helper ]]; then
  nfos_mtime=$(stat -c %Y "$nfos_cache" 2>/dev/null || echo 0)
  if (($(date +%s) - nfos_mtime > 30)); then
    setsid "$nfos_helper" </dev/null >/dev/null 2>&1 &
  fi
  if [[ -s $nfos_cache ]]; then
    IFS=$'\x1f' read -r nf_da nf_mem nf_sync nf_hooks nf_voice < <(jq -r \
      '[.da, (.mem | tostring), (.sync_ok | tostring), (.hooks_ok | tostring), .voice] | join("\u001f")' \
      "$nfos_cache" 2>/dev/null)
    [[ -n $nf_da || $nf_mem != -1 ]] && have_nfos=1
  fi
fi

nfos_segment() { # full|short
  ((have_nfos)) || return
  local mc hc hs vc m=$nf_mem
  mc=$([[ $nf_sync == 1 ]] && echo 32 || echo 33)
  [[ $m == -1 ]] && m="?" mc=31
  if [[ $nf_hooks == 1 ]]; then hc=32 hs="✓"; else hc=31 hs="✗"; fi
  case $nf_voice in on) vc=32 ;; down) vc=31 ;; *) vc=90 ;; esac
  sep
  put 95 "${nf_da:-nfos}"
  raw " "
  if [[ $1 == full ]]; then
    put 90 "mem " && put "$mc" "$m"
    put 90 " · hooks " && put "$hc" "$hs"
    put 90 " · voz " && put "$vc" "$nf_voice"
  else
    put "$mc" "$m" && raw " " && put "$hc" "$hs" && raw " " && put "$vc" "voz"
  fi
}

session_line() { # full|short|bare
  out="" plain=""
  put 36 "$model"
  raw " "
  if [[ $1 == full ]]; then
    put "$(effort_color)" "$effort" && [[ -n $fast ]] && put 93 " ⚡fast"
  else
    put "$(effort_color)" "${effort:0:3}" && [[ -n $fast ]] && put 93 "⚡"
  fi
  raw " "
  if [[ $1 == full ]]; then
    put "$(level_color "$pct" 60)" "$(bar "$pct" 10) $pct%"
    raw " "
    put 34 "${dir/#$HOME/\~}"
  else
    put "$(level_color "$pct" 60)" "ctx $pct%"
    raw " "
    put 34 "${dir##*/}"
  fi
  [[ -n $branch ]] && raw " " && put 35 "⎇ $branch"
  [[ -n $wt ]] && raw " " && put 90 "wt:$wt"
  [[ $1 != bare ]] && nfos_segment "$1"
}

# --- usage cache: never call the API inline (timeoutMs is 1.5s); refresh it in the background.
usage_cache="${XDG_CACHE_HOME:-$HOME/.cache}/cursor-statusline/usage.json"
now=$(date +%s)
mtime=$(stat -c %Y "$usage_cache" 2>/dev/null || echo 0)
if ((now - mtime > 60)); then
  if [[ -x "$HOME/.config/cursor/statusline-usage.sh" ]]; then
    setsid "$HOME/.config/cursor/statusline-usage.sh" </dev/null >/dev/null 2>&1 &
  fi
fi

have_usage=0
usage_error=""
if [[ -s $usage_cache ]] && jq -e '.updated' "$usage_cache" >/dev/null 2>&1; then
  have_usage=1
  IFS=$'\x1f' read -r h5 h5req h1 sess mpct apct pace runout proj reset reset_days age err gpct greset_days gavail < <(jq -r \
    --arg sid "$sid" --argjson now "$((now * 1000))" '
    def money: if . >= 10000 then "$\(. / 100 | round)"
      else (round) as $c | "$\($c / 100 | floor).\($c % 100 | tostring | if length < 2 then "0" + . else . end)" end;
    def onedec: (. * 10 | round) as $t | "\($t / 10 | floor).\($t % 10)";
    def cal: strftime("%d/%m/%Y");
    ((.cycle_end - .cycle_start) | if . > 0 then . else 1 end) as $len
    | (($now - .cycle_start) / $len | if . > 0.001 then . else 0.001 end) as $elapsed
    | (.auto_pct // .month_pct) as $auto
    | [
        (.h5_cents | money),
        (.h5_requests | tostring),
        (.h1_cents | money),
        (if $sid != "" and .sessions[$sid] then (.sessions[$sid] | money) else "" end),
        ($auto | floor | tostring),
        (if .api_pct == null then "" else (.api_pct | floor | tostring) end),
        ($auto / ($elapsed * 100) | onedec),
        (if $auto >= 100 then "agotado"
         elif $auto > 0 and (.cycle_start + ($now - .cycle_start) * 100 / $auto) < .cycle_end
         then (.cycle_start + ($now - .cycle_start) * 100 / $auto) / 1000 | cal
         else "" end),
        (.month_spend_cents / $elapsed | money),
        (.cycle_end / 1000 | cal),
        (if (.cycle_end - $now) <= 0 then "0"
         else ((.cycle_end - $now) / 86400000 | floor | tostring) end),
        ((($now - .updated) / 1000) | floor | tostring),
        (if .error and (.error_at // 0) > .updated then .error else "" end),
        (if .grok_pct == null then "" else (.grok_pct | tostring) end),
        (if .grok_reset_ms == null then ""
         elif (.grok_reset_ms - $now) <= 0 then "0"
         else ((.grok_reset_ms - $now) / 86400000 | floor | tostring) end),
        (if .grok_available == null then "" elif .grok_available then "1" else "0" end)
      ] | join("\u001f")' "$usage_cache")
elif [[ -s $usage_cache ]]; then
  usage_error=$(jq -r '.error // empty' "$usage_cache" 2>/dev/null || true)
fi

pace_color() {
  awk -v p="$1" 'BEGIN { print (p > 1.5) ? 31 : (p > 1.0) ? 33 : 32 }'
}

# Pace is three tokens (2.0 · x · ritmo · ⚠) so nothing reads as "2.0xritmo⚠".
print_pace() { # full|compact
  local pc
  pc=$(pace_color "$pace")
  case $1 in
    full)
      put 90 " · "
      put "$pc" "${pace}x"
      raw " "
      put 90 "ritmo"
      [[ -n $ahead ]] && raw " " && put 31 "$ahead"
      ;;
    compact)
      raw " "
      put "$pc" "${pace}x"
      raw " "
      put 90 "ritmo"
      [[ -n $ahead ]] && raw " " && put 31 "$ahead"
      ;;
    mini)
      raw " "
      put "$pc" "${pace}x"
      [[ -n $ahead ]] && raw " " && put 31 "$ahead"
      ;;
  esac
}

print_grok_usage() { # full|compact|mini
  [[ -z $gpct ]] && return
  local gc label
  if [[ $gavail == 0 ]]; then
    gc=31
    label="agotado"
  else
    gc=$(level_color "$gpct")
    label="${gpct}%"
  fi
  sep
  case $1 in
    full)
      put 90 "grok "
      if [[ $gavail != 0 ]]; then
        put "$gc" "$(bar "$gpct" 8) $label"
      else
        put "$gc" "$label"
      fi
      if [[ -n $greset_days ]]; then
        if [[ $greset_days == 0 ]]; then put 90 " (hoy)"
        elif [[ $greset_days == 1 ]]; then put 90 " (1d)"
        else put 90 " ($greset_days d)"; fi
      fi
      ;;
    compact)
      put 90 "grok " && put "$gc" "$label"
      [[ -n $greset_days && $greset_days != 0 ]] && put 90 " ${greset_days}d"
      ;;
    mini)
      put 90 "g" && put "$gc" "$label"
      ;;
  esac
}

print_cycle_reset() { # inline|solo — label and date never run together without ": "
  [[ -z $reset ]] && return
  put 90 "Fin de ciclo"
  raw ": "
  put 97 "$reset"
  if [[ -n $reset_days ]]; then
    if [[ $reset_days == 0 ]]; then
      put 90 " (hoy)"
    elif [[ $reset_days == 1 ]]; then
      put 90 " (1 día)"
    else
      put 90 " ($reset_days días)"
    fi
  fi
}

usage_line() { # full|compact|mini [show_reset=1]
  local show_reset=${2:-1}
  out="" plain=""
  if ((!have_usage)); then
    if [[ -n $usage_error ]]; then
      put 31 "uso: $usage_error"
    else
      put 90 "uso: cargando…"
    fi
    return
  fi
  local ahead=""
  [[ $(pace_color "$pace") != 32 ]] && ahead="⚠"
  case $1 in
    full)
      put 90 "5h " && put 36 "$h5" && put 90 " · $h5req req · $h1/h"
      sep
      put 90 "auto " && put "$(level_color "$mpct")" "$(bar "$mpct" 10) $mpct%"
      print_pace full
      [[ -n $runout ]] && put 31 " · agota el $runout"
      [[ -n $apct ]] && put 90 " · api " && put "$(level_color "$apct")" "$apct%"
      put 90 " · proy $proj"
      print_grok_usage full
      [[ -n $sess ]] && sep && put 90 "sesión " && put 36 "$sess"
      ;;
    compact)
      put 90 "5h " && put 36 "$h5" && put 90 " $h1/h"
      sep
      put 90 "auto " && put "$(level_color "$mpct")" "$mpct%"
      print_pace compact
      [[ -n $runout ]] && put 31 " → agota $runout"
      [[ -n $apct ]] && put 90 " api " && put "$(level_color "$apct")" "$apct%"
      print_grok_usage compact
      [[ -n $sess ]] && sep && put 90 "ses " && put 36 "$sess"
      ;;
    mini)
      put 36 "$h5" && raw " " && put "$(level_color "$mpct")" "$mpct%"
      print_pace mini
      print_grok_usage mini
      ;;
  esac
  if [[ -n $err ]]; then
    put 31 " ⚠ $err"
  elif ((age > 600)); then
    put 90 " (hace $((age / 60))m)"
  fi
  if ((show_reset)); then
    sep
    print_cycle_reset inline
  fi
}

session_line full
s_out=$out s_plain=$plain
usage_line full 1
if ((${#s_plain} + ${#SEP} + ${#plain} <= width)); then
  printf '%s%s%s%s\n' "$s_out" "${E}[90m" "$SEP" "${E}[0m$out"
  exit 0
fi

if ((${#s_plain} > width)); then
  session_line short
  s_out=$out
  if ((${#plain} > width)); then
    session_line bare
    s_out=$out
  fi
fi
printf '%s\n' "$s_out"

for level in full compact mini; do
  usage_line "$level" 0
  ((${#plain} <= width)) && break
done
printf '%s\n' "$out"

if [[ -n $reset ]]; then
  out="" plain=""
  print_cycle_reset solo
  printf '%s\n' "$out"
fi
