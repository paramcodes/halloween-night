class_name SaveData
extends RefCounted
## Pure save-file logic: wrap_run, parse, migrate, validate.
## No file access here, so every rule is unit-testable headless.

const SCHEMA_VERSION := 1

const DEFAULT_STATS := {
	"kills": 0,
	"fuel_spent": 0.0,
	"doors_lost": 0,
	"villagers_lost": 0,
	"nights_survived": 0,
	"bell_uses": 0,
}


static func wrap_run(run: Dictionary) -> Dictionary:
	var data := run.duplicate(true)
	data["schema_version"] = SCHEMA_VERSION
	data["saved_at_unix"] = int(Time.get_unix_time_from_system())
	return data


static func parse(raw_text: String) -> Dictionary:
	if raw_text.strip_edges().is_empty():
		return {"ok": false, "error": "empty save file", "data": {}}
	var json := JSON.new()
	if json.parse(raw_text) != OK:
		return {"ok": false, "error": "invalid JSON at line %d" % json.get_error_line(), "data": {}}
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "save is not a JSON object", "data": {}}
	var migrated := migrate(parsed as Dictionary)
	if not validate(migrated):
		return {"ok": false, "error": "save failed validation", "data": migrated}
	return {"ok": true, "error": "", "data": migrated}


static func migrate(raw: Dictionary) -> Dictionary:
	var data := raw.duplicate(true)
	var version := int(data.get("schema_version", 0))
	if version > SCHEMA_VERSION:
		# A future save is not ours to guess at; parse() will still validate it.
		data["schema_version"] = version
		return data
	if version < 1:
		data = _migrate_0_to_1(data)
		data["schema_version"] = 1
	return data


static func _migrate_0_to_1(data: Dictionary) -> Dictionary:
	if not data.has("fuel"):
		data["fuel"] = 100.0
	if not data.has("planks"):
		data["planks"] = 3
	if not data.has("bell_charges"):
		data["bell_charges"] = 3
	if not data.has("doors") or typeof(data["doors"]) != TYPE_DICTIONARY:
		data["doors"] = {}
	if not data.has("villagers") or typeof(data["villagers"]) != TYPE_ARRAY:
		data["villagers"] = []
	var stats: Dictionary = (
		data.get("stats", {}) if typeof(data.get("stats", {})) == TYPE_DICTIONARY else {}
	)
	for key: String in DEFAULT_STATS:
		if not stats.has(key):
			stats[key] = DEFAULT_STATS[key]
	data["stats"] = stats
	return data


static func validate(data: Dictionary) -> bool:
	if not data.has("night"):
		return false
	var night := int(data.get("night", 0))
	if night < 1 or night > 7:
		return false
	var fuel := float(data.get("fuel", 0.0))
	if fuel < 0.0 or fuel > 100.0:
		return false
	if not data.has("stats") or typeof(data["stats"]) != TYPE_DICTIONARY:
		return false
	return true


static func to_text(data: Dictionary) -> String:
	return JSON.stringify(wrap_run(data), "\t")


static func default_run(night := 1) -> Dictionary:
	return {
		"night": night,
		"fuel": 100.0,
		"planks": 3,
		"bell_charges": 3,
		"doors": {},
		"villagers": [],
		"stats": DEFAULT_STATS.duplicate(true),
	}
