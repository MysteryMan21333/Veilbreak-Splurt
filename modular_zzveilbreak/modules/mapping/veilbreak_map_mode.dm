// VEILBREAK ADDITION - Map mode system
// Lets administrators switch the server between STANDARD (Veilbreak maps only) and
// BROAD (all maps) map rotation modes. The chosen mode persists across restarts.

/datum/config_entry/string/veilbreak_map_mode
	default = "STANDARD"

/// Current effective map mode. Resolved lazily from the persisted override file, then config.
var/global/veilbreak_map_mode = null

/// Persisted statistics: { "history": [...], "wins": { "STANDARD": {...}, "BROAD": {...} } }
var/global/list/veilbreak_map_mode_stats = null

/// Returns the current effective map mode (MAP_MODE_STANDARD or MAP_MODE_BROAD).
/proc/veilbreak_get_map_mode()
	if(!isnull(veilbreak_map_mode))
		return veilbreak_map_mode

	if(fexists(VEILBREAK_MAP_MODE_FILE))
		var/overridden = trim(file2text(VEILBREAK_MAP_MODE_FILE))
		if(overridden == MAP_MODE_STANDARD || overridden == MAP_MODE_BROAD)
			veilbreak_map_mode = overridden
			return veilbreak_map_mode

	var/config_mode = MAP_MODE_STANDARD
	if(config)
		config_mode = uppertext(trim(CONFIG_GET(string/veilbreak_map_mode)))
	if(config_mode == MAP_MODE_BROAD)
		veilbreak_map_mode = MAP_MODE_BROAD
	else
		veilbreak_map_mode = MAP_MODE_STANDARD
	return veilbreak_map_mode

/// Loads (or initializes) the persisted map mode statistics.
/proc/veilbreak_load_map_mode_stats()
	if(!isnull(veilbreak_map_mode_stats))
		return veilbreak_map_mode_stats
	if(fexists(VEILBREAK_MAP_MODE_STATS_FILE))
		var/raw = file2text(VEILBREAK_MAP_MODE_STATS_FILE)
		if(raw)
			var/parsed = json_decode(raw)
			if(islist(parsed))
				veilbreak_map_mode_stats = parsed
				if(!islist(veilbreak_map_mode_stats["history"]))
					veilbreak_map_mode_stats["history"] = list()
				if(!islist(veilbreak_map_mode_stats["wins"]))
					veilbreak_map_mode_stats["wins"] = list()
				return veilbreak_map_mode_stats
	veilbreak_map_mode_stats = list("history" = list(), "wins" = list())
	return veilbreak_map_mode_stats

/// Writes the map mode statistics to disk.
/proc/veilbreak_save_map_mode_stats()
	if(isnull(veilbreak_map_mode_stats))
		return
	rustg_file_write(json_encode(veilbreak_map_mode_stats), VEILBREAK_MAP_MODE_STATS_FILE)

/// Returns the switch history list.
/proc/veilbreak_get_map_mode_history()
	var/list/stats = veilbreak_load_map_mode_stats()
	return stats["history"]

/// Returns the per-mode win counts: wins[mode][map_name] = count.
/proc/veilbreak_get_map_mode_wins()
	var/list/stats = veilbreak_load_map_mode_stats()
	return stats["wins"]

/// Records a map vote win under the given mode.
/proc/veilbreak_record_map_win(map_name, mode)
	var/list/wins = veilbreak_get_map_mode_wins()
	var/list/mode_wins = wins[mode]
	if(!islist(mode_wins))
		mode_wins = list()
		wins[mode] = mode_wins
	mode_wins[map_name] = (mode_wins[map_name] || 0) + 1
	veilbreak_save_map_mode_stats()

/// Normalizes and validates a mode string. Returns the canonical mode or null if invalid.
/proc/veilbreak_normalize_map_mode(mode)
	mode = uppertext(trim(mode))
	if(mode == MAP_MODE_STANDARD || mode == MAP_MODE_BROAD)
		return mode
	return null

/// Returns TRUE if the given map config is allowed under the current mode.
/proc/veilbreak_map_allowed(datum/map_config/map)
	if(veilbreak_get_map_mode() == MAP_MODE_STANDARD)
		return map.map_origin == MAP_ORIGIN_VEILBREAK
	return TRUE

/// Returns a list of map names allowed under the current mode.
/proc/veilbreak_allowed_map_names()
	var/list/names = list()
	if(!config?.maplist)
		return names
	for(var/map_id in config.maplist)
		var/datum/map_config/map = config.maplist[map_id]
		if(!veilbreak_map_allowed(map))
			continue
		names += map.map_name
	return names

