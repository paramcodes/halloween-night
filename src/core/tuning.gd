class_name Tuning
extends Resource
## Every tunable number lives here, serialised to res://resources/tuning.tres.
## Gameplay code reads Game.tuning; nothing hard-codes a balance value.

@export_group("Clock")
@export var day_seconds := 210.0
@export var dusk_seconds := 25.0
@export var night_seconds := 300.0
@export var dawn_seconds := 25.0
@export var total_nights := 7

@export_group("Player")
@export var walk_speed := 2.6
@export var sprint_speed := 5.2
@export var aim_speed := 1.6
@export var player_max_hp := 100.0
@export var sprint_stamina_seconds := 5.0
@export var stamina_regen_per_second := 0.35
@export var coyote_time := 0.12
@export var ground_accel := 14.0
@export var air_accel := 3.0
@export var gravity := 24.0
@export var mouse_sensitivity := 0.0025
@export var pitch_min_deg := -70.0
@export var pitch_max_deg := 45.0

@export_group("Camera")
@export var boom_length := 3.5
@export var boom_length_aim := 2.1
@export var shoulder_offset := 0.55
@export var pivot_height := 1.55
@export var position_smoothing := 0.15
@export var rotation_smoothing := 0.08
@export var fov := 65.0
@export var fov_aim := 72.0

@export_group("Feedback")
@export var fire_recoil_deg := 1.6
@export var fire_recoil_attack := 9.0
@export var fire_recoil_recover := 4.5
@export var camera_shake_max_deg := 1.4
@export var camera_shake_per_damage := 0.02
@export var camera_shake_decay := 2.2
@export var gait_variation := 0.12
@export var idle_breath_amount := 0.06
@export var idle_breath_period := 3.8

@export_group("Flamethrower")
@export var fuel_capacity := 100.0
@export var burn_rate_per_second := 6.0
@export var flame_range := 8.0
@export var flame_cone_degrees := 45.0
@export var flame_direct_dps := 18.0
@export var flame_burn_dps := 12.0
@export var flame_burn_seconds := 3.0
@export var flame_tick_hz := 10.0
@export var flame_ray_count := 12
@export var fuel_per_canister := 100.0

@export_group("Zombies")
@export var zombie_cap := 200
@export var zombie_hp := 100.0
@export var zombie_speed := 1.4
@export var zombie_lunge_speed := 4.5
@export var zombie_lunge_seconds := 2.0
@export var zombie_lunge_cooldown := 6.0
@export var zombie_lunge_range := 8.0
@export var zombie_attack_range := 1.5
@export var zombie_attack_dps := 15.0
@export var zombie_door_dps := 15.0
@export var zombie_detect_range := 60.0
@export var runner_hp := 40.0
@export var runner_speed := 6.0
@export var brute_hp := 400.0
@export var brute_speed := 1.0
@export var brute_door_multiplier := 3.0

@export_group("Horde")
@export var wave_base := 8
@export var wave_per_night := 6
@export var waves_base := 3
@export var wave_bell_bonus := 0.2
@export var runner_from_night := 4
@export var brute_from_night := 6

@export_group("Village")
@export var village_size := 120.0
@export var house_count := 9
@export var villager_count := 18
@export var spawner_count := 3
@export var door_hp := 200.0
@export var door_max_hp := 350.0
@export var boarding_bonus := 150.0
@export var boarding_seconds := 4.0
@export var starting_planks := 3
@export var bell_charges := 3
@export var flow_field_cell := 2.0
@export var flow_field_hz := 4.0

@export_group("Save")
@export var save_schema_version := 1


func night_wave_size(night: int) -> int:
	return wave_base + wave_per_night * night


func waves_for_night(night: int) -> int:
	return waves_base + night
