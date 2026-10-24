extends TestCase
## Scene-level behaviour: raiders break doors, the horde closes on the player,
## and villagers actually get home at dusk without wedging on geometry.

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
const ZOMBIE_SCENE := preload("res://scenes/actors/zombie.tscn")
const VILLAGER_SCENE := preload("res://scenes/actors/villager.tscn")

var world: Village
var player: Player
var director: NightDirector


func _build_world() -> void:
	Game.headless = true
	world = Village.new()
	world.name = "TestVillage"
	runner.add_child(world)
	world.build(Game.tuning)
	player = PLAYER_SCENE.instantiate()
	player.god_mode = true
	player.position = Vector3(0, 0.3, 8)
	runner.add_child(player)
	director = NightDirector.new()
	director.name = "TestDirector"
	runner.add_child(director)
	director.setup(world, player)
	await runner.get_tree().physics_frame
	await runner.get_tree().physics_frame


func _teardown() -> void:
	GameClock.running = false
	GameClock.phase = GameClock.Phase.DUSK
	if director != null:
		for villager: Villager in director.villagers:
			if is_instance_valid(villager):
				villager.queue_free()
		director.clear_all()
		director.queue_free()
	if world != null:
		world.queue_free()
	if player != null:
		player.queue_free()
	world = null
	player = null
	director = null
	await runner.get_tree().process_frame


func _spawn_zombie(kind: int, objective: int, house: House, position: Vector3) -> Zombie:
	var zombie: Zombie = ZOMBIE_SCENE.instantiate()
	zombie.position = position
	director.add_child(zombie)
	zombie.setup(world, player, director, kind, objective, house)
	director.zombies.append(zombie)
	return zombie


func test_village_layout_and_flow() -> void:
	await _build_world()
	equal(world.houses.size(), 9, "nine houses built")
	equal(world.doors.size(), 9, "each house has a door")
	equal(world.spawn_points.size(), 3, "three edge spawners")
	check(world.job_spots.size() >= 12, "villagers have job posts")
	check(world.flow.build(player.global_position), "flow field builds for the player")
	check(world.flow.open_cell_ratio() > 0.4, "most of the village is walkable")
	await _teardown()


func test_raider_damages_door() -> void:
	await _build_world()
	var house: House = world.houses[0]
	var door := house.door
	check(door != null, "house 0 has a door")
	var outward := door.global_position - house.interior_center
	outward.y = 0.0
	var spawn := door.global_position + outward.normalized() * 3.6
	spawn.y = 0.3
	var zombie := _spawn_zombie(Zombie.Archetype.SHAMBLER, Zombie.Objective.HOUSE, house, spawn)
	var start := door.hp
	await wait_physics(600)
	less(
		door.hp,
		start - 20.0,
		(
			"door took damage (hp %.1f, zombie at %.1f m)"
			% [door.hp, zombie.global_position.distance_to(door.global_position)]
		)
	)
	await _teardown()


func test_zombie_closes_on_player() -> void:
	await _build_world()
	var zombie := _spawn_zombie(
		Zombie.Archetype.SHAMBLER, Zombie.Objective.PLAYER, null, Vector3(0, 0.3, 20)
	)
	await wait_physics(720)
	var distance := zombie.global_position.distance_to(player.global_position)
	less(distance, 3.0, "zombie closed distance to %.2f m" % distance)
	await _teardown()


func test_staged_zombie_holds_its_post() -> void:
	await _build_world()
	var post := Vector3(6.0, 0.3, -8.0)
	var zombie := _spawn_zombie(
		Zombie.Archetype.SHAMBLER, Zombie.Objective.PLAYER, null, Vector3(0, 0.3, 22)
	)
	zombie.hold_at(post)
	await wait_physics(180)
	less(zombie.global_position.distance_to(post), 0.05, "a held zombie stays on its mark")
	greater(
		zombie.global_position.distance_to(player.global_position),
		8.0,
		"a held zombie does not close on the player"
	)
	zombie.apply_burn(3.0)
	await wait_physics(4)
	check(zombie.is_burning(), "a held body still burns")
	await _teardown()


func test_villager_shelters_at_dusk() -> void:
	await _build_world()
	GameClock.running = false
	GameClock.phase = GameClock.Phase.DUSK
	var house: House = world.houses[1]
	var door := house.door
	var outward := door.global_position - house.interior_center
	outward.y = 0.0
	var spawn := door.global_position + outward.normalized() * 5.0
	spawn.y = 0.3
	var villager: Villager = VILLAGER_SCENE.instantiate()
	villager.position = spawn
	runner.add_child(villager)
	villager.setup(
		"Test", house, {"kind": "wood", "position": Vector3(20, 0, 0)}, world, director, 0
	)
	await wait_physics(300)
	check(
		villager.is_hidden(),
		(
			"villager reached home (state %d, %.1f m from door)"
			% [villager.state, villager.global_position.distance_to(door.global_position)]
		)
	)
	equal(villager.stuck_events, 0, "villager was never stuck")
	less(villager.stuck_time, 5.0, "stuck timer below threshold")
	await _teardown()


func test_villager_leaves_house_at_dawn() -> void:
	await _build_world()
	GameClock.running = false
	GameClock.phase = GameClock.Phase.DUSK
	var house: House = world.houses[2]
	var door := house.door
	var outward := door.global_position - house.interior_center
	outward.y = 0.0
	var villager: Villager = VILLAGER_SCENE.instantiate()
	villager.position = door.global_position + outward.normalized() * 2.0
	villager.position.y = 0.3
	runner.add_child(villager)
	villager.setup(
		"Dawn", house, {"kind": "wood", "position": Vector3(20, 0, 0)}, world, director, 1
	)
	await wait_physics(240)
	check(villager.is_hidden(), "sheltered overnight")
	GameClock.phase = GameClock.Phase.DAY
	await wait_physics(120)
	check(not villager.is_hidden(), "left the house at dawn")
	await _teardown()
