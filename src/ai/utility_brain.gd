class_name UtilityBrain
extends RefCounted
## Villager decision scoring, kept pure so it can be unit-tested without a scene.
##
## score = w_safety * 1/threat + w_home * is_dusk * 10 + w_work * urgency - dist/60

const W_SAFETY := 1.0
const W_HOME := 1.0
const W_WORK := 1.0


static func score_home(threat: float, shelter_window: bool, distance: float) -> float:
	var safety := W_SAFETY / maxf(0.25, threat)
	var home := W_HOME * 10.0 if shelter_window else 0.0
	return safety + home - distance / 60.0


static func score_work(threat: float, urgency: float, distance: float) -> float:
	var safety := W_SAFETY / maxf(0.25, threat)
	var work := W_WORK * urgency
	return safety + work - distance / 60.0


static func score_flee(threat: float, distance: float) -> float:
	return 6.0 + W_SAFETY / maxf(0.25, threat) - distance / 60.0


## Returns 0 = home, 1 = work, 2 = flee to another house.
static func choose(
	threat: float,
	shelter_window: bool,
	work_urgency: float,
	home_distance: float,
	work_distance: float,
	flee_distance: float,
	home_available: bool,
	flee_available: bool
) -> int:
	var home := score_home(threat, shelter_window, home_distance) if home_available else -INF
	var work := score_work(threat, work_urgency, work_distance)
	var flee := score_flee(threat, flee_distance) if flee_available else -INF
	if flee_available and threat > 0.0 and flee > home and flee > work:
		return 2
	if home >= work:
		return 0
	return 1
