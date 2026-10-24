extends TestCase
## Locks the rigged-character contract: zombie surfaces and triangle budgets,
## clip mapping per archetype, manual animation LOD, and the hand attachment.

const PLAYER_CLIPS := {
	"idle": "Idle",
	"walk": "Walking_A",
	"run": "Running_A",
	"aim": "1H_Ranged_Aiming",
	"fire": "1H_Ranged_Shoot",
	"interact": "Interact",
	"hit": "Hit_A",
	"death": "Death_A",
}

const SHAMBLER_CLIPS := {
	"idle": "Idle",
	"walk": "Walking_D_Skeletons",
	"attack": "Unarmed_Melee_Attack_Punch_A",
	"death": "Death_C_Skeletons",
}


func _visual(kind: String, set_name := "") -> CharacterVisual:
	var visual := CharacterVisual.new()
	runner.add_child(visual)
	visual.setup(kind, set_name)
	return visual


func test_zombie_meshes_are_one_surface() -> void:
	for kind: String in ["shambler", "runner", "brute"]:
		var visual := _visual(kind, kind)
		equal(visual.surface_count(), 1, "%s has one draw surface" % kind)
		less(visual.triangle_count(), 6000, "%s fits the character triangle budget" % kind)
		equal(visual.animation_count(), 95, "%s keeps the full skeleton library" % kind)
		check(visual.has_hand(), "%s exposes the right-hand attachment" % kind)
		visual.queue_free()


func test_horde_triangle_budget() -> void:
	var visual := _visual("shambler", "shambler")
	var horde_triangles: int = visual.triangle_count() * Game.tuning.zombie_cap
	less(horde_triangles, 1_200_000, "200 skeletons stay under the horde budget")
	visual.queue_free()


func test_animation_state_mapping() -> void:
	var player := _visual("player", "player")
	for state: String in PLAYER_CLIPS:
		player.play_state(state, 0.0, 1.0, true)
		equal(player.current_clip(), PLAYER_CLIPS[state], "player %s clip" % state)
	player.queue_free()

	var shambler := _visual("shambler", "shambler")
	for state: String in SHAMBLER_CLIPS:
		shambler.play_state(state, 0.0, 1.0, true)
		equal(shambler.current_clip(), SHAMBLER_CLIPS[state], "shambler %s clip" % state)
	shambler.queue_free()


func test_runner_and_brute_attack_clips() -> void:
	var runner := _visual("runner", "runner")
	runner.play_state("attack", 0.0, 1.0, true)
	equal(runner.current_clip(), "1H_Melee_Attack_Slice_Diagonal", "runner attack clip")
	runner.play_state("lunge", 0.0, 1.0, true)
	equal(runner.current_clip(), "1H_Melee_Attack_Jump_Chop", "runner lunge clip")
	runner.queue_free()

	var brute := _visual("brute", "brute")
	brute.play_state("attack", 0.0, 1.0, true)
	equal(brute.current_clip(), "2H_Melee_Attack_Chop", "brute attack clip")
	brute.queue_free()


func test_manual_animation_lod() -> void:
	var visual := _visual("player", "player")
	visual.play_state("walk", 0.0)
	visual.tick(0.2, 0)
	greater(visual.animation_position(), 0.01, "near LOD advances every frame")
	var before_far := visual.animation_position()
	visual.tick(0.5, 2)
	almost(visual.animation_position(), before_far, 0.0001, "far LOD freezes the pose")
	visual.tick(0.1, 1)
	var before_mid := visual.animation_position()
	visual.tick(0.1, 1)
	greater(visual.animation_position(), before_mid, "mid LOD advances on its next 100 ms step")
	visual.queue_free()


func test_player_and_villager_scale_fit_their_capsules() -> void:
	var player := _visual("player", "player")
	less(player.model_height(), 2.0, "player visual fits the 1.8 m capsule")
	player.queue_free()

	var villager := _visual("villager_a", "villager")
	less(villager.model_height(), 1.9, "villager visual fits the 1.7 m capsule")
	villager.queue_free()


func test_hand_attachment_is_finite() -> void:
	var visual := _visual("player", "player")
	var hand := visual.hand_position()
	check(hand.is_finite(), "hand attachment returns a finite world position")
	greater(hand.y, 0.1, "hand attachment sits above the floor")
	visual.queue_free()
