/** Una cuenta tal como está en la base de datos. */
export interface Account {
  id: string;
  username: string;
  email: string;
  /** null en las cuentas creadas con Google (no tienen contraseña). */
  passwordHash: string | null;
  googleSub: string | null;
  points: number;
  wins: number;
  losses: number;
  /** Id del luchador elegido como retrato, o null. */
  avatar: string | null;
  /** Última vez que cambió su nombre, o null si nunca. */
  usernameChangedAt: Date | null;
  /** Cosméticos puestos: marco del retrato y título bajo el nombre (null = ninguno). */
  frame: string | null;
  title: string | null;
  createdAt: Date;
}

/** Lo que se puede mostrar de un jugador (nunca incluye email ni contraseña). */
export interface Profile {
  id: string;
  username: string;
  points: number;
  wins: number;
  losses: number;
  avatar: string | null;
  frame: string | null;
  title: string | null;
  /** true en las cuentas de Google: entran con Google y no tienen contraseña que cambiar. */
  google_account: boolean;
}

/** Una fila del ranking. El id es interno: sirve para pedir sus estadísticas y no sale por la API. */
export interface RankingEntry {
  id: string;
  username: string;
  points: number;
  wins: number;
  losses: number;
  avatar: string | null;
}

/** Sesión abierta tras registrarse o iniciar sesión. */
export interface AuthResult {
  accessToken: string;
  refreshToken: string;
  /** Segundos de vida del accessToken. */
  expiresIn: number;
  profile: Profile;
}

export function toProfile(a: Account): Profile {
  return { id: a.id, username: a.username, points: a.points, wins: a.wins, losses: a.losses, avatar: a.avatar, frame: a.frame, title: a.title, google_account: a.passwordHash === null };
}
