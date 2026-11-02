-- Partida guardada del modo Historia: una por cuenta, para seguir desde cualquier dispositivo.
-- Se reescribe en cada combate ganado; se borra al terminar la historia o al quedarse sin revanchas.
create table story_saves (
  player_id       uuid primary key references players(id) on delete cascade,
  fighter         text     not null,
  stage           smallint not null check (stage >= 0),
  continues       smallint not null check (continues >= 0),
  continues_used  int      not null check (continues_used >= 0),
  difficulty      smallint not null check (difficulty >= 0),
  -- Hora (segundos Unix) en que el juego hizo el guardado: el cliente se queda con el más reciente.
  saved_at        bigint   not null,
  updated_at      timestamptz not null default now()
);
