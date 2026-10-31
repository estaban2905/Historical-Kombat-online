-- History Combat · esquema de base de datos (Fase 2: cuentas).
-- Pegar entero en Supabase > SQL Editor > Run.

-- Un perfil por cuenta. Se crea solo al registrarse (trigger de abajo).
create table if not exists public.players (
  id          uuid primary key references auth.users(id) on delete cascade,
  username    text not null unique check (username ~ '^[A-Za-z0-9_]{3,16}$'),
  points      int  not null default 1000,
  wins        int  not null default 0,
  losses      int  not null default 0,
  created_at  timestamptz not null default now()
);

alter table public.players enable row level security;

-- Cualquier jugador con sesión puede VER perfiles (ranking, rivales).
drop policy if exists "players_select" on public.players;
create policy "players_select" on public.players
  for select to authenticated using (true);

-- A propósito NO hay políticas de insert/update/delete: el cliente no puede
-- tocar sus puntos. Solo el servidor (trigger y funciones security definer)
-- escribe, así nadie puede mandarse "gané" para subir puntos.

-- Al registrarse una cuenta se crea su perfil con el nombre elegido.
-- Si el nombre es inválido o está repetido, el registro entero falla.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.players (id, username)
  values (new.id, new.raw_user_meta_data->>'username');
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
