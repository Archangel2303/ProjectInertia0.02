extends RefCounted
class_name HudTexts

static func score_text(score: int) -> String:
	return "Score: %d" % score

static func ammo_text(current: int, max_ammo: int) -> String:
	return "Ammo: %d/%d" % [current, max_ammo]

static func extra_bullet_button_text(enabled: bool) -> String:
	return "Watch Ad" if enabled else "Ad Unavailable"

static func end_title_text(cleared: bool) -> String:
	return "Level Cleared" if cleared else "Run Ended"

static func high_score_text(high_score: int, is_new_high: bool) -> String:
	return "Best: %d%s" % [high_score, " (NEW)" if is_new_high else ""]

static func ad_debug_text(provider_name: String, can_extra_bullet: bool, can_end_bonus: bool) -> String:
	return "Ad: %s\nExtra: %s\nEnd: %s" % [
		provider_name,
		"YES" if can_extra_bullet else "NO",
		"YES" if can_end_bonus else "NO",
	]
