import { existsSync } from "node:fs";
import { resolve } from "node:path";
import type { FastifyInstance } from "fastify";
import fastifyStatic from "@fastify/static";

/**
 * Sirve el juego exportado a Web (carpeta public/) desde el mismo servidor:
 * una sola dirección para la página y para el WebSocket (/ws), sin CORS.
 * Si la carpeta no existe (desarrollo local) no hace nada.
 * Devuelve true si el juego quedó publicado.
 */
export async function registerStatic(app: FastifyInstance, dir: string): Promise<boolean> {
  const root = resolve(dir);
  if (!existsSync(resolve(root, "index.html"))) return false;

  await app.register(fastifyStatic, {
    root,
    // El build trae index.js.br / index.wasm.br / index.pck.br ya comprimidos (scripts/precompress.mjs).
    preCompressed: true,
    // Rutas de otros plugins (/docs, /health...) ganan siempre: son más específicas.
    wildcard: true,
    // La cabecera Cache-Control la pone setHeaders (la del plugin la pisaría).
    cacheControl: false,
    setHeaders(res, path) {
      // La página y el .js cambian en cada despliegue: que el navegador siempre pregunte.
      // Los archivos grandes (wasm/pck) se revalidan con ETag: si no cambiaron, no se vuelven a bajar.
      res.setHeader("Cache-Control", path.endsWith(".html") ? "no-cache" : "public, max-age=0, must-revalidate");
    },
  });
  return true;
}
