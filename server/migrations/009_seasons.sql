-- Temporadas mensuales del ranking. Cada mes (UTC) es una temporada con id 'AAAA-MM'. Al empezar el mes
-- siguiente se cierra: se guarda el puesto y la liga de cada uno que jugó, se dan las recompensas y los
-- puntos se acercan a 1000 a la mitad (src/services/season.service.ts).

-- La temporada abierta es la única fila con closed_at null.
create table seasons (
  id         text primary key check (id ~ '^[0-9]{4}-[0-9]{2}$'),
  started_at timestamptz not null default now(),
  closed_at  timestamptz
);

-- Cómo acabó cada jugador que jugó algún duelo con ranking en esa temporada.
create table season_results (
  season      text not null references seasons(id),
  player_id   uuid not null references players(id) on delete cascade,
  rank        int  not null,
  points      int  not null,
  peak_points int  not null,
  league      text not null check (league in ('bronze', 'silver', 'gold', 'diamond')),
  wins        int  not null,
  losses      int  not null,
  primary key (season, player_id)
);
create index season_results_player on season_results (player_id, season desc);

-- Los puntos más altos de la temporada en curso: la liga máxima alcanzada da el marco al cerrarla.
alter table players add column season_peak int not null default 1000;
update players set season_peak = greatest(points, 1000);
