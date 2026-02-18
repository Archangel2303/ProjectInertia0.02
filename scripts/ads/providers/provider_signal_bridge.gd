extends RefCounted
class_name ProviderSignalBridge

static func connect_if_signal_exists(sdk: Object, signal_name: String, handler: Callable) -> void:
	if sdk == null:
		return
	if not sdk.has_signal(signal_name):
		return
	if sdk.is_connected(signal_name, handler):
		return
	sdk.connect(signal_name, handler)
