extends TestCase
## Villager utility scoring: dusk pulls them home, daylight pulls them to work,
## threat pulls them toward shelter, distance always matters.


func test_dusk_beats_work() -> void:
	var choice := UtilityBrain.choose(0.0, true, 1.0, 20.0, 20.0, 40.0, true, false)
	equal(choice, 0, "dusk chooses home over work")


func test_day_beats_home() -> void:
	var choice := UtilityBrain.choose(0.0, false, 1.0, 10.0, 10.0, 40.0, true, false)
	equal(choice, 1, "day chooses work over home")


func test_threat_raises_shelter_score() -> void:
	var calm := UtilityBrain.score_home(8.0, true, 0.0)
	var danger := UtilityBrain.score_home(1.0, true, 0.0)
	greater(danger, calm, "closer threat scores higher shelter")


func test_distance_penalty() -> void:
	var near := UtilityBrain.score_work(0.0, 1.0, 10.0)
	var far := UtilityBrain.score_work(0.0, 1.0, 70.0)
	almost(near - far, 1.0, 0.001, "60 m costs one point")


func test_flee_wins_when_home_unavailable() -> void:
	var choice := UtilityBrain.choose(4.0, true, 1.0, 0.0, 200.0, 5.0, false, true)
	equal(choice, 2, "flees to an intact house")


func test_unavailable_flee_does_not_win() -> void:
	var choice := UtilityBrain.choose(1.0, false, 1.0, 30.0, 5.0, 500.0, true, false)
	equal(choice, 1, "works when no shelter exists")
