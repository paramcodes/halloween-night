extends TestCase
## Locks the Phase 5 feel layer: recoil and shake budgets, idle breathing, gait
## variation, panic run, and a door attack that does not read as a player attack.

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
const ZOMBIE_SCENE := preload("res://scenes/actors/zombie.tscn")
const VILLAGER_SCENE := preload("res://scenes/actors/villager.tscn")

const STEP := 1.0 / 60.0


func _visual(kind: String, set_name := "") -> CharacterVisual:
	var visual := CharacterVisual.new()
	runner.add_child(visual)
	visual.setup(kind, set_name)
	return visual


func test_recoil_builds_caps_and_recovers() -> void:
	var tuning := Game.tuning
	var recoil := 0.0
	for _i in range(60):
		recoil = Feedback.recoil_step(recoil, true, STEP, tuning)
	almost(recoil, tuning.fire_recoil_deg, 0.001, "one second of fire reaches the recoil cap")
	for _i in range(60):
		recoil = Feedback.recoil_step(recoil, false, STEP, tuning)
	less(recoil, tuning.fire_recoil_deg * 0.5, "recoil falls away after release")
	for _i in range(600):
		recoil = Feedback.recoil_step(recoil, false, STEP, tuning)
	almost(recoil, 0.0, 0.0001, "recoil never goes below zero")


func test_damage_shake_is_budgeted() -> void:
	var tuning := Game.tuning
	almost(Feedback.shake_amplitude(0.0, tuning), 0.0, 0.0001, "no damage, no shake")
	almost(Feedback.shake_amplitude(10.0, tuning), 0.2, 0.001, "shake scales with damage")
	almost(
		Feedback.shake_amplitude(10_000.0, tuning),
		tuning.camera_shake_max_deg,
		0.0001,
		"a fatal hit cannot exceed the shake cap"
	)
	var shake := tuning.camera_shake_max_deg
	for _i in range(60):
		shake = Feedback.shake_step(shake, STEP, tuning)
	less(shake, tuning.camera_shake_max_deg, "shake decays over one second")
	almost(Feedback.shake_rotation(0.0, 4321).length(), 0.0, 0.0001, "zero amplitude is silent")
	for ticks: int in [0, 37, 500, 12_345]:
		var rotation := Feedback.shake_rotation(1.0, ticks)
		less(absf(rad_to_deg(rotation.x)), 1.001, "pitch stays inside the shake budget")
		less(absf(rad_to_deg(rotation.y)), 0.601, "yaw stays inside the shake budget")


func test_breathing_and_gait_stay_in_bounds() -> void:
	var tuning := Game.tuning
	var lowest := 1.0
	var highest := 1.0
	for ticks in range(0, 4000, 50):
		var speed := Feedback.breath_speed(ticks, 0.0, tuning)
		lowest = minf(lowest, speed)
		highest = maxf(highest, speed)
	greater(lowest, 1.0 - tuning.idle_breath_amount - 0.001, "breath never dips past its budget")
	less(highest, 1.0 + tuning.idle_breath_amount + 0.001, "breath never rises past its budget")
	check(highest - lowest > 0.02, "breathing actually moves")
	almost(Feedback.gait_scale(0.0, 0.12), 0.88, 0.0001, "gait low roll")
	almost(Feedback.gait_scale(1.0, 0.12), 1.12, 0.0001, "gait high roll")
	almost(Feedback.gait_scale(0.5, 0.12), 1.0, 0.0001, "gait mid roll is neutral")
	almost(Feedback.gait_scale(0.0, 9.0), 0.5, 0.0001, "gait scale is clamped low")
	almost(Feedback.gait_scale(1.0, 9.0), 1.5, 0.0001, "gait scale is clamped high")


func test_phase_offset_desyncs_identical_walkers() -> void:
	var first := _visual("shambler", "shambler")
	var second := _visual("shambler", "shambler")
	first.set_gait(1.0, 0.0)
	second.set_gait(1.0, 0.4)
	first.play_state("walk", 0.0, 1.0, true)
	second.play_state("walk", 0.0, 1.0, true)
	greater(
		absf(first.animation_position() - second.animation_position()),
		0.05,
		"two walkers start out of step"
	)
	var offset := first.animation_position() - second.animation_position()
	first.tick(0.1, 0)
	second.tick(0.1, 0)
	almost(
		first.animation_position() - second.animation_position(),
		offset,
		0.002,
		"desync is a fixed offset, not drift"
	)
	first.queue_free()
	second.queue_free()


