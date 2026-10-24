extends Node
## Day / dusk / night / dawn state machine. Autoload: GameClock.
##
## Emits phase changes; owns no world state. `night` is the night number the
## next or current night belongs to.

enum Phase { DAY, DUSK, NIGHT, DAWN }

const PHASE_NAMES := ["Day", "Dusk", "Night", "Dawn"]

var phase: int = Phase.DUSK
var night := 1
var elapsed := 0.0
var running := false


func start(night_number := 1) -> void:
	night = clampi(night_number, 1, Game.tuning.total_nights)
	phase = Phase.DUSK
	elapsed = 0.0
	running = true
	EventBus.phase_changed.emit(phase, night)


func stop() -> void:
	running = false


func phase_duration() -> float:
	match phase:
		Phase.DAY:
			return Game.tuning.day_seconds
		Phase.DUSK:
			return Game.tuning.dusk_seconds
		Phase.NIGHT:
			return Game.tuning.night_seconds
		_:
			return Game.tuning.dawn_seconds


func remaining() -> float:
	return maxf(0.0, phase_duration() - elapsed)


func progress() -> float:
	var duration := phase_duration()
	if duration <= 0.0:
		return 1.0
	return clampf(elapsed / duration, 0.0, 1.0)


func phase_name() -> String:
	return PHASE_NAMES[phase]


func is_night() -> bool:
	return phase == Phase.NIGHT


func _process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	if elapsed >= phase_duration():
		_advance()


func skip_to_next_phase() -> void:
	if not running:
		return
	_advance()


func _advance() -> void:
	elapsed = 0.0
	match phase:
		Phase.DUSK:
			phase = Phase.NIGHT
			EventBus.phase_changed.emit(phase, night)
			EventBus.night_started.emit(night)
		Phase.NIGHT:
			phase = Phase.DAWN
			EventBus.night_ended.emit(night, true)
			EventBus.phase_changed.emit(phase, night)
			EventBus.dawn_tally.emit(Game.summary())
		Phase.DAWN:
			if night >= Game.tuning.total_nights:
				running = false
				EventBus.run_over.emit(true, Game.summary())
				return
			night += 1
			Game.set_night(night)
			phase = Phase.DAY
			EventBus.phase_changed.emit(phase, night)
		Phase.DAY:
			phase = Phase.DUSK
			EventBus.phase_changed.emit(phase, night)
