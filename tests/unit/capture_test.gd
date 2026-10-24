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
