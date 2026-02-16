extends "res://scripts/ads/ad_provider_base.gd"

const SETTINGS_PREFIX := "recoil/ads/steam/"

var _sdk: Object
var _sdk_name: String = ""
var _pending_rewarded_callback: Callable = Callable()
var _rewarded_in_flight: bool = false

func _init() -> void:
	_resolve_sdk()
	_setup_sdk()

func provider_name() -> String:
	if _sdk == null:
		return "steam_fallback_mock"
	return "steam_plugin_%s" % _sdk_name

func is_rewarded_available(_ad_type: String) -> bool:
	if _sdk == null:
		return _setting_bool("fallback_rewarded_available", true)
	if _sdk.has_method("is_rewarded_available"):
		return bool(_sdk.call("is_rewarded_available"))
	if _sdk.has_method("has_rewarded_offer"):
		return bool(_sdk.call("has_rewarded_offer"))
	return true

func show_rewarded_ad(ad_type: String, callback: Callable) -> void:
	if _sdk == null:
		callback.call_deferred(_setting_bool("fallback_grants_reward", true))
		return
	_pending_rewarded_callback = callback
	_rewarded_in_flight = true
	var offer_id := _setting_string("rewarded_offer_id", ad_type)
	if _sdk.has_method("show_rewarded_ad"):
		_sdk.call("show_rewarded_ad", offer_id)
		return
	if _sdk.has_method("show_rewarded_offer"):
		_sdk.call("show_rewarded_offer", offer_id)
		return
	if _sdk.has_method("showRewarded"):
		_sdk.call("showRewarded", offer_id)
		return
	if _sdk.has_method("request_rewarded"):
		_sdk.call("request_rewarded", offer_id)
		return
	_complete_pending_rewarded(false)

func show_banner(placement: String) -> void:
	if _sdk == null:
		return
	var configured_placement := _setting_string("banner_placement", placement)
	if _sdk.has_method("show_banner"):
		_sdk.call("show_banner", configured_placement)
		return
	if _sdk.has_method("show_overlay_banner"):
		_sdk.call("show_overlay_banner", configured_placement)
		return
	if _sdk.has_method("showBanner"):
		_sdk.call("showBanner", configured_placement)

func hide_banner() -> void:
	if _sdk == null:
		return
	if _sdk.has_method("hide_banner"):
		_sdk.call("hide_banner")
		return
	if _sdk.has_method("hide_overlay_banner"):
		_sdk.call("hide_overlay_banner")
		return
	if _sdk.has_method("hideBanner"):
		_sdk.call("hideBanner")

func _resolve_sdk() -> void:
	var preferred_singleton := _setting_string("plugin_singleton", "")
	if preferred_singleton != "" and Engine.has_singleton(preferred_singleton):
		_sdk = Engine.get_singleton(preferred_singleton)
		_sdk_name = preferred_singleton
		return
	var possible_singletons := [
		"SteamAds",
		"GodotSteamAds",
		"Steamworks",
		"GodotSteam",
	]
	for singleton_name in possible_singletons:
		if Engine.has_singleton(singleton_name):
			_sdk = Engine.get_singleton(singleton_name)
			_sdk_name = singleton_name
			return

func _setup_sdk() -> void:
	if _sdk == null:
		return
	if _sdk.has_method("initialize"):
		_sdk.call("initialize")
	elif _sdk.has_method("init"):
		_sdk.call("init")
	_connect_if_signal_exists("rewarded_granted", _on_rewarded_granted)
	_connect_if_signal_exists("rewarded_completed", _on_rewarded_granted)
	_connect_if_signal_exists("rewarded_failed", _on_rewarded_failed)
	_connect_if_signal_exists("rewarded_closed", _on_rewarded_closed)

func _connect_if_signal_exists(signal_name: String, handler: Callable) -> void:
	if _sdk == null:
		return
	if not _sdk.has_signal(signal_name):
		return
	if _sdk.is_connected(signal_name, handler):
		return
	_sdk.connect(signal_name, handler)

func _on_rewarded_granted(_args: Variant = null) -> void:
	_complete_pending_rewarded(true)

func _on_rewarded_failed(_args: Variant = null) -> void:
	_complete_pending_rewarded(false)

func _on_rewarded_closed(_args: Variant = null) -> void:
	if _rewarded_in_flight:
		_complete_pending_rewarded(false)

func _complete_pending_rewarded(granted: bool) -> void:
	if _pending_rewarded_callback.is_valid():
		_pending_rewarded_callback.call(granted)
	_pending_rewarded_callback = Callable()
	_rewarded_in_flight = false

func _setting_string(key: String, default_value: String) -> String:
	var full_key := "%s%s" % [SETTINGS_PREFIX, key]
	if not ProjectSettings.has_setting(full_key):
		return default_value
	return str(ProjectSettings.get_setting(full_key))

func _setting_bool(key: String, default_value: bool) -> bool:
	var full_key := "%s%s" % [SETTINGS_PREFIX, key]
	if not ProjectSettings.has_setting(full_key):
		return default_value
	return bool(ProjectSettings.get_setting(full_key))
