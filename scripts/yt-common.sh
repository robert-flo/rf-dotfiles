#!/usr/bin/env bash
# ==============================================================================
# yt-common.sh — Helpers compartidos para la suite yt-* (yt-video, etc.)
# ==============================================================================

yt_init_colors() {
  # shellcheck disable=SC2034
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_BOLD=$'\033[1m'
    C_RED=$'\033[31m'
    C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_DIM=$'\033[2m'
    C_RST=$'\033[0m'
  else
    C_BOLD=""; C_RED=""; C_BLUE=""; C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_DIM=""; C_RST=""
  fi
}

yt_is_interactive() {
  if [[ "${YT_FORCE_INTERACTIVE:-0}" == "1" ]]; then
    return 0
  fi
  [[ -t 0 && -t 1 ]]
}

yt_base_dir() {
  if [[ -n "${YT_BASE_DIR:-}" ]]; then
    printf '%s\n' "$YT_BASE_DIR"
  elif [[ -d "/zt" ]]; then
    printf '%s\n' "/zt/yt-downloads"
  else
    printf '%s\n' "$HOME/yt-downloads"
  fi
}

yt_check_deps() {
  local tool="$1"
  shift
  local missing=()
  local bin
  for bin in "$@"; do
    command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
  done
  python3 -c "import curl_cffi" 2>/dev/null || missing+=("python-curl_cffi")
  if [[ ${#missing[@]} -gt 0 ]]; then
    printf '%s[%s] Aviso: faltan dependencias óptimas (%s). Ejecuta '\''chezmoi apply'\''.%s\n' \
      "${C_YELLOW:-}" "$tool" "${missing[*]}" "${C_RST:-}" >&2
  fi
}

# Expande el patrón de idiomas para manuales: p.ej. "en" -> "en,en.*,-live_chat"
_yt_expand_manual_sub_langs() {
  local langs="$1"
  local out=()
  local part
  IFS=',' read -ra parts <<< "$langs"
  for part in "${parts[@]}"; do
    part="${part#"${part%%[![:space:]]*}"}"
    part="${part%"${part##*[![:space:]]}"}"
    [[ -z "$part" ]] && continue
    if [[ "$part" == -* || "$part" == *.* || "$part" == "all" ]]; then
      out+=("$part")
    else
      out+=("$part" "${part}.*")
    fi
  done
  local has_live_chat=false
  for part in "${out[@]}"; do
    if [[ "$part" == "-live_chat" ]]; then
      has_live_chat=true
      break
    fi
  done
  if [[ "$has_live_chat" == false ]]; then
    out+=("-live_chat")
  fi
  local IFS=','
  printf '%s\n' "${out[*]}"
}

# Lista archivos de subtítulos existentes en $dest_dir (.srt o .vtt)
_yt_find_sub_files() {
  local dest_dir="$1"
  find "$dest_dir" -maxdepth 1 -type f \( -name '*.srt' -o -name '*.vtt' \) 2>/dev/null | sort
}

# Pre-chequeo y descarga de subtítulos con mitigación anti-429 antes de bajar video pesado.
# Uso: yt_prepare_subtitles <tool> <url> <dest_dir> <sub_langs> <extra_args_nameref>
# Retorna 0 si se puede continuar con la descarga del video, 1 si el usuario cancela.
yt_prepare_subtitles() {
  local tool="$1"
  local url="$2"
  local dest_dir="$3"
  local sub_langs="$4"
  local -n _extra_ref="$5"

  local retry_sleep="${YT_RETRY_SLEEP:-2}"
  local manual_langs
  manual_langs="$(_yt_expand_manual_sub_langs "$sub_langs")"
  local auto_langs="${sub_langs},-live_chat"
  if [[ "$sub_langs" == *"-live_chat"* ]]; then
    auto_langs="$sub_langs"
  fi

  local before_subs after_subs new_subs
  before_subs="$(_yt_find_sub_files "$dest_dir")"

  printf '%s[%s] Pre-chequeando subtítulos (%s)...%s\n' \
    "${C_CYAN:-}" "$tool" "$sub_langs" "${C_RST:-}" >&2

  local log_file
  log_file="$(mktemp)"

  local sub_ok=false
  local last_err=""

  # Intento 1: subtítulos manuales (evita el endpoint de auto-captions que suele dar 429)
  if yt-dlp --ignore-config --no-playlist --skip-download \
      --write-subs --sub-langs "$manual_langs" --convert-subs srt \
      -P "$dest_dir" "${_extra_ref[@]}" "$url" >"$log_file" 2>&1; then
    after_subs="$(_yt_find_sub_files "$dest_dir")"
    new_subs="$(comm -13 <(printf '%s\n' "$before_subs") <(printf '%s\n' "$after_subs") || true)"
    if [[ -n "$new_subs" ]]; then
      sub_ok=true
    fi
  else
    last_err="$(grep -E '^ERROR:' "$log_file" | tail -n 1 || true)"
  fi

  # Intento 2: auto-captions con pausas anti-429
  if [[ "$sub_ok" == false ]]; then
    if yt-dlp --ignore-config --no-playlist --skip-download \
        --write-subs --write-auto-subs --sub-langs "$auto_langs" \
        --sleep-subtitles 3 --sleep-requests 2 --retries 3 \
        --convert-subs srt -P "$dest_dir" "${_extra_ref[@]}" "$url" >"$log_file" 2>&1; then
      after_subs="$(_yt_find_sub_files "$dest_dir")"
      new_subs="$(comm -13 <(printf '%s\n' "$before_subs") <(printf '%s\n' "$after_subs") || true)"
      if [[ -n "$new_subs" ]]; then
        sub_ok=true
      fi
    else
      last_err="$(grep -E '^ERROR:' "$log_file" | tail -n 1 || true)"
    fi
  fi

  # Intento 3 (mitigación 429): pausa + cliente android + fallback cookies Chrome
  if [[ "$sub_ok" == false && "$last_err" == *"429"* ]]; then
    printf '%s[%s] Aviso: HTTP 429 al descargar subtítulos. Reintentando con mitigación anti-429...%s\n' \
      "${C_YELLOW:-}" "$tool" "${C_RST:-}" >&2
    [[ "$retry_sleep" -gt 0 ]] && sleep "$retry_sleep"

    if yt-dlp --ignore-config --no-playlist --skip-download \
        --write-subs --write-auto-subs --sub-langs "$auto_langs" \
        --extractor-args "youtube:player_client=android" \
        --sleep-subtitles 3 --sleep-requests 2 --retries 3 \
        --convert-subs srt -P "$dest_dir" "${_extra_ref[@]}" "$url" >"$log_file" 2>&1; then
      after_subs="$(_yt_find_sub_files "$dest_dir")"
      new_subs="$(comm -13 <(printf '%s\n' "$before_subs") <(printf '%s\n' "$after_subs") || true)"
      [[ -n "$new_subs" ]] && sub_ok=true
    else
      last_err="$(grep -E '^ERROR:' "$log_file" | tail -n 1 || true)"
    fi

    if [[ "$sub_ok" == false ]]; then
      if yt-dlp --ignore-config --no-playlist --skip-download \
          --write-subs --write-auto-subs --sub-langs "$auto_langs" \
          --cookies-from-browser chrome \
          --sleep-subtitles 3 --sleep-requests 2 \
          --convert-subs srt -P "$dest_dir" "${_extra_ref[@]}" "$url" >"$log_file" 2>&1; then
        after_subs="$(_yt_find_sub_files "$dest_dir")"
        new_subs="$(comm -13 <(printf '%s\n' "$before_subs") <(printf '%s\n' "$after_subs") || true)"
        [[ -n "$new_subs" ]] && sub_ok=true
      else
        last_err="$(grep -E '^ERROR:' "$log_file" | tail -n 1 || true)"
      fi
    fi
  fi

  if [[ "$sub_ok" == true ]]; then
    rm -f "$log_file"
    # shellcheck disable=SC2034
    YT_SUBS_STATUS="ok"
    local sub_names
    sub_names="$(printf '%s\n' "$new_subs" | xargs -r -n1 basename | tr '\n' ' ')"
    printf '%s[%s] Subtítulos listos: %s%s\n' \
      "${C_GREEN:-}" "$tool" "$sub_names" "${C_RST:-}" >&2
    return 0
  fi

  rm -f "$log_file"
  # shellcheck disable=SC2034
  YT_SUBS_STATUS="failed"

  # Fallo explícito (nunca ocultado tras --ignore-errors)
  if [[ -z "$last_err" ]]; then
    last_err="No se encontraron subtítulos disponibles para '$sub_langs'."
  fi
  printf '%s[%s] ERROR en subtítulos: %s%s\n' \
    "${C_RED:-}" "$tool" "$last_err" "${C_RST:-}" >&2

  if yt_is_interactive; then
    local reply=""
    printf '%s[%s] ¿Continuar descargando el video sin estos subtítulos? [s/N]: %s' \
      "${C_YELLOW:-}" "$tool" "${C_RST:-}" >&2
    if ! read -r reply; then
      return 1
    fi
    case "$reply" in
      s|S|si|SI|y|Y|yes|YES)
        printf '%s[%s] Continuando sin subtítulos por confirmación del usuario.%s\n' \
          "${C_YELLOW:-}" "$tool" "${C_RST:-}" >&2
        return 0
        ;;
      *)
        printf '%s[%s] Descarga cancelada por el usuario antes de bajar el video.%s\n' \
          "${C_YELLOW:-}" "$tool" "${C_RST:-}" >&2
        return 1
        ;;
    esac
  else
    printf '%s[%s] Aviso (modo no interactivo): el video se descargará sin subtítulos (%s).%s\n' \
      "${C_YELLOW:-}" "$tool" "$last_err" "${C_RST:-}" >&2
    return 0
  fi
}

# Consulta formatos disponibles y presenta menú manual obligatorio <=1080p.
# Uso: yt_select_format <tool> <url> <out_format_var> <extra_args_nameref>
yt_select_format() {
  local tool="$1"
  local url="$2"
  local -n _out_fmt="$3"
  local -n _extra_ref="$4"

  printf '%s[%s] Consultando formatos disponibles (<=1080p)...%s\n' \
    "${C_CYAN:-}" "$tool" "${C_RST:-}" >&2

  local json_file
  json_file="$(mktemp)"

  if ! yt-dlp --ignore-config --no-playlist -J "${_extra_ref[@]}" "$url" >"$json_file" 2>/dev/null; then
    rm -f "$json_file"
    printf '%s[%s] Error: no se pudo consultar la lista de formatos.%s\n' \
      "${C_RED:-}" "$tool" "${C_RST:-}" >&2
    return 1
  fi

  local menu_lines
  menu_lines="$(python3 - "$json_file" << 'PYEOF'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)

formats = data.get("formats") or []
duration = data.get("duration") or 0

def fmt_size(b):
    if not b or b <= 0:
        return "~? MiB"
    gib = 1024 ** 3
    mib = 1024 ** 2
    if b >= gib:
        return f"~{b / gib:.2f} GiB"
    return f"~{b / mib:.1f} MiB"

def codec_group(vcodec):
    vc = (vcodec or "").lower()
    if vc.startswith("vp09") or vc.startswith("vp9"):
        return ("vp9", 0)
    if vc.startswith("av01"):
        return ("av01", 1)
    if vc.startswith("avc1") or vc.startswith("h264"):
        return ("h264", 2)
    return (vc or "unknown", 3)

def est_bytes(f):
    sz = f.get("filesize") or f.get("filesize_approx")
    if sz and sz > 0:
        return int(sz)
    tbr = f.get("tbr") or f.get("vbr") or 0
    if duration and tbr:
        return int(float(duration) * float(tbr) * 1000.0 / 8.0)
    return 0

def is_m3u8(f):
    proto = (f.get("protocol") or "").lower()
    return "m3u8" in proto

# Mejor audio para sumar peso estimado orientativo
audio_candidates = [
    f for f in formats
    if (f.get("vcodec") in (None, "none")) and (f.get("acodec") not in (None, "none"))
]
best_audio_bytes = 0
if audio_candidates:
    best_audio = max(audio_candidates, key=lambda a: (a.get("abr") or a.get("tbr") or 0))
    best_audio_bytes = est_bytes(best_audio)

video_formats = [
    f for f in formats
    if (f.get("vcodec") not in (None, "none"))
    and (f.get("height") is not None)
    and (int(f.get("height")) <= 1080)
]

premium_1080 = []
std_1080 = []
cand_720 = []

for f in video_formats:
    h = int(f["height"])
    note = (f.get("format_note") or "").lower()
    if h == 1080:
        if "premium" in note or (is_m3u8(f) and "premium" in (f.get("format") or "").lower()):
            premium_1080.append(f)
        else:
            std_1080.append(f)
    elif h == 720:
        cand_720.append(f)

options = []

# 1. 1080p Premium (HLS m3u8) primero si existe
if premium_1080:
    premium_1080.sort(key=lambda f: (0 if is_m3u8(f) else 1, -(f.get("tbr") or 0)))
    f = premium_1080[0]
    cname, _ = codec_group(f.get("vcodec"))
    total_b = est_bytes(f) + best_audio_bytes
    options.append((
        f["format_id"],
        f"1080p Premium ({cname}, HLS m3u8) — {fmt_size(total_b)}"
    ))

# 2. Demás variantes 1080p (vp9, av01, h264), prefiriendo https sobre m3u8 por codec
by_codec_1080 = {}
for f in std_1080:
    cname, cprio = codec_group(f.get("vcodec"))
    proto_prio = 1 if is_m3u8(f) else 0
    score = (proto_prio, -(est_bytes(f) or 0), -(f.get("tbr") or 0))
    if cname not in by_codec_1080 or score < by_codec_1080[cname][0]:
        by_codec_1080[cname] = (score, cprio, f)

for cname, (_, _, f) in sorted(by_codec_1080.items(), key=lambda kv: kv[1][1]):
    total_b = est_bytes(f) + best_audio_bytes
    proto_lbl = "HLS" if is_m3u8(f) else f.get("ext", "mp4")
    options.append((
        f["format_id"],
        f"1080p ({cname}, {proto_lbl}) — {fmt_size(total_b)}"
    ))

# 3. Mejor variante 720p disponible como opción final
if cand_720:
    cand_720.sort(key=lambda f: (
        1 if is_m3u8(f) else 0,
        codec_group(f.get("vcodec"))[1],
        -(f.get("tbr") or 0),
    ))
    f = cand_720[0]
    cname, _ = codec_group(f.get("vcodec"))
    proto_lbl = "HLS" if is_m3u8(f) else f.get("ext", "mp4")
    total_b = est_bytes(f) + best_audio_bytes
    options.append((
        f["format_id"],
        f"720p ({cname}, {proto_lbl}) — {fmt_size(total_b)}"
    ))

# Fallback si el video no tiene ni 1080p ni 720p (ej. max 480p)
if not options and video_formats:
    video_formats.sort(key=lambda f: (-int(f["height"]), codec_group(f.get("vcodec"))[1]))
    f = video_formats[0]
    cname, _ = codec_group(f.get("vcodec"))
    total_b = est_bytes(f) + best_audio_bytes
    options.append((
        f["format_id"],
        f"{f['height']}p ({cname}) — {fmt_size(total_b)}"
    ))

for fid, label in options:
    print(f"{fid}\t{label}")
PYEOF
)"

  rm -f "$json_file"

  if [[ -z "$menu_lines" ]]; then
    printf '%s[%s] Aviso: no se encontraron formatos <=1080p; usando selector seguro <=1080p.%s\n' \
      "${C_YELLOW:-}" "$tool" "${C_RST:-}" >&2
    _out_fmt="bv*[height<=1080]+ba/b[height<=1080]"
    return 0
  fi

  local ids=()
  local labels=()
  local fid lbl
  while IFS=$'\t' read -r fid lbl; do
    [[ -z "$fid" ]] && continue
    ids+=("$fid")
    labels+=("$lbl")
  done <<< "$menu_lines"

  local count=${#ids[@]}
  printf '\n%s[%s] Seleccioná la calidad de video (<=1080p):%s\n' \
    "${C_BOLD:-}" "$tool" "${C_RST:-}" >&2
  local i
  for ((i = 0; i < count; i++)); do
    printf '  %s%d)%s %s %s[id:%s]%s\n' \
      "${C_CYAN:-}" "$((i + 1))" "${C_RST:-}" "${labels[$i]}" \
      "${C_DIM:-}" "${ids[$i]}" "${C_RST:-}" >&2
  done

  local choice=""
  while true; do
    printf '%sOpción (1-%d, sin default): %s' "${C_BOLD:-}" "$count" "${C_RST:-}" >&2
    if ! read -r choice; then
      printf '\n%s[%s] Selección cancelada.%s\n' "${C_RED:-}" "$tool" "${C_RST:-}" >&2
      return 1
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
      local chosen_id="${ids[$((choice - 1))]}"
      _out_fmt="${chosen_id}+ba/b[height<=1080]"
      printf '%s[%s] Elegido: %s (%s)%s\n' \
        "${C_GREEN:-}" "$tool" "${labels[$((choice - 1))]}" "$chosen_id" "${C_RST:-}" >&2
      return 0
    fi
    printf '%sElección inválida. Ingresá un número entre 1 y %d (Enter vacío no es válido).%s\n' \
      "${C_YELLOW:-}" "$count" "${C_RST:-}" >&2
  done
}
