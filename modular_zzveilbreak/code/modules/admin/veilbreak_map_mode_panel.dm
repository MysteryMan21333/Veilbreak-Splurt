// VEILBREAK ADDITION - TGUI panel for map mode statistics

var/global/datum/veilbreak_map_mode_panel/veilbreak_map_mode_panel_instance

/// Returns the shared map mode statistics panel instance.
/proc/get_veilbreak_map_mode_panel()
	if(!veilbreak_map_mode_panel_instance)
		veilbreak_map_mode_panel_instance = new /datum/veilbreak_map_mode_panel()
	return veilbreak_map_mode_panel_instance

/datum/veilbreak_map_mode_panel

/datum/veilbreak_map_mode_panel/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "VeilbreakMapMode")
		ui.open()

/datum/veilbreak_map_mode_panel/ui_state(mob/user)
	return ADMIN_STATE(R_ADMIN)

/datum/veilbreak_map_mode_panel/ui_data(mob/user)
	return veilbreak_build_map_mode_stats_data()

/datum/veilbreak_map_mode_panel/ui_act(action, params, datum/tgui/ui)
	if(..() || !check_rights_for(ui.user.client, R_ADMIN))
		return FALSE

	switch(action)
		if("flip_mode")
			if(!check_rights_for(ui.user.client, R_SERVER))
				return TRUE
			veilbreak_set_map_mode(params["mode"], ui.user.client)
			return TRUE
		if("export_file")
			var/format = params["format"]
			if(format == "csv")
				rustg_file_write(veilbreak_build_csv_export(), "data/veilbreak_map_mode_export.csv")
				return TRUE
			if(format == "json")
				rustg_file_write(json_encode(veilbreak_load_map_mode_stats()), "data/veilbreak_map_mode_export.json")
				return TRUE
		if("refresh")
			return TRUE

	return FALSE
