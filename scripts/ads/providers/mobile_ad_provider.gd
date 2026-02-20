extends RefCounted

# Mobile provider adapts plugin-specific method names to the common ad interface.
# Signal bridging/settings reads are delegated to shared provider utilities.

const ProviderSignalBridgeScript = preload("res://scripts/ads/providers/provider_signal_bridge.gd")
const ProviderSettingsUtilScript = preload("res://scripts/ads/providers/provider_settings_util.gd")

const REWARDED_TEST_ANDROID := "ca-app-pub-3940256099942544/5224354917"
const REWARDED_TEST_IOS := "ca-app-pub-3940256099942544/1712485313"
const BANNER_TEST_ANDROID := "ca-app-pub-3940256099942544/6300978111"
const BANNER_TEST_IOS := "ca-app-pub-3940256099942544/2934735716"
const SETTINGS_PREFIX := "recoil/ads/"

var _sdk: Object
var _sdk_name: String = ""
var _pending_rewarded_callback: Callable = Callable()
var _pending_rewarded_type: String = ""
var _rewarded_loaded: bool = false
var _rewarded_shown: bool = false
var _reward_granted_this_show: bool = false

func _init() -> void:
	_resolve_sdk()
	_setup_sdk()
	_preload_rewarded()

func provider_name() -> String:
	if _sdk == null:
		return "mobile_fallback_mock"
	return "mobile_plugin_%s" % _sdk_name

func is_rewarded_available(_ad_type: String) -> bool:
	if _sdk == null:
		return true
	if _rewarded_loaded:
		return true
	if _sdk.has_method("is_rewarded_loaded"):
		return bool(_sdk.call("is_rewarded_loaded"))
	return true

func show_rewarded_ad(ad_type: String, callback: Callable) -> void:
	if _sdk == null:
		callback.call_deferred(true)
		return
	_pending_rewarded_callback = callback
	_pending_rewarded_type = ad_type
	_rewarded_shown = false
	_reward_granted_this_show = false
	var rewarded_unit_id := _rewarded_unit_id()
	if _sdk.has_method("show_rewarded_ad"):
		_sdk.call("show_rewarded_ad", rewarded_unit_id)
		_rewarded_shown = true
		return
	if _sdk.has_method("show_rewarded"):
		_sdk.call("show_rewarded", rewarded_unit_id)
		_rewarded_shown = true
		return
	if _sdk.has_method("showRewarded"):
		_sdk.call("showRewarded", rewarded_unit_id)
		_rewarded_shown = true
		return
	_complete_pending_rewarded(false)

func show_banner(placement: String) -> void:
	if _sdk == null:
		return
	var banner_unit_id := _banner_unit_id()
	if _sdk.has_method("show_banner_ad"):
		_sdk.call("show_banner_ad", banner_unit_id, placement)
		return
	if _sdk.has_method("show_banner"):
		_sdk.call("show_banner", banner_unit_id)
		return
	if _sdk.has_method("showBanner"):
		_sdk.call("showBanner", banner_unit_id)

func hide_banner() -> void:
	if _sdk == null:
		return
	if _sdk.has_method("hide_banner_ad"):
		_sdk.call("hide_banner_ad")
		return
	if _sdk.has_method("hide_banner"):
		_sdk.call("hide_banner")
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
		"GodotAdMob",
		"AdMob",
		"MobileAds",
		"GodotMobileAds",
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
	elif _sdk.has_method("initialize_ads"):
		_sdk.call("initialize_ads")
	_connect_if_signal_exists("rewarded_ad_loaded", _on_rewarded_loaded)
	_connect_if_signal_exists("rewarded_loaded", _on_rewarded_loaded)
	_connect_if_signal_exists("rewarded_ad_load_failed", _on_rewarded_failed)
	_connect_if_signal_exists("rewarded_load_failed", _on_rewarded_failed)
	_connect_if_signal_exists("rewarded_ad_failed_to_show", _on_rewarded_failed)
	_connect_if_signal_exists("rewarded_failed", _on_rewarded_failed)
	_connect_if_signal_exists("rewarded_earned", _on_reward_granted)
	_connect_if_signal_exists("rewarded_rewarded", _on_reward_granted)
	_connect_if_signal_exists("rewarded_ad_completed", _on_reward_granted)
	_connect_if_signal_exists("rewarded_closed", _on_rewarded_closed)
	_connect_if_signal_exists("rewarded_ad_closed", _on_rewarded_closed)

func _connect_if_signal_exists(signal_name: String, handler: Callable) -> void:
	ProviderSignalBridgeScript.connect_if_signal_exists(_sdk, signal_name, handler)

func _preload_rewarded() -> void:
	if _sdk == null:
		return
	var rewarded_unit_id := _rewarded_unit_id()
	if _sdk.has_method("load_rewarded_ad"):
		_sdk.call("load_rewarded_ad", rewarded_unit_id)
		return
	if _sdk.has_method("load_rewarded"):
		_sdk.call("load_rewarded", rewarded_unit_id)
		return
	if _sdk.has_method("loadRewarded"):
		_sdk.call("loadRewarded", rewarded_unit_id)

func _rewarded_unit_id() -> String:
	if _use_test_ids():
		return REWARDED_TEST_IOS if OS.has_feature("ios") else REWARDED_TEST_ANDROID
	if OS.has_feature("ios"):
		return _setting_string("ios_rewarded_unit_id", REWARDED_TEST_IOS)
	return _setting_string("android_rewarded_unit_id", REWARDED_TEST_ANDROID)

func _banner_unit_id() -> String:
	if _use_test_ids():
		return BANNER_TEST_IOS if OS.has_feature("ios") else BANNER_TEST_ANDROID
	if OS.has_feature("ios"):
		return _setting_string("ios_banner_unit_id", BANNER_TEST_IOS)
	return _setting_string("android_banner_unit_id", BANNER_TEST_ANDROID)

func _use_test_ids() -> bool:
	return _setting_bool("use_test_ids", true)

func _setting_string(key: String, default_value: String) -> String:
	return ProviderSettingsUtilScript.setting_string(SETTINGS_PREFIX, key, default_value)

func _setting_bool(key: String, default_value: bool) -> bool:
	return ProviderSettingsUtilScript.setting_bool(SETTINGS_PREFIX, key, default_value)

func _on_rewarded_loaded(_args: Variant = null) -> void:
	_rewarded_loaded = true

func _on_rewarded_failed(_args: Variant = null) -> void:
	_rewarded_loaded = false
	if _rewarded_shown:
		_complete_pending_rewarded(false)

func _on_reward_granted(_args: Variant = null) -> void:
	_reward_granted_this_show = true
	_complete_pending_rewarded(true)

func _on_rewarded_closed(_args: Variant = null) -> void:
	if not _reward_granted_this_show:
		_complete_pending_rewarded(false)
	_preload_rewarded()

func _complete_pending_rewarded(granted: bool) -> void:
	if _pending_rewarded_callback.is_valid():
		_pending_rewarded_callback.call(granted)
	_pending_rewarded_callback = Callable()
	_pending_rewarded_type = ""
	_rewarded_shown = false
	_reward_granted_this_show = false
