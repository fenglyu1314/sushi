extends Node
## 存档管理（Autoload 单例）
## M0：仅序列化日周期状态，验证存读机制。后续扩展现金/库存/布局/进度。

const SAVE_PATH := "user://savegame.json"


func save_game() -> void:
	var data := {
		"day": DayCycle.current_day,
		"phase": DayCycle.current_phase,
		"tick": DayCycle.current_tick,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("存档失败：无法写入 %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data))
	f.close()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return false
	DayCycle.current_day = int(data.get("day", 0))
	DayCycle.current_phase = int(data.get("phase", 0))
	DayCycle.current_tick = int(data.get("tick", 0))
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
