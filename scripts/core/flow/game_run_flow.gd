extends RefCounted
class_name GameRunFlow

static func current_level_id(mode: int, endless_mode_value: int, level_index: int) -> String:
	return "endless" if mode == endless_mode_value else "level_%d" % level_index

static func can_request_end_bonus(run_ended: bool, end_bonus_claimed: bool, request_in_progress: bool) -> bool:
	return run_ended and not end_bonus_claimed and not request_in_progress

static func end_bonus_button_state_for_availability(can_show_ad: bool) -> Dictionary:
	return {
		"enabled": can_show_ad,
		"text": "Watch Ad: +25% Reward" if can_show_ad else "Ad Unavailable",
	}

static func end_bonus_loading_state() -> Dictionary:
	return {
		"enabled": false,
		"text": "Loading Ad...",
	}

static func end_bonus_claimed_state() -> Dictionary:
	return {
		"enabled": false,
		"text": "Reward Claimed",
	}

static func should_offer_extra_bullet(has_ammo: bool) -> bool:
	return not has_ammo

static func can_use_extra_bullet_ad(session_can_use: bool, ad_can_show: bool) -> bool:
	return session_can_use and ad_can_show

static func apply_end_bonus(score: int, bonus_ratio: float = 0.25) -> int:
	return score + int(round(score * bonus_ratio))
