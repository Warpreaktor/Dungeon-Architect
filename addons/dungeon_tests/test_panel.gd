@tool
extends VBoxContainer

const GROUP_MANIFEST := "res://tests/group_suite.txt"
const FAILURE_MARKERS := ["SCRIPT ERROR:", "ERROR:", "Assertion failed:", "ASSERTION FAILED:"]
const TEST_TIMEOUT_MSEC := 60000

var suite_selector: OptionButton
var search_field: LineEdit
var test_list: ItemList
var output_log: TextEdit
var status_label: Label
var run_all_button: Button
var run_selected_button: Button
var rerun_failed_button: Button
var stop_button: Button

var _all_tests: Array[String] = []
var _group_tests: Dictionary = {}
var _results: Dictionary = {}
var _queue: Array[String] = []
var _process_id := -1
var _pipes: Dictionary = {}
var _stdout_buffer := PackedByteArray()
var _stderr_buffer := PackedByteArray()
var _last_display_update := 0
var _running_test := ""
var _running_started := 0
var _batch_count := 0
var _batch_completed := 0


func _ready() -> void:
	custom_minimum_size = Vector2(0, 260)
	_build_controls()
	_refresh_tests()
	set_process(false)


func _build_controls() -> void:
	var toolbar := HBoxContainer.new()
	add_child(toolbar)

	suite_selector = OptionButton.new()
	suite_selector.add_item("Все тесты")
	suite_selector.add_item("Групповой бой")
	suite_selector.item_selected.connect(func(_index: int) -> void: _update_list())
	toolbar.add_child(suite_selector)

	search_field = LineEdit.new()
	search_field.placeholder_text = "Фильтр по названию"
	search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_field.text_changed.connect(func(_value: String) -> void: _update_list())
	toolbar.add_child(search_field)

	var refresh_button := Button.new()
	refresh_button.text = "Обновить"
	refresh_button.pressed.connect(_refresh_tests)
	toolbar.add_child(refresh_button)

	run_all_button = Button.new()
	run_all_button.text = "Запустить набор"
	run_all_button.pressed.connect(_run_visible)
	toolbar.add_child(run_all_button)

	run_selected_button = Button.new()
	run_selected_button.text = "Запустить выбранные"
	run_selected_button.pressed.connect(_run_selected)
	toolbar.add_child(run_selected_button)

	rerun_failed_button = Button.new()
	rerun_failed_button.text = "Повторить ошибки"
	rerun_failed_button.pressed.connect(_rerun_failed)
	toolbar.add_child(rerun_failed_button)

	stop_button = Button.new()
	stop_button.text = "Остановить"
	stop_button.disabled = true
	stop_button.pressed.connect(_stop_batch)
	toolbar.add_child(stop_button)

	var splitter := HSplitContainer.new()
	splitter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(splitter)

	test_list = ItemList.new()
	test_list.custom_minimum_size = Vector2(300, 180)
	test_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	test_list.select_mode = ItemList.SELECT_MULTI
	test_list.item_selected.connect(_show_selected_output)
	splitter.add_child(test_list)

	output_log = TextEdit.new()
	output_log.editable = false
	output_log.custom_minimum_size = Vector2(350, 180)
	output_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	splitter.add_child(output_log)

	status_label = Label.new()
	add_child(status_label)


func _refresh_tests() -> void:
	_all_tests.clear()
	_find_tests("res://tests")
	_all_tests.sort()
	_group_tests.clear()
	if FileAccess.file_exists(GROUP_MANIFEST):
		var file := FileAccess.open(GROUP_MANIFEST, FileAccess.READ)
		if file != null:
			while not file.eof_reached():
				var name := file.get_line().strip_edges()
				if not name.is_empty() and not name.begins_with("#"):
					_group_tests[name] = true
	_update_list()


