-- Cosas que el jugador ha desbloqueado: finales del modo Historia vistos, luchadores ganados, cosméticos...
-- Una fila por cosa y nunca se borran (desbloquear es para siempre). `kind` dice de qué tipo es y `key`
-- cuál: ("ending", "repair"), ("fighter", "napoleon"). El servidor no conoce el plantel ni los finales:
-- solo exige una forma válida, y el juego ignora lo que no reconoce.
create table player_unlocks (
  player_id   uuid not null references players(id) on delete cascade,
  kind        text not null check (kind in ('ending', 'fighter', 'cosmetic')),
  key         text not null check (key ~ '^[a-z0-9_]{1,40}$'),
  unlocked_at timestamptz not null default now(),
  primary key (player_id, kind, key)
);
