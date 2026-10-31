## Datos de conexión con Supabase (Project Settings > API en supabase.com).
## La "anon key" es pública por diseño: la seguridad real la dan las reglas
## RLS de la base de datos (ver supabase/schema.sql). NUNCA pegues aquí la
## clave "service_role": con ella cualquiera podría editar la base de datos.
## Alternativa sin tocar el código: crear user://backend.cfg (ver backend.gd).
extends RefCounted

const SUPABASE_URL := ""
const SUPABASE_ANON_KEY := ""
