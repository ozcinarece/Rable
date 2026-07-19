extends Node
## Kayit yoneticisi - autoload (singleton).
## Oyun durumunu JSON olarak user:// dizinine yazar/okur.
## Android'de bu dizin uygulamanin ozel veri klasorudur; oyun
## silinmedikce kayit durur. Ne kaydedilecegine World karar verir.

const SAVE_PATH: String = "user://save.json"

func save_data(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Kayit yazilamadi: " + str(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data))
	file.close()

## Kayit yoksa veya bozuksa bos sozluk doner.
func load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed
	return {}

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
