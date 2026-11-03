-- Avatar del jugador: el id de un luchador (null = sin elegir). El servidor no conoce el plantel:
-- solo exige un id con forma válida y el juego ignora los que no reconoce.
alter table players add column avatar text check (avatar ~ '^[a-z0-9_]{1,40}$');
