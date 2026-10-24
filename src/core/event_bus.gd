extends Node
## Global signal bus. Signals only: no state, no logic, no lookups.
##
## Autoload order matters: EventBus is first so every other autoload can emit
## during its own _ready().

signal phase_changed(phase: int, night: int)
signal night_started(night: int)
signal night_ended(night: int, survived: bool)
signal dawn_tally(summary: Dictionary)
signal run_over(victory: bool, summary: Dictionary)

signal fuel_changed(current: float, maximum: float)
signal fuel_empty
signal fuel_refilled(amount: float)

signal zombie_spawned(alive_count: int)
signal zombie_died(world_position: Vector3, archetype: int)
signal wave_spawned(count: int, alive_count: int)
signal bell_rung(charges_left: int)

signal villager_died(display_name: String)
signal villager_stuck(display_name: String)
signal villagers_changed(alive: int, total: int)

signal door_damaged(house_id: int, hp: float, max_hp: float)
signal door_breached(house_id: int)
signal door_boarded(house_id: int, hp: float)
signal house_occupied(house_id: int, occupants: int)

signal player_damaged(hp: float, max_hp: float)
signal player_healed(hp: float, max_hp: float)
signal player_died

signal toast(text: String)
signal dusk_choice_offered(options: Array)
signal dusk_choice_made(option_id: String)
signal debug_toggled(enabled: bool)
