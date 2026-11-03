// Servidor de desarrollo con cuentas y SIN Postgres: la base de datos es PGlite (Postgres
// embebido) y se guarda en la carpeta .dev-data, así las cuentas sobreviven a los reinicios.
// Uso: npm run dev:local      (DEV_DATA_DIR=memory para una base que se borra al cerrar)
// DEV_CLOCK_OFFSET_DAYS=31 adelanta el reloj de las temporadas (solo aquí, en desarrollo): al arrancar se
// cierra la temporada del mes "pasado" como lo haría el día 1 (ver tests/populate_dev.sh).
import { PGlite } from "@electric-sql/pglite";
import { buildApp } from "./app.js";
import { loadConfig } from "./config/env.js";
import { migrate } from "./db/migrate.js";
import { PgliteDb } from "./db/pglite-db.js";

const config = loadConfig();
const dir = process.env["DEV_DATA_DIR"] ?? ".dev-data";
const db = new PgliteDb(await PGlite.create(dir === "memory" ? undefined : dir));
await migrate(db);

const offsetMs = Number(process.env["DEV_CLOCK_OFFSET_DAYS"] ?? 0) * 24 * 60 * 60 * 1000;
const app = await buildApp({ config, db, now: offsetMs ? () => new Date(Date.now() + offsetMs) : undefined });
app.log.info(dir === "memory" ? "base de datos en memoria" : `base de datos en ${dir}`);

for (const signal of ["SIGTERM", "SIGINT"] as const) {
  process.on(signal, () => {
    app.close().then(() => db.close()).finally(() => process.exit(0));
  });
}
await app.listen({ port: config.port, host: "0.0.0.0" });