func _find_tests(folder: String) -> void:
	for filename in DirAccess.get_files_at(folder):
		if filename.begins_with("test_") and filename.ends_with(".gd"):
			_all_tests.append(folder.path_join(filename))
	for dirname in DirAccess.get_directories_at(folder):
		_find_tests(folder.path_join(dirname))


func _visible_tests() -> Array[String]:
	var paths: Array[String] = []
	var filter_text := search_field.text.to_lower()
	for path in _all_tests:
		if suite_selector.selected == 1 and not _group_tests.has(path.get_file()):
			continue
		if not filter_text.is_empty() and not path.to_lower().contains(filter_text):
			continue
		paths.append(path)
	return paths


func _update_list() -> void:
	var previous: Dictionary = {}
	for index in test_list.get_selected_items():
		previous[str(test_list.get_item_metadata(index))] = true
	test_list.clear()
	for path in _visible_tests():
		var record: Dictionary = _results.get(path, {})
		var state: String = str(record.get("status", ""))
		var prefix := "[  ] "
		match state:
			"PASS": prefix = "[OK] "
			"FAIL": prefix = "[!!] "
			"TIMEOUT": prefix = "[!!] "
			"CANCELLED": prefix = "[--] "
			"RUN": prefix = "[>>] "
		test_list.add_item(prefix + path.trim_prefix("res://tests/"))
		var index := test_list.item_count - 1
		test_list.set_item_metadata(index, path)
		if state == "FAIL" or state == "TIMEOUT":
			test_list.set_item_custom_fg_color(index, Color(1, 0.42, 0.42))
		elif state == "PASS":
			test_list.set_item_custom_fg_color(index, Color(0.55, 0.84, 0.59))
		if previous.has(path):
			test_list.select(index, false)
	_update_status()


func _show_selected_output(_index: int) -> void:
	var selected := test_list.get_selected_items()
	if selected.is_empty():
		return
	var path: String = str(test_list.get_item_metadata(selected[-1]))
	var result: Dictionary = _results.get(path, {})
	output_log.text = path + "\n\n" + str(result.get("output", "Ещё не запускался"))


func _run_visible() -> void:
	_start_batch(_visible_tests())


func _run_selected() -> void:
	var paths: Array[String] = []
	for index in test_list.get_selected_items():
		paths.append(str(test_list.get_item_metadata(index)))
	_start_batch(paths)


func _rerun_failed() -> void:
	var paths: Array[String] = []
	for path in _all_tests:
		if str(_results.get(path, {}).get("status", "")) in ["FAIL", "TIMEOUT"]:
			paths.append(path)
	_start_batch(paths)


func _start_batch(paths: Array[String]) -> void:
	if _process_id > 0 or paths.is_empty():
		return
	_queue = paths.duplicate()
	_batch_count = _queue.size()
	_batch_completed = 0
	run_all_button.disabled = true
	run_selected_button.disabled = true
	rerun_failed_button.disabled = true
	stop_button.disabled = false
	_start_next()


func _start_next() -> void:
	if _queue.is_empty():
		run_all_button.disabled = false
		run_selected_button.disabled = false
		rerun_failed_button.disabled = false
		stop_button.disabled = true
		set_process(false)
		_update_status()
		return
	_running_test = _queue.pop_front()
	_running_started = Time.get_ticks_msec()
	_last_display_update = 0
	_stdout_buffer.clear()
	_stderr_buffer.clear()
	_results[_running_test] = {"status": "RUN", "output": "Запускается…"}
	_update_list()
	output_log.text = "Запуск: %s" % _running_test
	var arguments := PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", _running_test
	])
	_pipes = OS.execute_with_pipe(OS.get_executable_path(), arguments, false)
	_process_id = int(_pipes.get("pid", -1))
	if _process_id <= 0:
		_pipes.clear()
		_finish_test("FAIL", "Не удалось запустить процесс Godot")
		return
	set_process(true)
	_update_status()


