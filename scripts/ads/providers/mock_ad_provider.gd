extends "res://scripts/ads/ad_provider_base.gd"

func provider_name() -> String:
	return "mock"

func is_rewarded_available(_ad_type: String) -> bool:
	return true

func show_rewarded_ad(_ad_type: String, callback: Callable) -> void:
	callback.call_deferred(true)
