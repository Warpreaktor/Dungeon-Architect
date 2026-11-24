class_name ProgressSaveStore
extends RefCounted

const DEFAULT_DIRECTORY := "user://saves"
const SAVE_FILE := "progress.json"
const BACKUP_FILE := "progress.json.bak"
const TEMP_FILE := "progress.json.tmp"

var directory: String
var campaign_library: CampaignLibrary
var last_error: String = ""


func _init(save_directory: String = DEFAULT_DIRECTORY, campaign_directory: String = CampaignLibrary.DIRECTORY) -> void:
	directory = save_directory
	campaign_library = CampaignLibrary.new(campaign_directory)


func save_game(session: GameSession, maps_by_id: Dictionary) -> bool:
	last_error = ""
	if session == null:
		last_error = "Нет активного прохождения."
		return false
	var campaigns: Dictionary = _load_campaigns(maps_by_id)
	if not campaign_library.last_error.is_empty():
		last_error = campaign_library.last_error
		return false
	var snapshot: Dictionary = session.progress_snapshot()
	if snapshot.is_empty() or GameSession.from_progress_snapshot(snapshot, maps_by_id, campaigns) == null:
		last_error = "Текущее прохождение нельзя сохранить."
		return false
	var serialized: String = JSON.stringify(snapshot, "\t")
	if _decode_session(serialized, maps_by_id) == null:
		last_error = "Не удалось проверить данные прохождения."
		return false

	var save_path: String = _path(SAVE_FILE)
	var backup_path: String = _path(BACKUP_FILE)
	var temp_path: String = _path(TEMP_FILE)
	var save_exists: bool = FileAccess.file_exists(save_path)
	var backup_exists: bool = FileAccess.file_exists(backup_path)
	var save_valid: bool = save_exists and _read_session(save_path, maps_by_id) != null
	var backup_valid: bool = backup_exists and _read_session(backup_path, maps_by_id) != null
	if (save_exists and not save_valid and _is_incompatible_save(save_path, maps_by_id)) or (backup_exists and not backup_valid and _is_incompatible_save(backup_path, maps_by_id)):
		last_error = "Существующее сохранение несовместимо; перезапись отменена."
		return false
	if (save_exists or backup_exists) and not save_valid and not backup_valid:
		last_error = "Существующее сохранение повреждено или несовместимо; перезапись отменена."
		return false
	if not DirAccess.dir_exists_absolute(directory):
		var mkdir_error: int = DirAccess.make_dir_recursive_absolute(directory)
		if mkdir_error != OK:
			last_error = "Не удалось создать папку сохранений: %s" % error_string(mkdir_error)
			return false

	var writer: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if writer == null:
		last_error = "Не удалось открыть временный файл: %s" % error_string(FileAccess.get_open_error())
		return false
	writer.store_string(serialized)
	writer.flush()
	var write_error: int = writer.get_error()
	writer = null
	if write_error != OK:
		last_error = "Не удалось записать прохождение: %s" % error_string(write_error)
		return false
	if _read_text(temp_path) != serialized or _read_session(temp_path, maps_by_id) == null:
		last_error = "Проверка записанного файла не пройдена."
		return false

	if save_valid:
		if backup_exists:
			var remove_error: int = DirAccess.remove_absolute(backup_path)
			if remove_error != OK:
				last_error = "Не удалось обновить резервную копию: %s" % error_string(remove_error)
				return false
		var backup_error: int = DirAccess.rename_absolute(save_path, backup_path)
		if backup_error != OK:
			last_error = "Не удалось защитить предыдущее сохранение: %s" % error_string(backup_error)
			return false
	elif save_exists:
		var remove_error: int = DirAccess.remove_absolute(save_path)
		if remove_error != OK:
			last_error = "Не удалось заменить повреждённый файл: %s" % error_string(remove_error)
			return false

	var promote_error: int = DirAccess.rename_absolute(temp_path, save_path)
	if promote_error != OK:
		if save_valid and not FileAccess.file_exists(save_path):
			DirAccess.rename_absolute(backup_path, save_path)
		last_error = "Не удалось завершить сохранение: %s" % error_string(promote_error)
		return false
	return true


func load_game(maps_by_id: Dictionary) -> GameSession:
	last_error = ""
	var save_path: String = _path(SAVE_FILE)
	var backup_path: String = _path(BACKUP_FILE)
	var session: GameSession = _read_session(save_path, maps_by_id)
	if session != null:
		return session
	session = _read_session(backup_path, maps_by_id)
	if session != null:
		return session
	last_error = "Сохранение отсутствует, повреждено или несовместимо с картами."
	return null


func has_valid_save(maps_by_id: Dictionary) -> bool:
	return _read_session(_path(SAVE_FILE), maps_by_id) != null or _read_session(_path(BACKUP_FILE), maps_by_id) != null


func _path(filename: String) -> String:
	return directory.path_join(filename)


func _read_session(path: String, maps_by_id: Dictionary) -> GameSession:
	if not FileAccess.file_exists(path):
		return null
	return _decode_session(_read_text(path), maps_by_id)


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _decode_session(content: String, maps_by_id: Dictionary) -> GameSession:
	if content.is_empty():
		return null
	var json := JSON.new()
	if json.parse(content) != OK or not (json.data is Dictionary):
		return null
	var campaigns: Dictionary = _load_campaigns(maps_by_id)
	if not campaign_library.last_error.is_empty():
		return null
	return GameSession.from_progress_snapshot(json.data, maps_by_id, campaigns)


func _load_campaigns(maps_by_id: Dictionary) -> Dictionary:
	return campaign_library.load_all(maps_by_id)


func _is_incompatible_save(path: String, maps_by_id: Dictionary) -> bool:
	var parsed: Variant = JSON.parse_string(_read_text(path))
	return parsed is Dictionary and _decode_session(JSON.stringify(parsed), maps_by_id) == null
