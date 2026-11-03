-- Duelos con ranking anulados por desincronización, una fila por cuenta y anulación. Sirven para saber quién se
-- repite en ellas (src/services/matchmaking.service.ts): las filas fuera de la ventana de 24 h se borran al anotar
-- la siguiente, así que la tabla se mantiene pequeña.
create table desync_strikes (
  id        bigserial primary key,
  player_id uuid not null references players(id) on delete cascade,
  at        timestamptz not null default now()
);
create index desync_strikes_player on desync_strikes (player_id, at desc);
create index desync_strikes_at on desync_strikes (at);
