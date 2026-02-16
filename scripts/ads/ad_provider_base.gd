extends RefCounted
class_name AdProviderBase

func provider_name() -> String:
	return "base"

func is_rewarded_available(_ad_type: String) -> bool:
	return false

func show_rewarded_ad(_ad_type: String, callback: Callable) -> void:
	callback.call(false)

func show_banner(_placement: String) -> void:
	pass

func hide_banner() -> void:
	pass
