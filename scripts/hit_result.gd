## Lo que pasó al recibir un golpe (lo devuelve Fighter.receive_hit y lo reparten las señales del
## combate). Es una clase y no un Dictionary para que un nombre mal escrito falle al cargar el script
## y no en mitad de una pelea.
class_name HitResult
extends RefCounted

## El golpe fue bloqueado (o absorbido por un escudo).
var blocked: bool = false
## Daño final aplicado, ya con bloqueo, counter-hit y escalado de combo.
var damage: float = 0.0
## El golpe dejó la vida a cero.
var ko: bool = false
## La guardia llegó a cero y se rompió.
var guard_break: bool = false
## El golpe pilló al rival en el startup de su ataque.
var counter: bool = false
## Bloqueo perfecto: se pulsó el bloqueo justo antes del golpe.
var perfect: bool = false
## Un escudo (Allende) absorbió el golpe: no hubo daño.
var absorbed: bool = false
## Nivel (AttackData.HitLevel) del golpe que entró porque la guardia no lo cubría (p. ej. un golpe bajo
## contra un bloqueo de pie); -1 si no fue el caso. Sirve para avisar al jugador de por qué le entró.
var guard_miss: int = -1
## Nombre del combo completado con este golpe ("" si ninguno); lo rellena el CombatManager.
var combo_name: String = ""
