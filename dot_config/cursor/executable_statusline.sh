#!/usr/bin/env bash
# cursor-agent status line: session on line 1, then two plain usage lines.
# The session line shrinks to render_width_chars. Usage does not.
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
canon_token() {
  local t
  t=$(tr '[:upper:]' '[:lower:]' <<<"$1")
  printf '%s' "${t//[^a-z0-9.]/}"
}
take_token() { # 0 if the word is effort or fast
  local t
  t=$(canon_token "$1")
  case $t in
    none | minimal | low | medium | high | xhigh | max | thinking) effort=$t; return 0 ;;
    fast) fast=1; return 0 ;;
  esac
  return 1
}

if [[ -n $served ]]; then
  base=()
  IFS=- read -ra parts <<<"$served"
  for p in "${parts[@]}"; do
    take_token "$p" || base+=("$p")
  done
  model="Auto→$(pretty_slug "$(IFS=-; echo "${base[*]}")")"
else
  # display_name often already includes context and effort ("Grok 4.7 256K Medium").
  # param_summary repeats those tokens; keep each visible token once. Effort is printed later.
  leftover=()
  seen=" "
  for w in $model $params; do
    key=$(canon_token "$w")
    [[ -z $key ]] && continue
    take_token "$key" && continue
    [[ $seen == *" $key "* ]] && continue
    seen+="$key "
    leftover+=("$w")
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
# Whole units only: Nd Nh when a day remains, Nh Nm when hours remain, otherwise Nm.
remain_label() { # absolute epoch ms; empty if unknown
  local ms=${1:-} left d h m
  [[ -n $ms ]] || return 0
  left=$((ms - now * 1000))
  ((left < 0)) && left=0
  d=$((left / 86400000))
  h=$(((left % 86400000) / 3600000))
  m=$(((left % 3600000) / 60000))
  if ((d >= 1)); then
    printf '%dd %dh' "$d" "$h"
  elif ((h >= 1)); then
    printf '%dh %dm' "$h" "$m"
  else
    printf '%dm' "$m"
  fi
}

total_pct="" auto_pct="" api_pct="" cycle_end_ms="" grok_pct="" grok_reset_ms="" grok_available=""
if [[ -s $usage_cache ]] && jq -e '.updated' "$usage_cache" >/dev/null 2>&1; then
  have_usage=1
  IFS=$'\x1f' read -r total_pct auto_pct api_pct cycle_end_ms grok_pct grok_reset_ms grok_available < <(jq -r \
    '[
      ((.month_pct // 0) | floor | tostring),
      (if .auto_pct == null then "" else (.auto_pct | floor | tostring) end),
      (if .api_pct == null then "" else (.api_pct | floor | tostring) end),
      (if .cycle_end == null then "" else (.cycle_end | tostring) end),
      (if .grok_pct == null then "" else (.grok_pct | floor | tostring) end),
      (if .grok_reset_ms == null then "" else (.grok_reset_ms | tostring) end),
      (if .grok_available == null then "" elif .grok_available then "1" else "0" end)
    ] | join("\u001f")' "$usage_cache")
  reset_in=$(remain_label "$cycle_end_ms")
  grok_reset_in=$(remain_label "$grok_reset_ms")
elif [[ -s $usage_cache ]]; then
  usage_error=$(jq -r '.error // empty' "$usage_cache" 2>/dev/null || true)
fi

session_line full
if ((${#plain} > width)); then
  session_line short
  if ((${#plain} > width)); then
    session_line bare
  fi
fi
printf '%s\n' "$out"

if ((have_usage)); then
  cursor_line="  📅 Cursor: ${total_pct}% usado"
  [[ -n $reset_in ]] && cursor_line+=" · reset en ${reset_in}"
  grok_txt=""
  if [[ $grok_available == 0 ]]; then
    grok_txt="agotado"
  elif [[ -n $grok_pct ]]; then
    grok_txt="${grok_pct}% usado"
  fi
  if [[ -n $grok_txt ]]; then
    [[ -n $grok_reset_in ]] && grok_txt+=" · reset en ${grok_reset_in}"
    cursor_line+=" | 🤖 Grok Bot: ${grok_txt}"
  fi
  printf '%s\n' "$cursor_line"
  auto_txt="" api_txt=""
  [[ -n $auto_pct ]] && auto_txt="Balde Auto: ${auto_pct}% usado."
  [[ -n $api_pct ]] && api_txt="Balde API: ${api_pct}% usado."
  if [[ -n $auto_txt && -n $api_txt ]]; then
    printf '  %s | %s\n' "$auto_txt" "$api_txt"
  elif [[ -n $auto_txt || -n $api_txt ]]; then
    printf '  %s\n' "${auto_txt}${api_txt}"
  fi
elif [[ -n $usage_error ]]; then
  printf '%s\n' "${E}[31muso: ${usage_error}${E}[0m"
else
  printf '%s\n' "${E}[90muso: cargando…${E}[0m"
fi
