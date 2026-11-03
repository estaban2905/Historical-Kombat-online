import { test } from "node:test";
import assert from "node:assert/strict";
import { bestStreak, evaluateAchievements, type AchievementInput } from "../../src/services/achievements.service.js";

const win = (opp = 1) => ({ result: "win" as const, myRounds: 2, opponentRounds: opp });
const loss = () => ({ result: "loss" as const, myRounds: 0, opponentRounds: 2 });
const draw = () => ({ result: "draw" as const, myRounds: 1, opponentRounds: 1 });

const base: AchievementInput = { wins: 0, losses: 0, results: [], endings: [], fighterUnlocks: 0 };
const get = (input: AchievementInput, key: string) => evaluateAchievements(input).find((a) => a.key === key)!;

test("sin nada hecho ningún logro está cumplido y todos parten de 0", () => {
  const all = evaluateAchievements(base);
  assert.ok(all.length >= 10);
  assert.ok(all.every((a) => !a.done && a.progress === 0 && a.goal > 0));
  assert.equal(new Set(all.map((a) => a.key)).size, all.length, "las claves no se repiten");
});

test("la mejor racha: un empate o una derrota cortan, y cuenta la más larga aunque no sea la actual", () => {
  assert.equal(bestStreak([]), 0);
  assert.equal(bestStreak([win(), win(), loss(), win()]), 2);
  assert.equal(bestStreak([win(), win(), draw(), win(), win(), win()]), 3);
  assert.equal(bestStreak([loss(), loss()]), 0);
});

test("victorias: se cumplen en su meta y el progreso no pasa de ella", () => {
  assert.equal(get({ ...base, wins: 0 }, "first_win").done, false);
  assert.equal(get({ ...base, wins: 1 }, "first_win").done, true);
  const ten = get({ ...base, wins: 9 }, "wins_10");
  assert.deepEqual([ten.progress, ten.goal, ten.done], [9, 10, false]);
  const many = get({ ...base, wins: 80 }, "wins_50");
  assert.deepEqual([many.progress, many.goal, many.done], [50, 50, true]);
});

test("duelos jugados cuentan victorias y derrotas", () => {
  assert.equal(get({ ...base, wins: 10, losses: 14 }, "played_25").done, false);
  assert.equal(get({ ...base, wins: 10, losses: 15 }, "played_25").done, true);
});

test("racha de 5 y victoria perfecta salen de los duelos", () => {
  const five = { ...base, results: [win(), win(), win(), win(), win()] };
  assert.equal(get(five, "streak_5").done, true);
  assert.equal(get({ ...base, results: [win(), win(), win(), win(), loss(), win()] }, "streak_5").done, false);
  assert.equal(get({ ...base, results: [win(1), loss()] }, "flawless").done, false);
  assert.equal(get({ ...base, results: [win(0)] }, "flawless").done, true, "ganar 2-0 es una victoria perfecta");
  assert.equal(get({ ...base, results: [{ result: "loss", myRounds: 0, opponentRounds: 0 }] }, "flawless").done, false);
});

test("los finales: cualquiera termina la historia, el oculto es aparte y los tres suman", () => {
  assert.equal(get(base, "story_done").done, false);
  const one = { ...base, endings: ["repair"] };
  assert.equal(get(one, "story_done").done, true);
  assert.equal(get(one, "hidden_ending").done, false);
  assert.equal(get({ ...base, endings: ["free"] }, "hidden_ending").done, true);
  const two = get({ ...base, endings: ["repair", "rewrite"] }, "all_endings");
  assert.deepEqual([two.progress, two.done], [2, false]);
  assert.equal(get({ ...base, endings: ["repair", "rewrite", "free"] }, "all_endings").done, true);
  assert.equal(get({ ...base, endings: ["repair", "repair"] }, "all_endings").progress, 1, "un final repetido no suma");
});

test("luchadores ganados: coleccionista a los 20 y plantel completo a los 38", () => {
  assert.equal(get({ ...base, fighterUnlocks: 19 }, "collector").done, false);
  assert.equal(get({ ...base, fighterUnlocks: 20 }, "collector").done, true);
  assert.equal(get({ ...base, fighterUnlocks: 37 }, "full_roster").done, false);
  assert.equal(get({ ...base, fighterUnlocks: 38 }, "full_roster").done, true);
});
