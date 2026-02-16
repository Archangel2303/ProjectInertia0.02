extends Node

signal rewarded_ad_completed(ad_type: String, granted: bool)
signal provider_initialized(provider_name: String)

const MockAdProvider = preload("res://scripts/ads/providers/mock_ad_provider.gd")
const MobileAdProvider = preload("res://scripts/ads/providers/mobile_ad_provider.gd")
const SteamAdProvider = preload("res://scripts/ads/providers/steam_ad_provider.gd")

var _provider: Object

func _ready() -> void:
	_provider = _create_default_provider()
	provider_initialized.emit(_provider.provider_name())

func configure_provider(provider: Object) -> void:
	if provider == null:
		return
	_provider = provider
	provider_initialized.emit(_provider.provider_name())

func show_rewarded_ad(ad_type: String) -> void:
	if _provider == null:
		_provider = _create_default_provider()
	_provider.show_rewarded_ad(ad_type, func(granted: bool) -> void:
		rewarded_ad_completed.emit(ad_type, granted)
	)

func can_show_rewarded_ad(ad_type: String) -> bool:
	if _provider == null:
		_provider = _create_default_provider()
	return _provider.is_rewarded_available(ad_type)

func show_banner_ad(placement: String = "menu_bottom") -> void:
	if _provider == null:
		_provider = _create_default_provider()
	_provider.show_banner(placement)

func hide_banner_ad() -> void:
	if _provider == null:
		return
	_provider.hide_banner()

func active_provider_name() -> String:
	if _provider == null:
		_provider = _create_default_provider()
	return _provider.provider_name()

func _create_default_provider() -> Object:
	if OS.has_feature("mobile"):
		return MobileAdProvider.new()
	if OS.has_feature("pc"):
		return SteamAdProvider.new()
	return MockAdProvider.new()
