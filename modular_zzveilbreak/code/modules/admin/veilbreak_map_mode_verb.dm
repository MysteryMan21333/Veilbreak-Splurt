// VEILBREAK ADDITION - Admin verbs for the map mode system

ADMIN_VERB(veilbreak_map_mode, R_SERVER, "Set Map Mode", "Switch between STANDARD (Veilbreak maps only) and BROAD (all maps) map mode.", ADMIN_CATEGORY_SERVER)
	var/new_mode = tgui_alert(user.mob, "Current mode: [veilbreak_get_map_mode()].\nAllowed maps: [veilbreak_allowed_map_names_text()].\n\nChoose the new map mode.", "Set Map Mode", list(MAP_MODE_STANDARD, MAP_MODE_BROAD, "Cancel"))
	if(new_mode == "Cancel" || !new_mode)
		return
	veilbreak_set_map_mode(new_mode, user)
	BLACKBOX_LOG_ADMIN_VERB("Set Map Mode")

ADMIN_VERB(veilbreak_map_mode_stats, R_ADMIN, "Map Mode Statistics", "Open the map mode statistics panel.", ADMIN_CATEGORY_SERVER)
	get_veilbreak_map_mode_panel().ui_interact(user.mob)
	BLACKBOX_LOG_ADMIN_VERB("Map Mode Statistics")
