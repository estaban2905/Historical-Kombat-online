-- Cuándo cambió el jugador su nombre por última vez (null = nunca). Limita los cambios para que
-- nadie se haga pasar por otro cambiándose el nombre todo el rato.
alter table players add column username_changed_at timestamptz;
