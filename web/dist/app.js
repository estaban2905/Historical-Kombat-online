import Fastify from "fastify";
import { registerStatic } from "./static.js";
export function loadConfig(env = process.env) {
    return {
        staticDir: env["STATIC_DIR"] ?? "public",
        serverUrl: env["SERVER_URL"] ?? "",
        logger: env["LOG"] !== "false",
    };
}
/** Arma la aplicación web. No abre ningún puerto. */
export async function buildApp(options = {}) {
    const config = { ...loadConfig(), ...options };
    const app = Fastify({ logger: config.logger });
    // Railway usa esta ruta para saber si el servicio está vivo.
    app.get("/health", async () => ({ ok: true }));
    // El juego lee aquí a qué servidor conectarse. Sale de una variable de entorno,
    // así el mismo build sirve en develop y en producción sin volver a exportarlo.
    app.get("/config.js", async (_req, reply) => {
        return reply
            .header("Content-Type", "text/javascript; charset=utf-8")
            .header("Cache-Control", "no-store")
            .send(`window.HC_SERVER_URL = ${JSON.stringify(config.serverUrl)};\n`);
    });
    if (await registerStatic(app, config.staticDir)) {
        app.log.info("sirviendo el juego web desde %s", config.staticDir);
    }
    else {
        app.log.warn("no hay juego exportado en %s (falta index.html)", config.staticDir);
    }
    return app;
}
