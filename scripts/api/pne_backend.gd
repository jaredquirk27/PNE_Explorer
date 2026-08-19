extends RefCounted

class_name PNEBackend

const DEFAULT_BASE_URL := "http://127.0.0.1:8000"


static func base_url() -> String:
	var configured: Variant = ProjectSettings.get_setting("application/config/pne_api_base_url", "")
	var base: String = str(configured).strip_edges()
	if base.is_empty():
		var env_base: String = OS.get_environment("PNE_API_BASE_URL").strip_edges()
		base = env_base if not env_base.is_empty() else DEFAULT_BASE_URL
	return base.trim_suffix("/")


static func chat_url() -> String:
	return "%s/chat" % base_url()


static func campaign_action_url() -> String:
	return "%s/campaign/action" % base_url()


static func realms_onboarding_url() -> String:
	return "%s/campaign/realms/active/onboarding" % base_url()


static func realms_onboarding_turn_url() -> String:
	return "%s/campaign/realms/active/onboarding/turn" % base_url()
