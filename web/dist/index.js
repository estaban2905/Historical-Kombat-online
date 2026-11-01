import { buildApp, loadConfig } from "./app.js";
const port = Number(process.env["PORT"] ?? 8788);
const app = await buildApp(loadConfig());
// Railway cierra con SIGTERM al redesplegar: terminamos limpio.
for (const signal of ["SIGTERM", "SIGINT"]) {
    process.on(signal, () => {
        app.close().finally(() => process.exit(0));
    });
}
try {
    await app.listen({ port, host: "0.0.0.0" });
}
catch (err) {
    app.log.error(err);
    process.exit(1);
}
