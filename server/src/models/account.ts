/** Una cuenta tal como está en la base de datos. */
export interface Account {
  id: string;
  username: string;
  email: string;
  passwordHash: string;
  points: number;
  wins: number;
  losses: number;
  createdAt: Date;
}

/** Lo que se puede mostrar de un jugador (nunca incluye email ni contraseña). */
export interface Profile {
  id: string;
  username: string;
  points: number;
  wins: number;
  losses: number;
}

export interface RankingEntry {
  username: string;
  points: number;
  wins: number;
  losses: number;
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
  return { id: a.id, username: a.username, points: a.points, wins: a.wins, losses: a.losses };
}
