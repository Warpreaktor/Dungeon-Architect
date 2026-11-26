extends RefCounted

const SETTINGS_PATH := "user://editor_state.cfg"
var directory: String = "user://da_editor_test_%d" % Time.get_ticks_usec()
var _had_settings: bool = FileAccess.file_exists(SETTINGS_PATH)
var _settings: PackedByteArray = FileAccess.get_file_as_bytes(SETTINGS_PATH) if _had_settings else PackedByteArray()


func configure(editor: Node) -> void:
	editor.set("_editor_maps_directory", directory)


func cleanup() -> void:
	if DirAccess.dir_exists_absolute(directory):
		for filename in DirAccess.get_files_at(directory):
			assert(DirAccess.remove_absolute(directory.path_join(filename)) == OK)
		assert(DirAccess.remove_absolute(directory) == OK)
	if _had_settings:
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		assert(file != null)
		file.store_buffer(_settings)
		file.close()
	elif FileAccess.file_exists(SETTINGS_PATH):
		assert(DirAccess.remove_absolute(SETTINGS_PATH) == OK)
