-- Amigos: una solicitud pendiente (de quien la manda a quien la recibe) que pasa a aceptada.
-- Nunca hay dos filas para el mismo par de jugadores, vengan de donde vengan: el índice único
-- mira el par sin importar el orden, así dos solicitudes cruzadas a la vez no se duplican.
create table friendships (
  requester_id uuid not null references players(id) on delete cascade,
  addressee_id uuid not null references players(id) on delete cascade,
  status       text not null check (status in ('pending', 'accepted')),
  created_at   timestamptz not null default now(),
  primary key (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);
create unique index friendships_pair on friendships (
  least(requester_id::text, addressee_id::text),
  greatest(requester_id::text, addressee_id::text)
);
create index friendships_addressee on friendships (addressee_id);
