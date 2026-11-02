-- Inicio de sesión con Google: una cuenta puede no tener contraseña y se enlaza por el
-- identificador "sub" de Google (estable; el email puede cambiar).
alter table players alter column password_hash drop not null;
alter table players add column google_sub text;
create unique index players_google_sub on players (google_sub) where google_sub is not null;