func _read_output() -> void:
	var stdout := _pipes.get("stdio") as FileAccess
	var stderr := _pipes.get("stderr") as FileAccess
	if stdout != null:
		var available := stdout.get_length()
		if available > 0:
			_stdout_buffer.append_array(stdout.get_buffer(available))
	if stderr != null:
		var available := stderr.get_length()
		if available > 0:
			_stderr_buffer.append_array(stderr.get_buffer(available))


func _collected_output() -> String:
	return _stdout_buffer.get_string_from_utf8() + _stderr_buffer.get_string_from_utf8()


func _has_failure_marker(text: String) -> bool:
	for marker in FAILURE_MARKERS:
		if text.findn(marker) >= 0:
			return true
	return false


func _process(_delta: float) -> void:
	if _process_id <= 0:
		return
	_read_output()
	if _has_failure_marker(_collected_output()):
		if OS.is_process_running(_process_id):
			OS.kill(_process_id)
		_read_output()
		_finish_test("FAIL", _collected_output())
		return
	var elapsed := Time.get_ticks_msec() - _running_started
	if elapsed - _last_display_update >= 300:
		_last_display_update = elapsed
		status_label.text = "Выполнено %d/%d | Сейчас: %s (%.1f с)" % [
			_batch_completed, _batch_count, _running_test.get_file(), elapsed / 1000.0
		]
		output_log.text = "Выполняется: %s\n\n%s" % [_running_test, _collected_output()]
	if elapsed >= TEST_TIMEOUT_MSEC:
		OS.kill(_process_id)
		_read_output()
		_queue.clear()
		_finish_test("TIMEOUT", "Превышено время выполнения (60 с). Набор остановлен.\n" + _collected_output())
		return
	if not OS.is_process_running(_process_id):
		_read_output()
		var exit_code := OS.get_process_exit_code(_process_id)
		var output := _collected_output()
		var failed := exit_code != 0 or _has_failure_marker(output)
		if output.strip_edges().is_empty():
			failed = true
			output = "Процесс завершился без вывода. Успех теста не подтверждён."
		if exit_code != 0:
			output += "\nКод завершения: %d" % exit_code
		_finish_test("FAIL" if failed else "PASS", output)


func _stop_batch() -> void:
	_queue.clear()
	if _process_id > 0:
		OS.kill(_process_id)
		_read_output()
		_finish_test("CANCELLED", "Остановлено пользователем\n" + _collected_output())
	else:
		_start_next()


func _finish_test(status: String, output: String) -> void:
	var elapsed := float(Time.get_ticks_msec() - _running_started) / 1000.0
	_results[_running_test] = {"status": status, "output": output, "seconds": elapsed}
	_batch_completed += 1
	output_log.text = "%s  %s  (%.2f с)\n\n%s" % [status, _running_test, elapsed, output]
	_pipes.clear()
	_process_id = -1
	_update_list()
	call_deferred("_start_next")


func _update_status() -> void:
	var passed := 0
	var failed := 0
	for record in _results.values():
		match str(record.get("status", "")):
			"PASS": passed += 1
			"FAIL", "TIMEOUT": failed += 1
	if _process_id > 0 or not _queue.is_empty():
		status_label.text = "Выполнено %d/%d | Успешно: %d | Ошибок: %d | Сейчас: %s" % [
			_batch_completed, _batch_count, passed, failed, _running_test.get_file()
		]
	elif _batch_count > 0:
		status_label.text = "Выполнено %d/%d | Успешно: %d | Ошибок: %d" % [
			_batch_completed, _batch_count, passed, failed
		]
	else:
		status_label.text = "Найдено: %d | Успешно: %d | Ошибок: %d" % [
			_visible_tests().size(), passed, failed
		]


func _exit_tree() -> void:
	_queue.clear()
	if _process_id > 0:
		OS.kill(_process_id)
		_pipes.clear()
		_process_id = -1
