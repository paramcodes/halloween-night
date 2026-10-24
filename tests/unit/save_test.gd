extends TestCase
## Save format, versioning and migration.

const TEST_PATH := "user://test_godor_save.json"


func test_round_trip() -> void:
	var run := SaveData.default_run(3)
	run["fuel"] = 42.5
	run["stats"]["kills"] = 12
	var parsed := SaveData.parse(SaveData.to_text(run))
	check(bool(parsed["ok"]), "save parses: %s" % str(parsed["error"]))
	var data: Dictionary = parsed["data"]
	equal(int(data.get("night", 0)), 3, "night survives round trip")
	almost(float(data.get("fuel", 0.0)), 42.5, 0.001, "fuel survives round trip")
	equal(int(data["stats"]["kills"]), 12, "stats survive round trip")
	equal(int(data.get("schema_version", 0)), SaveData.SCHEMA_VERSION, "schema version stamped")
	check(data.has("saved_at_unix"), "timestamp stamped")


func test_migrates_unversioned_save() -> void:
	var parsed := SaveData.parse('{"night": 4, "fuel": 33}')
	check(bool(parsed["ok"]), "legacy save parses")
	var data: Dictionary = parsed["data"]
	equal(int(data.get("schema_version", 0)), 1, "migrated to v1")
	almost(float(data.get("fuel", 0.0)), 33.0, 0.001, "legacy fuel kept")
	equal(int(data.get("planks", 0)), 3, "missing planks defaulted")
	equal(int(data.get("bell_charges", 0)), 3, "missing bells defaulted")
	equal(typeof(data.get("doors")), TYPE_DICTIONARY, "doors defaulted")
	equal(typeof(data.get("villagers")), TYPE_ARRAY, "villagers defaulted")
	equal(int(data["stats"].get("kills", -1)), 0, "stats defaulted")


func test_rejects_bad_saves() -> void:
	var garbage := SaveData.parse("this is not json")
	check(not bool(garbage["ok"]), "garbage is rejected")
	var out_of_range := SaveData.parse('{"night": 99, "fuel": 50}')
	check(not bool(out_of_range["ok"]), "night 99 is rejected")
	var negative_fuel := SaveData.parse('{"night": 2, "fuel": -5}')
	check(not bool(negative_fuel["ok"]), "negative fuel is rejected")


func test_savegame_round_trip() -> void:
	var original := SaveGame.path
	SaveGame.path = TEST_PATH
	SaveGame.clear()
	var run := SaveData.default_run(5)
	run["fuel"] = 12.5
	check(SaveGame.write(run), "write save: %s" % SaveGame.last_error)
	check(SaveGame.has_save(), "save file exists")
	var loaded := SaveGame.read()
	equal(int(loaded.get("night", 0)), 5, "night loaded from disk")
	almost(float(loaded.get("fuel", 0.0)), 12.5, 0.001, "fuel loaded from disk")
	SaveGame.clear()
	check(not SaveGame.has_save(), "save cleared")
	SaveGame.path = original