func test_gait_scale_changes_playback() -> void:
	var visual := _visual("player", "player")
	visual.set_gait(1.2, 0.0)
	visual.play_state("walk", 0.0, 1.0, true)
	almost(visual.playback_speed(), 1.2, 0.0001, "gait multiplies walk playback")
	visual.tick(0.25, 0)
	greater(visual.animation_position(), 0.0, "gait-scaled walk still advances")
	visual.play_state("walk", 0.0, 0.8, false)
	almost(visual.playback_speed(), 0.96, 0.0001, "state speed and gait compose")
	visual.queue_free()


func test_door_attack_has_its_own_clip() -> void:
	var shambler := _visual("shambler", "shambler")
	shambler.play_state("door", 0.0, 1.0, true)
	equal(shambler.current_clip(), "2H_Melee_Attack_Chop", "shambler door attack clip")
	check(
		shambler.clip_for("door") != shambler.clip_for("attack"),
		"a door attack does not reuse the player attack"
	)
	shambler.queue_free()

	var runner_visual := _visual("runner", "runner")
	runner_visual.play_state("door", 0.0, 1.0, true)
	equal(runner_visual.current_clip(), "1H_Melee_Attack_Chop", "runner door attack clip")
	runner_visual.queue_free()

	var brute := _visual("brute", "brute")
	brute.play_state("door", 0.0, 1.0, true)
	equal(brute.current_clip(), "2H_Melee_Attack_Spinning", "brute door attack clip")
	brute.queue_free()


func test_zombie_gait_varies_per_spawn() -> void:
	var director := NightDirector.new()
	runner.add_child(director)
	director.rng.seed = 1234
	var first_pass := _spawn_gait_sample(director)
	director.rng.seed = 1234
	var second_pass := _spawn_gait_sample(director)
	equal(first_pass, second_pass, "gait rolls are reproducible from the director seed")
	var distinct := {}
	for scale: float in first_pass:
		distinct[snappedf(scale, 0.001)] = true
		check(scale >= 0.8799 and scale <= 1.1201, "shambler gait stays inside the spread")
	check(distinct.size() >= 5, "a group of eight spawns does not march in lockstep")
	director.queue_free()


func _spawn_gait_sample(director: NightDirector) -> Array[float]:
	var scales: Array[float] = []
	for _i in range(8):
		var zombie: Zombie = ZOMBIE_SCENE.instantiate()
		runner.add_child(zombie)
		zombie.setup(null, null, director, Zombie.Archetype.SHAMBLER, Zombie.Objective.PLAYER, null)
		var body := zombie.get_node("Body") as CharacterVisual
		scales.append(body.gait_scale)
		zombie.queue_free()
	return scales


func test_villager_panic_run() -> void:
	var villager: Villager = VILLAGER_SCENE.instantiate()
	villager.set_physics_process(false)
	runner.add_child(villager)
	villager.setup("Panic", null, {"kind": "wood", "position": Vector3.ZERO}, null, null, 2)
	GameClock.running = false
	GameClock.phase = GameClock.Phase.DUSK
	villager.state = Villager.State.TO_HOME
	villager.velocity = Vector3(3.4, 0.0, 0.0)
	villager.animate_gait(STEP)
	check(villager.panicking, "sprinting home at dusk is panic")
	var body := villager.get_node("Body") as CharacterVisual
	equal(body.current_clip(), "Running_A", "panic reads as a run")
	greater(body.playback_speed(), 1.0, "panic run plays faster than a walk")
	GameClock.phase = GameClock.Phase.DAY
	villager.state = Villager.State.WORK
	villager.velocity = Vector3.ZERO
	villager.animate_gait(STEP)
	check(not villager.panicking, "work by day is not panic")
	villager.queue_free()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame


func test_player_camera_feedback_end_to_end() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	runner.add_child(player)
	for _i in range(60):
		player.apply_feedback(STEP, true)
	almost(
		player.camera_recoil_degrees(),
		Game.tuning.fire_recoil_deg,
		0.001,
		"holding fire builds the full recoil"
	)
	for _i in range(120):
		player.apply_feedback(STEP, false)
	almost(player.camera_recoil_degrees(), 0.0, 0.0001, "releasing fire settles the camera")
	var rest := player.camera_shake_degrees()
	player.take_damage(20.0)
	greater(player.camera_shake_degrees(), rest, "damage adds shake")
	player.take_damage(5_000.0)
	less(
		player.camera_shake_degrees(),
		Game.tuning.camera_shake_max_deg + 0.0001,
		"a killing blow is still capped"
	)
	player.queue_free()
