extends Node
## SaveManager (autoload) - thin wrapper around a single ConfigFile.
## Centralises persistence so nothing else needs to touch the disk.
## Loads a legacy save (1010_save.cfg) and migrates it on first launch.

const SAVE_PATH := "user://gridlock_save.cfg"
const LEGACY_PATH := "user://1010_save.cfg"

var _config := ConfigFile.new()

func _ready() -> void:
	if not FileAccess.file_exists(SAVE_PATH) and FileAccess.file_exists(LEGACY_PATH):
		_config.load(LEGACY_PATH)
		_config.save(SAVE_PATH)
	else:
		_config.load(SAVE_PATH)

func get_value(section: String, key: String, default: Variant) -> Variant:
	return _config.get_value(section, key, default)

func set_value(section: String, key: String, value: Variant) -> void:
	_config.set_value(section, key, value)
	_config.save(SAVE_PATH)