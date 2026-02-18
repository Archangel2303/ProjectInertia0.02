extends RefCounted
class_name ProviderSettingsUtil

# Reads provider config from ProjectSettings using a prefix per platform/provider.
# This removes duplicated settings boilerplate across ad provider implementations.
static func setting_string(prefix: String, key: String, default_value: String) -> String:
	var full_key := "%s%s" % [prefix, key]
	if not ProjectSettings.has_setting(full_key):
		return default_value
	return str(ProjectSettings.get_setting(full_key))

static func setting_bool(prefix: String, key: String, default_value: bool) -> bool:
	var full_key := "%s%s" % [prefix, key]
	if not ProjectSettings.has_setting(full_key):
		return default_value
	return bool(ProjectSettings.get_setting(full_key))
