#!/usr/bin/env bash
# Cuentas de punta a punta: servidor de desarrollo con base de datos embebida (PGlite) y
# el cliente de Godot (Backend) contra él. No necesita Postgres ni Docker.
# Uso:  GODOT=/ruta/a/godot tests/run_account_e2e.sh      (antes: cd server && npm ci)
set -u
GODOT="${GODOT:-godot}"
PORT="${PORT:-$((19000 + RANDOM % 900))}"   # al azar: un servidor viejo no puede contestar por este
OUT="$(mktemp -d)"
cd "$(dirname "$0")/.."

(cd server && PORT="$PORT" LOG=false DEV_DATA_DIR=memory exec node --import tsx src/dev.ts > "$OUT/server.log" 2>&1) &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
for _ in $(seq 1 100); do
  curl -sf "http://127.0.0.1:$PORT/health" > /dev/null && break
  sleep 0.3
done
kill -0 $SERVER 2>/dev/null || { echo "FAIL: el servidor de prueba no arrancó (¿puerto $PORT ocupado?)"; exit 1; }

"$GODOT" --headless --path . res://tests/BackendTest.tscn -- --url="ws://127.0.0.1:$PORT/ws" > "$OUT/godot.log" 2>&1
CODE=$?
grep -E "^\s+\[FAIL\]|RESULTADO" "$OUT/godot.log"
[ "$CODE" = 0 ] && echo "E2E CUENTAS: OK" || { echo "E2E CUENTAS: FALLÓ (logs en $OUT)"; exit 1; }
