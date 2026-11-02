import { OAuth2Client } from "google-auth-library";

/** Lo que el servidor necesita saber de un jugador que entra con Google. */
export interface GoogleIdentity {
  /** Identificador estable de la cuenta de Google. */
  sub: string;
  email: string;
  emailVerified: boolean;
}

/** Comprueba un ID token de Google. Lanza si no es válido. Se inyecta para poder probarlo sin red. */
export type GoogleVerifier = (idToken: string) => Promise<GoogleIdentity>;

/** Verificador real: firma, caducidad y que el token sea para ESTE cliente (audience). */
export function createGoogleVerifier(clientId: string): GoogleVerifier {
  const client = new OAuth2Client(clientId);
  return async (idToken) => {
    const ticket = await client.verifyIdToken({ idToken, audience: clientId });
    const p = ticket.getPayload();
    if (!p?.sub || !p.email) throw new Error("token de Google sin sub o email");
    return { sub: p.sub, email: p.email, emailVerified: p.email_verified === true };
  };
}
