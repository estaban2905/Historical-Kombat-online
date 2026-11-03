#!/usr/bin/env bash
# Llena un servidor de desarrollo con datos de verdad JUGANDO, sin tocar la base de datos a mano: cuentas,
# modo Historia, amigos, un reto amistoso, duelos con ranking entre 6 clientes de Godot y el cierre de una
# temporada. Así se ven todas las pantallas con datos y, si algo del flujo falla, falla aquí.
#
#   Cuentas (contraseña secreto1): Max_Sim (max@sim.com, la principal), Ana_Sim, Beto_Sim, Carla_Sim,
#   Dani_Sim y Eva_Sim (nombre@sim.com).
#
# Uso:  GODOT=/ruta/a/godot tests/populate_dev.sh <carpeta-de-datos> [puerto]
#   La base de datos (PGlite) queda en <carpeta-de-datos>; después se puede abrir con
#   cd server && DEV_DATA_DIR=<carpeta-de-datos> DEV_CLOCK_OFFSET_DAYS=31 npm run dev:local
#   (el reloj adelantado es el de después del cierre de temporada; sin él se abriría otra vez la del mes real).
set -u
GODOT="${GODOT:-godot}"
DATA="${1:?falta la carpeta de datos}"
PORT="${2:-8787}"
URL="ws://127.0.0.1:$PORT/ws"
LOGS="$(mktemp -d)"
cd "$(dirname "$0")/.."

SERVER=""
start_server() {   # $1 = días que se adelanta el reloj de las temporadas
  (cd server && PORT="$PORT" LOG=false DEV_DATA_DIR="$DATA" DEV_CLOCK_OFFSET_DAYS="$1" exec node --import tsx src/dev.ts \
    >> "$LOGS/server.log" 2>&1) &
  SERVER=$!
  for _ in $(seq 1 100); do curl -sf "http://127.0.0.1:$PORT/health" > /dev/null && return 0; sleep 0.3; done
  echo "FALLO: el servidor no arrancó (¿puerto $PORT ocupado?)"; exit 1
}
stop_server() { [ -n "$SERVER" ] && kill "$SERVER" 2>/dev/null; wait "$SERVER" 2>/dev/null; SERVER=""; }
trap stop_server EXIT

FAIL=0
PIDS=()
# Espera a los clientes lanzados con "&" en esta fase (no al servidor, que también va en segundo plano).
wait_all() { for p in "${PIDS[@]}"; do wait "$p"; done; PIDS=(); }
# Un cliente de duelos: $1 = nombre, $2 = semilla, resto = opciones de tests/online_client_test.gd.
client() {
  local name="$1" seed="$2"; shift 2
  local email; email="$(echo "$name" | cut -d_ -f1 | tr '[:upper:]' '[:lower:]')@sim.com"
  timeout 400 "$GODOT" --headless --path . res://tests/OnlineClientTest.tscn -- --url="$URL" --email="$email" --name="$name" \
    --seed="$seed" "$@" > "$LOGS/$name-$seed.log" 2>&1
  local code=$?
  grep -h "^CUENTA\|^AMISTAD\|^RETO\|^MATCHED\|^SETTLED\|^TITULO\|^FALLO" "$LOGS/$name-$seed.log" | sed "s/^/  $name: /"
  [ "$code" = 0 ] || { echo "  FALLO: $name terminó con error ($code)"; FAIL=1; }
}
story() {   # $1 = nombre, resto = opciones de tests/story_sim.gd
  local name="$1"; shift
  local email; email="$(echo "$name" | cut -d_ -f1 | tr '[:upper:]' '[:lower:]')@sim.com"
  timeout 600 "$GODOT" --headless --path . res://tests/StorySim.tscn -- --url="$URL" --email="$email" --name="$name" "$@" \
    > "$LOGS/story-$name.log" 2>&1
  local code=$?
  grep -h "^CUENTA\|^COMBATE\|^REVANCHA\|^PARTIDA\|^DESBLOQUEOS\|^FALLO" "$LOGS/story-$name.log" | sed "s/^/  $name: /"
  [ "$code" = 0 ] || { echo "  FALLO: la historia de $name terminó con error ($code)"; FAIL=1; }
}

start_server 0

echo "# 1. Modo Historia (cuentas nuevas, desbloqueos y partida guardada)"
story Max_Sim --fighter=napoleon --wins=7 --lose-at=3 & PIDS+=($!)
story Ana_Sim --fighter=cleopatra --wins=3 & PIDS+=($!)
wait_all

echo "# 2. Amigos: Max con Ana, Beto y Carla; Dani le pide a Max (pendiente); Max le pide a Eva (pendiente)"
client Max_Sim 11 --duels=0 --friends=Ana_Sim,Beto_Sim,Carla_Sim,Eva_Sim
for n in Ana_Sim Beto_Sim Carla_Sim; do client "$n" 12 --duels=0 --friends=Max_Sim & PIDS+=($!); done
client Dani_Sim 13 --duels=0 --friends=Max_Sim & PIDS+=($!)
client Eva_Sim 14 --duels=0 & PIDS+=($!)
wait_all

echo "# 3. Reto amistoso: Max reta a Ana (sala privada, no mueve puntos)"
client Ana_Sim 21 --challenge-from=Max_Sim --fighter=cleopatra & PIDS+=($!)
sleep 3
client Max_Sim 22 --challenge-to=Ana_Sim --fighter=napoleon & PIDS+=($!)
wait_all

echo "# 4. Temporada pasada: duelos con ranking entre los 6 (más agresivo = gana más)"
client Max_Sim 31 --duels=6 --aggr=0.32 --fighters=napoleon,nikola_tesla,napoleon,cleopatra & PIDS+=($!)
client Ana_Sim 32 --duels=6 --aggr=0.26 --fighters=cleopatra,juana_de_arco & PIDS+=($!)
client Beto_Sim 33 --duels=6 --aggr=0.16 --fighters=gengis_kan,rasputin & PIDS+=($!)
client Carla_Sim 34 --duels=6 --aggr=0.12 --fighters=lautaro,albert_einstein & PIDS+=($!)
client Dani_Sim 35 --duels=6 --aggr=0.08 --fighters=papa_francisco & PIDS+=($!)
client Eva_Sim 36 --duels=6 --aggr=0.2 --fighters=alejandro_magno,leonardo_da_vinci & PIDS+=($!)
wait_all

echo "# 5. Cambio de mes: el servidor arranca con el reloj adelantado y cierra la temporada"
stop_server
start_server 31
curl -s "http://127.0.0.1:$PORT/season"; echo

echo "# 6. Temporada nueva: unos duelos más"
client Max_Sim 41 --duels=3 --aggr=0.3 --fighters=napoleon,nikola_tesla & PIDS+=($!)
client Ana_Sim 42 --duels=3 --aggr=0.2 --fighters=cleopatra & PIDS+=($!)
client Beto_Sim 43 --duels=3 --aggr=0.18 --fighters=gengis_kan & PIDS+=($!)
client Eva_Sim 44 --duels=3 --aggr=0.14 --fighters=alejandro_magno & PIDS+=($!)
wait_all

echo "# Ranking final"
curl -s "http://127.0.0.1:$PORT/leaderboard?limit=10" | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{for(const p of JSON.parse(s))console.log('  '+p.username.padEnd(10),p.points,p.wins+'V',p.losses+'D','racha',p.streak,'fav',p.favorite_fighter)})"

[ "$FAIL" = 0 ] && echo "DATOS: OK (logs en $LOGS)" || { echo "DATOS: HUBO FALLOS (logs en $LOGS)"; exit 1; }
