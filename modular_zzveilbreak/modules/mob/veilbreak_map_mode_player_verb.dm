// VEILBREAK ADDITION - Player-facing read-only map mode verb

/mob/verb/veilbreak_map_mode_status()
	set name = "Veilbreak Map Mode"
	set category = "OOC.Info.Veilbreak"
	set desc = "Shows the current map mode and which maps can be chosen."

	var/mode = veilbreak_get_map_mode()
	var/desc = "Current map mode is [mode]. Allowed maps: [veilbreak_allowed_map_names_text()]."
	to_chat(src, span_purple(boxed_message("Map Mode<br><hr>[desc]")))
