import { buildApp } from "./app.js";
import { loadConfig } from "./config/env.js";
import { PgDb } from "./db/pg-db.js";
import { migrate } from "./db/migrate.js";

const config = loadConfig();

// Con DATABASE_URL hay cuentas; sin ella el servidor solo empareja (útil en local).
const db = config.databaseUrl ? new PgDb(config.databaseUrl) : undefined;
const app = await buildApp({ config, db });

// Railway cierra con SIGTERM al redesplegar: terminamos limpio.
for (const signal of ["SIGTERM", "SIGINT"] as const) {
  process.on(signal, () => {
    app
      .close()
      .then(() => db?.close())
      .finally(() => process.exit(0));
  });
}

try {
  if (db) {
    const applied = await migrate(db);
    app.log.info({ applied }, applied.length > 0 ? "migraciones aplicadas" : "base de datos al día");
  } else {
    app.log.warn("sin DATABASE_URL: las cuentas están desactivadas");
  }
  await app.listen({ port: config.port, host: "0.0.0.0" });
} catch (err) {
  app.log.error(err);
  process.exit(1);
}
