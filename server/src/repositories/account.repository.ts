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
  created_at: Date | string;
}

const COLUMNS = "id, username, email, password_hash, google_sub, points, wins, losses, created_at";

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

  /** Aplica el resultado de un duelo: puntos nuevos y una victoria o derrota más. */
  async applyResult(id: string, points: number, outcome: "win" | "loss" | "draw"): Promise<void> {
    await this.db.query(
      "update players set points = $2, wins = wins + $3, losses = losses + $4 where id = $1",
      [id, points, outcome === "win" ? 1 : 0, outcome === "loss" ? 1 : 0],
    );
  }

  /** Los mejores jugadores: más puntos primero, y a igualdad más victorias. */
  async ranking(limit: number): Promise<RankingEntry[]> {
    const res = await this.db.query<RankingEntry>(
      "select username, points, wins, losses from players order by points desc, wins desc, created_at asc limit $1",
      [limit],
    );
    return res.rows;
  }
}
