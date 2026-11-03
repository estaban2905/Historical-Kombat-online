/** Lo que hace falta saber de un jugador para evaluar sus logros. */
export interface AchievementInput {
  wins: number;
  losses: number;
  /** Sus duelos con ranking, del más antiguo al más reciente. */
  results: { result: "win" | "loss" | "draw"; myRounds: number; opponentRounds: number }[];
  /** Los finales del modo Historia que ha visto ("repair", "rewrite", "free"). */
  endings: string[];
  /** Cuántos luchadores ha ganado en el modo Historia (sin contar los iniciales). */
  fighterUnlocks: number;
}

export interface Achievement {
  key: string;
  /** Cuánto lleva (nunca pasa de la meta: con la meta cumplida vale `goal`). */
  progress: number;
  goal: number;
  done: boolean;
}

/** La racha de victorias más larga que ha tenido. Un empate o una derrota la cortan. */
export function bestStreak(results: AchievementInput["results"]): number {
  let best = 0;
  let run = 0;
  for (const r of results) {
    run = r.result === "win" ? run + 1 : 0;
    best = Math.max(best, run);
  }
  return best;
}

/** Los luchadores del plantel que no son iniciales: 50 menos los 12 con los que se empieza. */
export const LOCKED_FIGHTERS = 38;

interface Definition {
  key: string;
  goal: number;
  value: (i: AchievementInput) => number;
}

/** Los textos y el orden en que se muestran son cosa del juego; aquí solo la regla de cada logro. */
const DEFINITIONS: Definition[] = [
  { key: "first_win", goal: 1, value: (i) => i.wins },
  { key: "wins_10", goal: 10, value: (i) => i.wins },
  { key: "wins_50", goal: 50, value: (i) => i.wins },
  { key: "played_25", goal: 25, value: (i) => i.wins + i.losses },
  { key: "streak_5", goal: 5, value: (i) => bestStreak(i.results) },
  // Una victoria perfecta: ganar sin perder ninguna ronda.
  { key: "flawless", goal: 1, value: (i) => i.results.filter((r) => r.result === "win" && r.opponentRounds === 0).length },
  { key: "story_done", goal: 1, value: (i) => (i.endings.length > 0 ? 1 : 0) },
  { key: "hidden_ending", goal: 1, value: (i) => (i.endings.includes("free") ? 1 : 0) },
  { key: "all_endings", goal: 3, value: (i) => new Set(i.endings).size },
  { key: "collector", goal: 20, value: (i) => i.fighterUnlocks },
  { key: "full_roster", goal: LOCKED_FIGHTERS, value: (i) => i.fighterUnlocks },
];

export function evaluateAchievements(input: AchievementInput): Achievement[] {
  return DEFINITIONS.map((d) => {
    const value = d.value(input);
    return { key: d.key, progress: Math.min(value, d.goal), goal: d.goal, done: value >= d.goal };
  });
}
