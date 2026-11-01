export const healthSchema = {
  tags: ["system"],
  summary: "Estado del servidor",
  description: "Lo usa Railway para saber si el servidor está vivo. Incluye jugadores en cola y salas activas.",
  response: {
    200: {
      type: "object",
      required: ["ok", "queued", "rooms"],
      properties: {
        ok: { type: "boolean", examples: [true] },
        queued: { type: "integer", description: "Jugadores esperando rival", examples: [1] },
        rooms: { type: "integer", description: "Partidas en curso", examples: [3] },
      },
    },
  },
} as const;
