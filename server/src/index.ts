import { buildApp } from "./app.js";
import { loadConfig } from "./config/env.js";

const config = loadConfig();
const app = await buildApp({ config });

// Railway cierra con SIGTERM al redesplegar: terminamos limpio.
for (const signal of ["SIGTERM", "SIGINT"] as const) {
  process.on(signal, () => {
    app.close().finally(() => process.exit(0));
  });
}

try {
  await app.listen({ port: config.port, host: "0.0.0.0" });
} catch (err) {
  app.log.error(err);
  process.exit(1);
}
