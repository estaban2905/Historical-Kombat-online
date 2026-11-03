import type { Queryable } from "../db/db.js";
import { isUniqueViolation } from "../db/db.js";

/** Cómo es la relación con otro jugador, vista desde mi lado. */
export type FriendStatus = "friend" | "incoming" | "outgoing";

export interface FriendEntry {
  username: string;
  avatar: string | null;
  points: number;
  status: FriendStatus;
}

/** Qué pasó al pedir amistad. */
export type RequestResult = "requested" | "accepted" | "already_friends" | "already_requested";

/** Máximo de amigos más solicitudes enviadas pendientes: frena el envío masivo de solicitudes. */
export const MAX_FRIENDS = 100;

interface Row {
  requester_id: string;
  addressee_id: string;
  status: "pending" | "accepted";
}

interface ListRow {
  username: string;
  avatar: string | null;
  points: number;
  status: "pending" | "accepted";
  incoming: boolean;
}

/** Todo el SQL de la tabla friendships. */
export class FriendRepository {
  constructor(private readonly db: Queryable) {}

  /** La fila entre dos jugadores, mande quien mande. */
  private async between(a: string, b: string): Promise<Row | null> {
    const res = await this.db.query<Row>(
      `select requester_id, addressee_id, status from friendships
        where (requester_id = $1 and addressee_id = $2) or (requester_id = $2 and addressee_id = $1)`,
      [a, b],
    );
    return res.rows[0] ?? null;
  }

  /**
   * `me` pide amistad a `other`. Si `other` ya le había pedido a `me`, se aceptan las dos a la vez.
   * Repetir una petición no hace nada. Devuelve null si `me` ya tiene demasiados amigos y solicitudes.
   */
  async request(me: string, other: string): Promise<RequestResult | null> {
    const existing = await this.between(me, other);
    if (existing) return this.resolve(existing, me);
    if ((await this.count(me)) >= MAX_FRIENDS) return null;
    try {
      await this.db.query("insert into friendships (requester_id, addressee_id, status) values ($1, $2, 'pending')", [me, other]);
      return "requested";
    } catch (err) {
      // Los dos se pidieron a la vez: la otra fila ganó la carrera y ahora hay que resolver con ella.
      if (isUniqueViolation(err)) return this.resolve((await this.between(me, other))!, me);
      throw err;
    }
  }

  private async resolve(row: Row, me: string): Promise<RequestResult> {
    if (row.status === "accepted") return "already_friends";
    if (row.requester_id === me) return "already_requested";
    await this.db.query(
      "update friendships set status = 'accepted' where requester_id = $1 and addressee_id = $2",
      [row.requester_id, row.addressee_id],
    );
    return "accepted";
  }

  /** Quita la relación: deja de ser amigo, cancela mi solicitud o rechaza la que me mandaron. No falla si no había nada. */
  async remove(me: string, other: string): Promise<void> {
    await this.db.query(
      `delete from friendships
        where (requester_id = $1 and addressee_id = $2) or (requester_id = $2 and addressee_id = $1)`,
      [me, other],
    );
  }

  /** Amigos y solicitudes (recibidas y enviadas) de un jugador. */
  async list(me: string): Promise<FriendEntry[]> {
    const res = await this.db.query<ListRow>(
      `select p.username, p.avatar, p.points, f.status, (f.addressee_id = $1) as incoming
         from friendships f
         join players p on p.id = case when f.requester_id = $1 then f.addressee_id else f.requester_id end
        where f.requester_id = $1 or f.addressee_id = $1
        order by lower(p.username)`,
      [me],
    );
    return res.rows.map((r) => ({
      username: r.username,
      avatar: r.avatar,
      points: r.points,
      status: r.status === "accepted" ? "friend" : r.incoming ? "incoming" : "outgoing",
    }));
  }

  /** Los ids de mis amigos (solo los aceptados). */
  async friendIds(me: string): Promise<string[]> {
    const res = await this.db.query<{ id: string }>(
      `select case when requester_id = $1 then addressee_id else requester_id end as id
         from friendships where status = 'accepted' and (requester_id = $1 or addressee_id = $1)`,
      [me],
    );
    return res.rows.map((r) => r.id);
  }

  /** ¿Son amigos (solicitud aceptada)? */
  async areFriends(a: string, b: string): Promise<boolean> {
    return (await this.between(a, b))?.status === "accepted";
  }

  /** Amigos más solicitudes que he enviado. */
  private async count(me: string): Promise<number> {
    const res = await this.db.query<{ n: number }>(
      `select count(*)::int as n from friendships
        where (requester_id = $1) or (addressee_id = $1 and status = 'accepted')`,
      [me],
    );
    return res.rows[0]!.n;
  }
}
