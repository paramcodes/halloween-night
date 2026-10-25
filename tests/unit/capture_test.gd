extends TestCase
## Locks the capture harness layer: the soft particle puff and the burning body's
## own fire, so a clip cannot silently regress into square puffs or a red cut-out.


func test_soft_puff_is_a_soft_disc() -> void:
	var texture := Palette.soft_puff()
	equal(texture.get_width(), 64, "puff texture width")
	equal(texture.get_height(), 64, "puff texture height")
	var image := texture.get_image()
	greater(image.get_pixel(32, 32).a, 0.9, "puff is opaque at its centre")
	almost(image.get_pixel(0, 0).a, 0.0, 0.001, "puff fades to nothing at the edge")
	check(Palette.material("flame_core").albedo_texture == texture, "the flame uses the puff")
	check(Palette.material("flame_edge").albedo_texture == texture, "the edge uses the puff")
	check(Palette.material("smoke").albedo_texture == texture, "the smoke uses the puff")


func test_burning_body_carries_its_own_fire() -> void:
	var visual := CharacterVisual.new()
	runner.add_child(visual)
	visual.setup("shambler", "shambler")
	check(visual.get_node_or_null("BurnParticles") == null, "no fire before ignition")
	visual.set_burning(true)
	var fire := visual.get_node_or_null("BurnParticles") as GPUParticles3D
	check(fire != null, "ignition adds a fire emitter")
	check(fire.emitting, "the emitter runs while burning")
	visual.set_burning(false)
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	check(visual.get_node_or_null("BurnParticles") == null, "the fire is freed with the burn")
	visual.queue_free()


## The plume is a hot core plus a cooler, wider edge layer and a smoke tail, so
## it reads as a flame instead of a single solid bar.
func test_flame_carries_an_edge_layer() -> void:
	var gun := Flamethrower.new()
	runner.add_child(gun)
	check(gun.get_node_or_null("Nozzle/FlameEdge") != null, "the flame has a cooler edge layer")
	gun.queue_free()


## The staged top-up is what lets a long take keep firing. A fixed-interval drip
## quantised down to 4.05 fuel/s on a 30 fps render, so the tank ran dry at 51 s
## of a 60 s take. The drip is now applied every frame, so the level tracks the
## intended drain instead of dipping to zero between lumps.
func test_staged_top_up_keeps_the_tank_for_a_minute() -> void:
	var burn := Game.tuning.burn_rate_per_second
	var duration := 60.0
	var fire_seconds := maxf(1.0, duration - 0.8 - 1.8)
	var net_drain := clampf(Game.tuning.fuel_capacity / fire_seconds, 0.1, burn - 0.1)
	var frame := 1.0 / 30.0
	var fuel := Game.tuning.fuel_capacity
	var lowest := fuel
	for i in range(int(duration * 30.0)):
		fuel = maxf(0.0, fuel - burn * frame)
		fuel = minf(Game.tuning.fuel_capacity, fuel + CaptureRig.fuel_step(frame, burn, net_drain))
		lowest = minf(lowest, fuel)
	check(lowest > 0.0, "the flame stays lit for the whole minute")
	almost(lowest, 0.0, 1.0, "the tank empties right at the cut")
