#!/usr/bin/env bash
# M3 spike (Phase 2, C3): real multi-process multiplayer test on this machine.
# One headless Godot server process + N headless Godot client processes over
# real WebSockets (127.0.0.1). During the match:
#   client 0 double-sends commands, client 1 sends invalid / hostile frames,
#   client 2 drops its connection for DOWN_S seconds (longer than the seat
#   hold, so the server bot takes over and the player then reclaims the seat),
#   client 3 fakes its local state and idles sometimes (server timers act);
#   the server is killed with SIGKILL at KILL_AT_S and restarted from its
#   journal; every client reconnects on its own.
# Then tools/net/verify_e2e.gd checks convergence, determinism and invariants.
# Usage: GODOT=/path/to/godot scripts/run_net_e2e.sh [OUT_DIR]
#   env: PORT (18765) SEED (404) PLAYERS (4) TIME_SCALE (10) KILL_AT_S (12, 0 = no kill) DROP_AT_S (20)
#        DOWN_S (6) HOLD_MS (20000) POLICY (bot|timers) TIMEOUT_S (420)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
OUT="${1:-$(mktemp -d)}"
PORT="${PORT:-18765}"; SEED="${SEED:-404}"; PLAYERS="${PLAYERS:-4}"; TIME_SCALE="${TIME_SCALE:-10}"
KILL_AT_S="${KILL_AT_S:-12}"; DROP_AT_S="${DROP_AT_S:-20}"; DOWN_S="${DOWN_S:-6}"; HOLD_MS="${HOLD_MS:-20000}"; POLICY="${POLICY:-bot}"
TIMEOUT_S="${TIMEOUT_S:-420}"
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"  # Godot resolves relative paths against client/
rm -f "$OUT"/*.json "$OUT"/*.jsonl "$OUT"/*.log
G=("$GODOT" --headless --path "$ROOT/client")

start_server() {
  local before
  before=$(grep -c "LISTENING" "$OUT/server.log" 2>/dev/null || true)
  "${G[@]}" --script res://tools/net/server_main.gd -- --port="$PORT" --dir="$OUT" --players="$PLAYERS" \
    --seed="$SEED" --time_scale="$TIME_SCALE" --hold_ms="$HOLD_MS" --policy="$POLICY" "$@" >>"$OUT/server.log" 2>&1 &
  SERVER_PID=$!
  for _ in $(seq 1 100); do
    [ "$(grep -c "LISTENING" "$OUT/server.log" 2>/dev/null || true)" -gt "${before:-0}" ] && return 0
    sleep 0.1
  done
  echo "server did not start"; cat "$OUT/server.log"; return 1
}

start_server || exit 1
CLIENT_OPTS=("--dup_every=5" "--invalid_every=6" "--drop_at_s=$DROP_AT_S --down_s=$DOWN_S" "--fake_state_at=10 --idle_pct=8")
PIDS=()
for i in $(seq 0 $((PLAYERS - 1))); do
  # shellcheck disable=SC2086
  "${G[@]}" --script res://tools/net/client_main.gd -- --url="ws://127.0.0.1:$PORT" --token="tok-$SEED-$i" \
    --dir="$OUT" ${CLIENT_OPTS[$i]} >"$OUT/client_$i.log" 2>&1 &
  PIDS+=($!)
done
RESTARTED=0
START=$SECONDS
while :; do
  alive=0
  for p in "${PIDS[@]}"; do kill -0 "$p" 2>/dev/null && alive=1; done
  [ $alive = 0 ] && break
  if [ "$KILL_AT_S" != 0 ] && [ $RESTARTED = 0 ] && [ $((SECONDS - START)) -ge "$KILL_AT_S" ]; then
    echo "killing server (SIGKILL) at $((SECONDS - START)) s"
    kill -9 "$SERVER_PID"; wait "$SERVER_PID" 2>/dev/null
    sleep 2
    start_server --resume || exit 1
    RESTARTED=1
  fi
  if [ $((SECONDS - START)) -ge "$TIMEOUT_S" ]; then
    echo "TIMEOUT after $TIMEOUT_S s"; kill "${PIDS[@]}" "$SERVER_PID" 2>/dev/null; break
  fi
  # Server footprint sample: RSS (KiB) and cumulative CPU time.
  ps -o rss=,time= -p "$SERVER_PID" >>"$OUT/server_resources.log" 2>/dev/null
  sleep 0.5
done
wait "$SERVER_PID" 2>/dev/null
echo "wall time: $((SECONDS - START)) s, out: $OUT"
EXTRA=()
[ $RESTARTED = 1 ] && EXTRA+=(--expect_restart=1)
# A drop longer than the seat hold must trigger the server bot, then a reclaim.
[ "$POLICY" = bot ] && [ "$PLAYERS" -ge 3 ] && [ $((DOWN_S * 1000 * ${TIME_SCALE%.*})) -gt "$HOLD_MS" ] && EXTRA+=(--expect_takeover=1)
"${G[@]}" --script res://tools/net/verify_e2e.gd -- --dir="$OUT" --players="$PLAYERS" --seed="$SEED" "${EXTRA[@]}"
