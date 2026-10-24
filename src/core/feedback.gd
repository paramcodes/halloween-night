class_name Feedback
extends RefCounted
## Camera and animation feedback maths. Static and pure so the feel constants can
## be unit-tested without a scene: recoil, damage shake, idle breathing, gait
## variation. Nothing here allocates or reads the input system.


static func recoil_step(current_deg: float, firing: bool, delta: float, tuning: Tuning) -> float:
	if firing:
		return minf(tuning.fire_recoil_deg, current_deg + tuning.fire_recoil_attack * delta)
	return maxf(0.0, current_deg - tuning.fire_recoil_recover * delta)


static func shake_amplitude(damage: float, tuning: Tuning) -> float:
	return clampf(damage * tuning.camera_shake_per_damage, 0.0, tuning.camera_shake_max_deg)


static func shake_step(current_deg: float, delta: float, tuning: Tuning) -> float:
	return maxf(0.0, current_deg - tuning.camera_shake_decay * delta)


static func shake_rotation(amplitude_deg: float, ticks_msec: int) -> Vector3:
	if amplitude_deg <= 0.0:
		return Vector3.ZERO
	var seconds := float(ticks_msec) * 0.001
	var pitch := sin(seconds * 43.0) * amplitude_deg
	var yaw := cos(seconds * 57.0) * amplitude_deg * 0.6
	return Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0)


static func breath_speed(ticks_msec: int, phase: float, tuning: Tuning) -> float:
	var period := maxf(0.1, tuning.idle_breath_period)
	var seconds := float(ticks_msec) * 0.001 + phase * period
	var wave := sin(TAU * seconds / period)
	return 1.0 + wave * tuning.idle_breath_amount


static func gait_scale(roll: float, spread: float) -> float:
	return clampf(1.0 + (roll * 2.0 - 1.0) * spread, 0.5, 1.5)
