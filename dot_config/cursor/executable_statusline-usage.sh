#!/usr/bin/env bash
# Refreshes the Cursor usage cache read by statusline.sh.
# Cursor Pro has no 5h cap, so the 5h figure is spend in a rolling window, not a % of a limit.
# All $ figures are chargedCents (what Cursor bills), which is what GetAggregatedUsageEvents sums.
set -uo pipefail

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/cursor-statusline"
cache="$cache_dir/usage.json"
mkdir -p "$cache_dir"

exec 9>"$cache_dir/lock"
flock -n 9 || exit 0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
now=$(($(date +%s) * 1000))

fail() {
  [[ -s $cache ]] || echo '{}' >"$cache"
  jq --arg e "$1" --argjson now "$now" '.error = $e | .error_at = $now' "$cache" >"$tmp/err.json" &&
    mv "$tmp/err.json" "$cache"
  exit 1
}

token=$(jq -r '.accessToken // empty' "$HOME/.config/cursor/auth.json" 2>/dev/null)
[[ -n $token ]] || fail "sin token"

api=https://api2.cursor.sh/aiserver.v1.DashboardService
h5=$((now - 5 * 3600 * 1000))
h24=$((now - 24 * 3600 * 1000))

call() {
  local code
  code=$(curl -s -m 10 -X POST "$api/$1" -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' -d "$2" -o "$tmp/$1.json" -w '%{http_code}')
  echo "$code" >"$tmp/$1.code"
}

call GetCurrentPeriodUsage '{}' &
call GetAggregatedUsageEvents "{\"startDate\":\"$h5\",\"endDate\":\"$now\"}" &
call GetFilteredUsageEvents "{\"startDate\":\"$h24\",\"endDate\":\"$now\",\"page\":1,\"pageSize\":1000}" &
call GetSandUsageStatus '{}' &
wait

for ep in GetCurrentPeriodUsage GetAggregatedUsageEvents GetFilteredUsageEvents; do
  code=$(cat "$tmp/$ep.code" 2>/dev/null)
  case $code in
    200) ;;
    401 | 403) fail "token expirado" ;;
    000 | "") fail "sin red" ;;
    *) fail "API $code" ;;
  esac
done

sand_ok=0
[[ $(cat "$tmp/GetSandUsageStatus.code" 2>/dev/null) == 200 ]] && sand_ok=1

jq -n \
  --slurpfile period "$tmp/GetCurrentPeriodUsage.json" \
  --slurpfile agg "$tmp/GetAggregatedUsageEvents.json" \
  --slurpfile ev "$tmp/GetFilteredUsageEvents.json" \
  --slurpfile sand "$tmp/GetSandUsageStatus.json" \
  --argjson sand_ok "$sand_ok" \
  --argjson now "$now" --argjson h5 "$h5" '
  def iso_ms: if . == null or . == "" then null else (sub("\\.[0-9]+(?=Z$)"; "") | fromdateiso8601) * 1000 end;
  ($ev[0].usageEventsDisplay // []) as $events
  | ($events | map(.timestamp |= tonumber)) as $e
  | (if $sand_ok == 1 then $sand[0] else null end) as $g
  | {
      updated: $now,
      h5_cents: ($agg[0].totalCostCents // 0),
      h5_requests: ($e | map(select(.timestamp >= $h5)) | length),
      h1_cents: ($e | map(select(.timestamp >= $now - 3600000) | .chargedCents // 0) | add // 0),
      sessions: ($e | group_by(.conversationId)
        | map({key: .[0].conversationId, value: (map(.chargedCents // 0) | add)}) | from_entries),
      month_pct: ($period[0].planUsage.totalPercentUsed // 0),
      auto_pct: ($period[0].planUsage.autoPercentUsed // null),
      api_pct: ($period[0].planUsage.apiPercentUsed // null),
      month_spend_cents: ($period[0].planUsage.totalSpend // 0),
      month_included_cents: ($period[0].planUsage.limit // 0),
      cycle_start: ($period[0].billingCycleStart // "0" | tonumber),
      cycle_end: ($period[0].billingCycleEnd // "0" | tonumber),
      grok_pct: (if $g then ($g.usagePercent // 0 | floor) else null end),
      grok_reset_ms: (if $g then ($g.nextResetTimestampUtc | iso_ms) else null end),
      grok_available: (if $g then ($g.hasAvailableUsage // true) else null end)
    }' >"$tmp/out.json" || fail "respuesta inválida"

mv "$tmp/out.json" "$cache"
