-- La partida del modo Historia pasa a ser una por cuenta y luchador: empezar una historia con otro luchador
-- ya no borra la que había con el anterior. Las filas existentes siguen valiendo tal cual.
alter table story_saves drop constraint story_saves_pkey;
alter table story_saves add primary key (player_id, fighter);
