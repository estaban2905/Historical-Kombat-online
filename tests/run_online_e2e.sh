#!/usr/bin/env bash
# Prueba de extremo a extremo del duelo online: servidor real + dos clientes Godot.
# Uso:  GODOT=/ruta/a/godot tests/run_online_e2e.sh
# Requiere haber hecho `npm ci && npm run build` en server/.
set -u
GODOT="${GODOT:-godot}"
PORT="${PORT:-18080}"
OUT="$(mktemp -d)"
cd "$(dirname "$0")/.."

PORT="$PORT" LOG=false node server/dist/index.js > "$OUT/server.log" 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
for _ in $(seq 1 50); do
  curl -sf "http://127.0.0.1:$PORT/health" > /dev/null && break
  sleep 0.2
done

URL="ws://127.0.0.1:$PORT/ws"
"$GODOT" --headless --path . res://tests/OnlineClientTest.tscn -- --url="$URL" --fighter=napoleon --seed=1 > "$OUT/a.log" 2>&1 &
A=$!
sleep 1
"$GODOT" --headless --path . res://tests/OnlineClientTest.tscn -- --url="$URL" --fighter=cleopatra --seed=2 > "$OUT/b.log" 2>&1 &
B=$!
wait $A; RA=$?
wait $B; RB=$?

grep -h "^MATCHED\|^FIN\|^FALLO" "$OUT/a.log" | sed 's/^/A: /'
grep -h "^MATCHED\|^FIN\|^FALLO" "$OUT/b.log" | sed 's/^/B: /'

grep "^CHK" "$OUT/a.log" > "$OUT/a.chk"
grep "^CHK" "$OUT/b.log" > "$OUT/b.chk"
FAIL=0
[ "$RA" = 0 ] && [ "$RB" = 0 ] || { echo "FAIL: un cliente terminó con error (A=$RA B=$RB)"; FAIL=1; }
[ -s "$OUT/a.chk" ] || { echo "FAIL: A no registró ningún checksum"; FAIL=1; }
if ! diff -q "$OUT/a.chk" "$OUT/b.chk" > /dev/null; then
  echo "FAIL: los checksums de A y B difieren"; diff "$OUT/a.chk" "$OUT/b.chk" | head; FAIL=1
else
  echo "OK: $(wc -l < "$OUT/a.chk") checksums idénticos en los dos PCs"
fi
[ "$FAIL" = 0 ] && echo "E2E ONLINE: OK" || { echo "E2E ONLINE: FALLÓ (logs en $OUT)"; exit 1; }