/// Human readable list of allowed map names.
/proc/veilbreak_allowed_map_names_text()
	var/list/names = veilbreak_allowed_map_names()
	return length(names) ? jointext(names, ", ") : "None"

/// Broadcasts a chat notice describing the current mode and allowed maps.
/proc/veilbreak_announce_map_mode()
	var/mode = veilbreak_get_map_mode()
	var/desc = "Map mode is [mode]. "
	if(mode == MAP_MODE_STANDARD)
		desc += "Only Veilbreak maps are selectable."
	else
		desc += "All maps are selectable."
	desc += " Allowed maps: [veilbreak_allowed_map_names_text()]."
	to_chat(world, span_purple(boxed_message("Map Mode<br><hr>[desc]")))

/// Removes tallies for maps that are no longer allowed under the current mode.
/proc/veilbreak_sanitize_map_vote_cache()
	if(!SSmap_vote?.map_vote_cache)
		return
	for(var/map_id in SSmap_vote.map_vote_cache)
		var/datum/map_config/map = config?.maplist ? config.maplist[map_id] : null
		if(!map || !veilbreak_map_allowed(map))
			SSmap_vote.map_vote_cache -= map_id
	SSmap_vote.write_cache()
	SSmap_vote.update_tally_printout()

/// Sets the map mode, persists it, announces it, and refreshes the map vote cache.
/proc/veilbreak_set_map_mode(new_mode, client/admin)
	var/normalized = veilbreak_normalize_map_mode(new_mode)
	if(!normalized)
		return FALSE

	var/old_mode = veilbreak_get_map_mode()
	if(normalized == old_mode)
		if(admin?.mob)
			to_chat(admin.mob, span_warning("Map mode is already [old_mode]."))
		return FALSE

	veilbreak_map_mode = normalized
	rustg_file_write(normalized, VEILBREAK_MAP_MODE_FILE)

	var/list/history = veilbreak_get_map_mode_history()
	history += list(list(
		"time" = time2text(world.timeofday),
		"ckey" = admin ? admin.key : "SERVER",
		"old_mode" = old_mode,
		"new_mode" = normalized,
	))
	veilbreak_save_map_mode_stats()

	// Refresh the cached vote choices so excluded maps drop out immediately.
	SSmap_vote.player_cache = -1
	SSmap_vote.votable_map_cache = null
	veilbreak_sanitize_map_vote_cache()

	veilbreak_announce_map_mode()
	var/actor = admin ? admin.key : "SERVER"
	message_admins("[actor] set the map mode to [normalized] (was [old_mode]).")
	log_admin("[actor] set the map mode to [normalized] (was [old_mode]).")
	return TRUE

/// Builds the full statistics payload for the TGUI panel.
/proc/veilbreak_build_map_mode_stats_data()
	var/list/data = list()
	data["mode"] = veilbreak_get_map_mode()
	data["persisted_override"] = fexists(VEILBREAK_MAP_MODE_FILE) ? trim(file2text(VEILBREAK_MAP_MODE_FILE)) : null
	data["config_default"] = config ? CONFIG_GET(string/veilbreak_map_mode) : MAP_MODE_STANDARD
	data["allowed_maps"] = veilbreak_allowed_map_names()

	var/list/maps = list()
	if(config?.maplist)
		for(var/map_id in config.maplist)
			var/datum/map_config/map = config.maplist[map_id]
			var/tally = 0
			if(SSmap_vote?.map_vote_cache)
				tally = SSmap_vote.map_vote_cache[map_id] || 0
			maps += list(list(
				"name" = map.map_name,
				"origin" = map.map_origin,
				"votable" = map.votable,
				"min" = map.config_min_users,
				"max" = map.config_max_users,
				"weight" = map.voteweight,
				"tally" = tally,
				"allowed" = veilbreak_map_allowed(map),
			))
	data["maps"] = maps
	data["wins"] = veilbreak_get_map_mode_wins()
	data["history"] = veilbreak_get_map_mode_history()
	data["json_export"] = json_encode(veilbreak_load_map_mode_stats())
	data["csv_export"] = veilbreak_build_csv_export()
	return data

/// Builds a CSV export of the per-mode win statistics.
/proc/veilbreak_build_csv_export()
	var/list/rows = list("mode,map,wins")
	var/list/wins = veilbreak_get_map_mode_wins()
	for(var/mode in wins)
		var/list/mode_wins = wins[mode]
		for(var/map_name in mode_wins)
			rows += "[mode],[map_name],[mode_wins[map_name]]"
	return jointext(rows, "\n")

