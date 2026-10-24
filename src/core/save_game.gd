extends Node
## Versioned JSON saves. Autoload: SaveGame.
##
## Save points are dusk boundaries, so a reload always resumes at a phase
## boundary with stable world state.

const SAVE_PATH := "user://godor_save.json"

var path := SAVE_PATH
var last_error := ""


func has_save() -> bool:
	return FileAccess.file_exists(path)


func write(run: Dictionary) -> bool:
	last_error = ""
	var text := SaveData.to_text(run)
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		last_error = "cannot open temp save: %s" % error_string(FileAccess.get_open_error())
		return false
	file.store_string(text)
	file.close()
	var absolute := ProjectSettings.globalize_path(path)
	var temp_absolute := ProjectSettings.globalize_path(temp_path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute)
	var err := DirAccess.rename_absolute(temp_absolute, absolute)
	if err != OK:
		last_error = "cannot promote save: %s" % error_string(err)
		return false
	return true


func read() -> Dictionary:
	last_error = ""
	if not has_save():
		last_error = "no save file"
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "cannot read save"
		return {}
	var parsed := SaveData.parse(file.get_as_text())
	file.close()
	if not parsed["ok"]:
		last_error = str(parsed["error"])
		return {}
	return parsed["data"]


func clear() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
