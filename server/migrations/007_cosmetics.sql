-- Cosméticos que el jugador lleva puestos: un marco para su retrato y un título bajo su nombre (null = ninguno).
-- Solo se pueden poner los que tenga en player_unlocks (kind 'cosmetic'): lo comprueba la API, no la base de datos.
alter table players add column frame text check (frame ~ '^[a-z0-9_]{1,40}$');
alter table players add column title text check (title ~ '^[a-z0-9_]{1,40}$');