/// Override of the map vote choice builder to enforce the current mode.
/datum/controller/subsystem/map_vote/get_valid_map_vote_choices()
	var/filter_threshold = 0
	if(SSticker.HasRoundStarted())
		filter_threshold = get_active_player_count(alive_check = FALSE, afk_check = TRUE, human_check = FALSE)
	else
		filter_threshold = length(GLOB.clients)

	// Cached because it's called off ui_data, I really don't think this is worth it but whatever
	if(filter_threshold == player_cache && !isnull(votable_map_cache))
		return votable_map_cache.Copy()

	player_cache = filter_threshold
	var/list/pop_valid_maps = list()
	// Fill in our default choices with all of the maps in our map config, if they are votable and not blocked.
	var/list/maps = shuffle(global.config.maplist)
	for(var/map in maps)
		var/datum/map_config/possible_config = config.maplist[map]
		if(!possible_config.votable)
			continue
		if(!veilbreak_map_allowed(possible_config)) // VEILBREAK ADDITION
			continue
		if(possible_config.config_min_users > 0 && filter_threshold < possible_config.config_min_users)
			continue
		if(possible_config.config_max_users > 0 && filter_threshold > possible_config.config_max_users)
			continue
		pop_valid_maps += possible_config.map_name

	// Remove stale (played twice in the past KEEP_ROUNDS_MAP + 1 rounds (including this one as the + 1)) maps
	var/list/freshened_valid_maps = list()
	for(var/map_name in pop_valid_maps)
		if(map_name in SSpersistence.blocked_maps)
			continue
		freshened_valid_maps += map_name

	// We might stale out all valid maps, in that case just ignore the stale system
	if(!length(freshened_valid_maps))
		votable_map_cache = pop_valid_maps.Copy()
		return pop_valid_maps

	votable_map_cache = freshened_valid_maps.Copy()
	return freshened_valid_maps

/// Override to record map vote wins (per-mode) when a winner is finalized.
/datum/controller/subsystem/map_vote/finalize_map_vote(datum/vote/map_vote/map_vote)
	if(already_voted)
		message_admins("Attempted to finalize a map vote after a map vote has already been finalized.")
		return
	already_voted = TRUE

	var/flat = CONFIG_GET(number/map_vote_flat_bonus)
	previous_cache = map_vote_cache.Copy()
	for(var/map_id in map_vote.choices)
		var/datum/map_config/map = config.maplist[map_id]
		map_vote_cache[map_id] += (map_vote.choices[map_id] * map.voteweight) + flat
	sanitize_cache()
	write_cache()
	update_tally_printout()

	if(admin_override)
		send_map_vote_notice("Admin Override is in effect. Map will not be changed.", "Tallies are recorded and saved.")
		return

	var/winner
	var/winner_amount = 0
	for(var/map in map_vote.choices)
		if(!winner_amount)
			winner = map
			winner_amount = map_vote_cache[map]
			continue
		if(map_vote_cache[map] <= winner_amount)
			continue
		winner = map
		winner_amount = map_vote_cache[map]

	ASSERT(winner, "No winner found in map vote.")
	set_next_map(config.maplist[winner])
	veilbreak_record_map_win(winner, veilbreak_get_map_mode()) // VEILBREAK ADDITION
	var/list/messages = list("Map Selected - [span_bold(next_map_config.map_name)]")
	messages += "Tallies at the time of selection:"
	messages += tally_printout

	// do not reset tallies if only one map is even possible
	if(length(map_vote.choices) > 1)
		map_vote_cache[winner] = CONFIG_GET(number/map_vote_minimum_tallies)
		write_cache()
		update_tally_printout()
	else
		messages += "Only one map was possible, tallies were not reset."

	send_map_vote_notice(arglist(messages))

/// Shows the current map mode once to a player loading into the lobby.
/proc/veilbreak_show_lobby_map_status(mob/dead/new_player/viewer)
	var/mode = veilbreak_get_map_mode()
	var/desc = "Current map mode is [mode]. Allowed maps: [veilbreak_allowed_map_names_text()]."
	to_chat(viewer, span_purple(boxed_message("Map Mode<br><hr>[desc]")))

/mob/dead/new_player/Initialize(mapload)
	if(client && SSticker.state == GAME_STATE_STARTUP)
		var/atom/movable/screen/splash/fade_out = new(null, null, client, TRUE)
		fade_out.fade(TRUE)

	if(length(GLOB.newplayer_start))
		forceMove(pick(GLOB.newplayer_start))
	else
		forceMove(locate(1,1,1))

	. = ..()

	GLOB.new_player_list += src
	ASSIGN_GAME_VERB(src, /mob/dead/new_player, reset_menu_hud)

	// VEILBREAK ADDITION - Show the current map mode once when loading into the lobby.
	veilbreak_show_lobby_map_status(src)

