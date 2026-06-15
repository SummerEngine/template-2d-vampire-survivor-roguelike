extends Node

## Tracks XP and level. Lives in the "level_system" group so XP gems can grant
## XP via call_group without a hard reference.

signal xp_changed(current: int, needed: int, level: int)
signal leveled_up(level: int)

var level: int = 1
var xp: int = 0
var xp_to_next: int = 5

func _ready() -> void:
	add_to_group("level_system")
	xp_changed.emit(xp, xp_to_next, level)

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = _needed_for(level)
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_to_next, level)

func _needed_for(lv: int) -> int:
	return 5 + (lv - 1) * 3
