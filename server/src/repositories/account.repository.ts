import type { Queryable } from "../db/db.js";
import { isUniqueViolation } from "../db/db.js";
import { DuplicateAccountError } from "../errors.js";
import type { Account, RankingEntry } from "../models/account.js";

interface AccountRow {
  id: string;
  username: string;
  email: string;
  password_hash: string | null;
  google_sub: string | null;
  points: number;
  wins: number;
  losses: number;
  avatar: string | null;
  username_changed_at: Date | string | null;
  frame: string | null;
  title: string | null;
  created_at: Date | string;
}

const COLUMNS = "id, username, email, password_hash, google_sub, points, wins, losses, avatar, username_changed_at, frame, title, created_at";

function toAccount(r: AccountRow): Account {
  return {
    id: r.id,
    username: r.username,
    email: r.email,
    passwordHash: r.password_hash,
    googleSub: r.google_sub,
    points: r.points,
    wins: r.wins,
    losses: r.losses,
    avatar: r.avatar,
    usernameChangedAt: r.username_changed_at ? new Date(r.username_changed_at) : null,
    frame: r.frame,
    title: r.title,
    createdAt: new Date(r.created_at),
  };
}

/** Todo el SQL de la tabla players. */
export class AccountRepository {
  constructor(private readonly db: Queryable) {}

  /** Crea la cuenta; lanza DuplicateAccountError si el nombre o el email ya existen. */
  async create(input: {
    username: string;
    email: string;
    passwordHash?: string;
    googleSub?: string;
  }): Promise<Account> {
    try {
      const res = await this.db.query<AccountRow>(
        `insert into players (username, email, password_hash, google_sub) values ($1, $2, $3, $4) returning ${COLUMNS}`,
        [input.username, input.email, input.passwordHash ?? null, input.googleSub ?? null],
      );
      return toAccount(res.rows[0]!);
    } catch (err) {
      if (isUniqueViolation(err)) {
        const hint = `${err.constraint ?? ""} ${(err as { message?: string }).message ?? ""}`;
        throw new DuplicateAccountError(hint.includes("email") ? "email" : "username");
      }
      throw err;
    }
  }

  async findByEmail(email: string): Promise<Account | null> {
    const res = await this.db.query<AccountRow>(`select ${COLUMNS} from players where lower(email) = lower($1)`, [email]);
    return res.rows[0] ? toAccount(res.rows[0]) : null;
  }

  async findByGoogleSub(sub: string): Promise<Account | null> {
    const res = await this.db.query<AccountRow>(`select ${COLUMNS} from players where google_sub = $1`, [sub]);
    return res.rows[0] ? toAccount(res.rows[0]) : null;
  }

  /**
   * Google demostró que el email es suyo: la cuenta que ya existía con ese email pasa a ser
   * de Google. Se borra la contraseña y se cierran todas sus sesiones, porque el email nunca
   * se verificó y quien la registró pudo no ser su dueño. Una sola sentencia: todo o nada.
   * false si la cuenta ya estaba enlazada a otra cuenta de Google.
   */
  async claimForGoogle(id: string, sub: string): Promise<boolean> {
    const res = await this.db.query<{ id: string }>(
      `with claimed as (
         update players set google_sub = $2, password_hash = null
          where id = $1 and google_sub is null
          returning id
       ), closed as (
         delete from sessions where player_id in (select id from claimed)
       )
       select id from claimed`,
      [id, sub],
    );
    return res.rows.length > 0;
  }

  async findById(id: string): Promise<Account | null> {
    const res = await this.db.query<AccountRow>(`select ${COLUMNS} from players where id = $1`, [id]);
    return res.rows[0] ? toAccount(res.rows[0]) : null;
  }

  /**
   * Bloquea las dos cuentas hasta el final de la transacción (FOR UPDATE), siempre en el
   * mismo orden para que dos duelos a la vez nunca se queden esperándose entre sí.
   */
  async lockPair(idA: string, idB: string): Promise<Map<string, Account>> {
    const res = await this.db.query<AccountRow>(
      `select ${COLUMNS} from players where id in ($1, $2) order by id for update`,
      [idA, idB],
    );
    return new Map(res.rows.map((r) => [r.id, toAccount(r)]));
  }

  /** Aplica el resultado de un duelo: puntos nuevos (y el máximo de la temporada) y una victoria o derrota más. */
  async applyResult(id: string, points: number, outcome: "win" | "loss" | "draw"): Promise<void> {
    await this.db.query(
      `update players set points = $2, season_peak = greatest(season_peak, $2), wins = wins + $3, losses = losses + $4
        where id = $1`,
      [id, points, outcome === "win" ? 1 : 0, outcome === "loss" ? 1 : 0],
    );
  }

  /**
   * Cambia el nombre si ya pasaron `cooldownDays` desde el último cambio. false = todavía en espera.
   * Lanza DuplicateAccountError si otro jugador ya tiene ese nombre.
   */
  async rename(id: string, username: string, cooldownDays: number): Promise<boolean> {
    try {
      const res = await this.db.query<{ id: string }>(
        `update players set username = $2, username_changed_at = now()
          where id = $1 and (username_changed_at is null or username_changed_at <= now() - $3::int * interval '1 day')
          returning id`,
        [id, username, cooldownDays],
      );
      return res.rows.length > 0;
    } catch (err) {
      if (isUniqueViolation(err)) throw new DuplicateAccountError("username");
      throw err;
    }
  }

  async setPasswordHash(id: string, passwordHash: string): Promise<void> {
    await this.db.query("update players set password_hash = $2 where id = $1", [id, passwordHash]);
  }

  /** Busca por nombre sin distinguir mayúsculas. */
  async findByUsername(username: string): Promise<Account | null> {
    const res = await this.db.query<AccountRow>(`select ${COLUMNS} from players where lower(username) = lower($1)`, [username]);
    return res.rows[0] ? toAccount(res.rows[0]) : null;
  }

  /** Puesto en el ranking (1 = el mejor), con el mismo orden que ranking(). */
  async rankOf(a: Account): Promise<number> {
    const res = await this.db.query<{ rank: number }>(
      `select (count(*) + 1)::int as rank from players
        where points > $1
           or (points = $1 and wins > $2)
           or (points = $1 and wins = $2 and created_at < $3)`,
      [a.points, a.wins, a.createdAt.toISOString()],
    );
    return res.rows[0]!.rank;
  }

  /** Pone (o quita, con null) el marco y/o el título. Lo que no se pasa se deja como está. */
  async setCosmetics(id: string, change: { frame?: string | null; title?: string | null }): Promise<void> {
    if (change.frame !== undefined) await this.db.query("update players set frame = $2 where id = $1", [id, change.frame]);
    if (change.title !== undefined) await this.db.query("update players set title = $2 where id = $1", [id, change.title]);
  }

  /** Cambia (o quita, con null) el avatar de la cuenta. */
  async setAvatar(id: string, avatar: string | null): Promise<void> {
    await this.db.query("update players set avatar = $2 where id = $1", [id, avatar]);
  }

  /** Los mejores jugadores: más puntos primero, y a igualdad más victorias. */
  async ranking(limit: number, onlyIds?: string[]): Promise<RankingEntry[]> {
    const res = await this.db.query<RankingEntry>(
      `select id, username, points, wins, losses, avatar from players
        where $2::uuid[] is null or id = any($2::uuid[])
        order by points desc, wins desc, created_at asc limit $1`,
      [limit, onlyIds ?? null],
    );
    return res.rows;
  }
}
