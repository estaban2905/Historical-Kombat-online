-- Borrado de cuenta y aceptación de términos.
-- Al borrar una cuenta, sus duelos se conservan para el historial del rival, pero sin el jugador borrado:
-- la referencia pasa a null y el historial lo muestra como "JUGADOR ELIMINADO".
alter table matches alter column p1_id drop not null;
alter table matches alter column p2_id drop not null;
alter table matches drop constraint matches_p1_id_fkey;
alter table matches drop constraint matches_p2_id_fkey;
alter table matches add constraint matches_p1_id_fkey foreign key (p1_id) references players(id) on delete set null;
alter table matches add constraint matches_p2_id_fkey foreign key (p2_id) references players(id) on delete set null;

-- Cuándo aceptó los términos y la privacidad (null = cuentas anteriores a este aviso).
alter table players add column terms_accepted_at timestamptz;
