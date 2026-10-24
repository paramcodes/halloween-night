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


## The staged top-up is what lets a 60 s take keep firing. A fixed-interval drip
## quantised down to 4.05 fuel/s on a 30 fps render, so the tank emptied at 51 s
## and the last seconds of the clip had no flame.
func test_staged_top_up_keeps_the_tank_for_a_minute() -> void:
	var burn := Game.tuning.burn_rate_per_second
	var frame := 1.0 / 30.0
	var fuel := Game.tuning.fuel_capacity
	var credit := 0.0
	var lowest := fuel
	for _i in range(1800):
		fuel = maxf(0.0, fuel - burn * frame)
		var step := CaptureRig.fuel_step(frame, credit, burn, 1.5)
		credit = step[0]
		fuel = minf(Game.tuning.fuel_capacity, fuel + step[1])
		lowest = minf(lowest, fuel)
	almost(lowest, 10.0, 1.0, "a minute of fire drains the tank by 90")
	greater(lowest, 5.0, "the flame never runs dry mid-take")
