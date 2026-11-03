#!/usr/bin/env bash
# Duelo con ranking de punta a punta: servidor de desarrollo con base de datos embebida
# (PGlite) y DOS clientes de Godot con cuentas distintas. Comprueba que:
#   - se emparejan como duelo con ranking,
#   - las dos peleas quedan idénticas (mismos checksums),
#   - el servidor confirma los puntos a los dos (uno sube y el otro baja lo mismo),
#   - el ranking y el historial de las cuentas lo reflejan.
# Uso:  GODOT=/ruta/a/godot tests/run_ranked_e2e.sh      (antes: cd server && npm ci)
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

URL="ws://127.0.0.1:$PORT/ws"
"$GODOT" --headless --path . res://tests/OnlineClientTest.tscn -- --url="$URL" --fighter=napoleon --seed=1 --email=ana@e2e.com --name=Ana_E2E > "$OUT/a.log" 2>&1 &
A=$!
sleep 2
"$GODOT" --headless --path . res://tests/OnlineClientTest.tscn -- --url="$URL" --fighter=cleopatra --seed=2 --email=beto@e2e.com --name=Beto_E2E > "$OUT/b.log" 2>&1 &
B=$!
wait $A; RA=$?
wait $B; RB=$?

grep -h "^MATCHED\|^FIN\|^SETTLED\|^FALLO" "$OUT/a.log" | sed 's/^/A: /'
grep -h "^MATCHED\|^FIN\|^SETTLED\|^FALLO" "$OUT/b.log" | sed 's/^/B: /'

FAIL=0
fail() { echo "FAIL: $1"; FAIL=1; }
[ "$RA" = 0 ] && [ "$RB" = 0 ] || fail "un cliente terminó con error (A=$RA B=$RB)"
grep -q "^MATCHED.*ranked=true" "$OUT/a.log" || fail "A no entró a un duelo con ranking"
grep -q "^MATCHED.*ranked=true" "$OUT/b.log" || fail "B no entró a un duelo con ranking"

grep "^CHK" "$OUT/a.log" > "$OUT/a.chk"
grep "^CHK" "$OUT/b.log" > "$OUT/b.chk"
[ -s "$OUT/a.chk" ] && diff -q "$OUT/a.chk" "$OUT/b.chk" > /dev/null || fail "los checksums de A y B difieren"

DA=$(grep -o "^SETTLED.* delta=[-0-9]*" "$OUT/a.log" | grep -o "delta=[-0-9]*" | cut -d= -f2)
DB=$(grep -o "^SETTLED.* delta=[-0-9]*" "$OUT/b.log" | grep -o "delta=[-0-9]*" | cut -d= -f2)
grep -q "^SETTLED ranked=true ok=true" "$OUT/a.log" || fail "A: el servidor no confirmó el duelo"
grep -q "^SETTLED ranked=true ok=true" "$OUT/b.log" || fail "B: el servidor no confirmó el duelo"
{ [ -n "$DA" ] && [ -n "$DB" ] && [ "$DA" != 0 ] && [ $((DA + DB)) = 0 ]; } || fail "los puntos no cuadran (A=$DA, B=$DB)"

BOARD=$(curl -s "http://127.0.0.1:$PORT/leaderboard?limit=5")
echo "RANKING: $BOARD"
echo "$BOARD" | grep -q '"Ana_E2E"' && echo "$BOARD" | grep -q '"Beto_E2E"' || fail "el ranking no muestra a los dos"
TOKEN=$(curl -s -X POST "http://127.0.0.1:$PORT/auth/login" -H 'content-type: application/json' -d '{"email":"ana@e2e.com","password":"secreto1"}' | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>console.log(JSON.parse(s).access_token))")
HIST=$(curl -s "http://127.0.0.1:$PORT/me/matches" -H "authorization: Bearer $TOKEN")
echo "HISTORIAL DE ANA: $HIST"
echo "$HIST" | grep -q '"opponent":"Beto_E2E"' || fail "el historial de Ana no tiene el duelo"

[ "$FAIL" = 0 ] && echo "E2E RANKING: OK" || { echo "E2E RANKING: FALLÓ (logs en $OUT)"; exit 1; }
