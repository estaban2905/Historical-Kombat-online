-- Cuentas, sesiones y partidas de History Combat.
-- Las migraciones se aplican solas al arrancar el servidor (src/db/migrate.ts),
-- una vez cada una y en orden. NO se editan las ya publicadas: se agrega una nueva.

create table players (
  id            uuid primary key default gen_random_uuid(),
  username      text not null,
  email         text not null,
  password_hash text not null,
  points        int  not null default 1000,
  wins          int  not null default 0,
  losses        int  not null default 0,
  created_at    timestamptz not null default now(),
  constraint players_username_format check (username ~ '^[A-Za-z0-9_]{3,16}$')
);

-- Únicos sin distinguir mayúsculas: "Max_29" y "max_29" son el mismo jugador.
create unique index players_username_lower on players (lower(username));
create unique index players_email_lower on players (lower(email));
create index players_ranking on players (points desc, wins desc);

-- Una fila por dispositivo con sesión. Los tokens NO se guardan, solo su hash:
-- si se filtrara la base de datos no servirían para entrar.
create table sessions (
  id              uuid primary key default gen_random_uuid(),
  player_id       uuid not null references players(id) on delete cascade,
  access_hash     text not null unique,
  refresh_hash    text not null unique,
  access_expires  timestamptz not null,
  refresh_expires timestamptz not null,
  created_at      timestamptz not null default now()
);
create index sessions_player on sessions (player_id);

-- Historial de duelos online entre cuentas. winner: 1 = P1, 2 = P2, 0 = empate.
create table matches (
  id         uuid primary key default gen_random_uuid(),
  p1_id      uuid not null references players(id),
  p2_id      uuid not null references players(id),
  p1_fighter text not null,
  p2_fighter text not null,
  winner     smallint not null check (winner in (0, 1, 2)),
  p1_rounds  smallint not null,
  p2_rounds  smallint not null,
  p1_delta   int not null,
  p2_delta   int not null,
  reason     text not null default 'normal' check (reason in ('normal', 'forfeit')),
  played_at  timestamptz not null default now()
);
create index matches_p1 on matches (p1_id, played_at desc);
create index matches_p2 on matches (p2_id, played_at desc);
