class_name DisplayUtil
extends RefCounted
## Persisted full-screen handling. Safe to call under the headless server.

static func apply_saved() -> void:
	set_fullscreen(bool(SaveManager.get_value("display", "fullscreen", true)))

static func set_fullscreen(enabled: bool) -> void:
	SaveManager.set_value("display", "fullscreen", enabled)
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

static func toggle_fullscreen() -> bool:
	var enabled := not is_fullscreen()
	set_fullscreen(enabled)
	return enabled

static func is_fullscreen() -> bool:
	if DisplayServer.get_name() == "headless":
		return bool(SaveManager.get_value("display", "fullscreen", true))
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
