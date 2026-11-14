class_name HeroState
extends RefCounted

## Характеристики одного героя в рамках игрового прохождения.
## Не относятся к исходной карте и пока не сохраняются на диск.

const START_HEALTH: int = 20
const START_ATTACK: int = 3
const START_DEFENSE: int = 1

var max_health: int = START_HEALTH
var health: int = START_HEALTH
var attack: int = START_ATTACK
var defense: int = START_DEFENSE
var gold: int = 0
