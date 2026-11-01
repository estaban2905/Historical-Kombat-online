import type { Queryable } from "../db/db.js";
import { isUniqueViolation } from "../db/db.js";
import { DuplicateAccountError } from "../errors.js";
import type { Account, RankingEntry } from "../models/account.js";

interface AccountRow {
  id: string;
  username: string;
  email: string;
  password_hash: string;
  points: number;
  wins: number;
  losses: number;
  created_at: Date | string;
}

const COLUMNS = "id, username, email, password_hash, points, wins, losses, created_at";

function toAccount(r: AccountRow): Account {
  return {
    id: r.id,
    username: r.username,
    email: r.email,
    passwordHash: r.password_hash,
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
  async create(input: { username: string; email: string; passwordHash: string }): Promise<Account> {
    try {
      const res = await this.db.query<AccountRow>(
        `insert into players (username, email, password_hash) values ($1, $2, $3) returning ${COLUMNS}`,
        [input.username, input.email, input.passwordHash],
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

  async findById(id: string): Promise<Account | null> {
    const res = await this.db.query<AccountRow>(`select ${COLUMNS} from players where id = $1`, [id]);
    return res.rows[0] ? toAccount(res.rows[0]) : null;
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
