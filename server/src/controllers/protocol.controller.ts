import { clientMessages, serverMessages } from "../schemas/protocol.schema.js";

export function getProtocol() {
  return { endpoint: "/ws", client: clientMessages, server: serverMessages };
}
