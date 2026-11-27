// Fair single-slot roles
//
// Prevents a single player from repeatedly holding a single-slot role (Heads, AI,
// and any other job with total_positions == 1) round after round at mid population.
//
// This is a SOFT deprioritization, not a hard block: the player who held the role
// last round has that role's preference tier demoted by one level (HIGH to MEDIUM to LOW).
// Other players therefore get first pick, but if nobody else wants the role the previous
// holder still gets it. Because we only ever lower a priority (and never mark a job
// unavailable), the player's Occupations If unavailable fallback is fully respected.

/// Previous round's single-slot holders, keyed by job title to ckey.
GLOBAL_LIST_EMPTY(fair_single_slot_last_holders)
/// This round's single-slot holders, keyed by job title to ckey. Populated by assign_role().
GLOBAL_LIST_EMPTY(current_round_fair_single_slot_holders)
/// True once last round's data has been loaded from disk.
GLOBAL_VAR_INIT(fair_single_slot_loaded, FALSE)
/// True once the round-end save callback has been registered.
GLOBAL_VAR_INIT(fair_single_slot_roundend_registered, FALSE)

#define FAIR_SINGLE_SLOT_SAVEFILE "data/fair_single_slot.json"

/datum/job
	/// If set, this single-slot job is excluded from the fair single-slot deprioritization.
	var/exempt_from_fair_single_slot = FALSE

/datum/job/proc/is_fair_single_slot()
	return total_positions == 1 && !exempt_from_fair_single_slot

/datum/config_entry/flag/fair_single_slot

/datum/config_entry/number/fair_single_slot_min_pop
	default = 8
	min_val = 0

/datum/config_entry/number/fair_single_slot_max_pop
	default = 12
	min_val = 0

/// Whether the fair single-slot deprioritization should be active for this round's population.
/datum/controller/subsystem/job/proc/is_fair_single_slot_restriction_active()
	if(!CONFIG_GET(flag/fair_single_slot))
		return FALSE
	var/min_pop = CONFIG_GET(number/fair_single_slot_min_pop)
	var/max_pop = CONFIG_GET(number/fair_single_slot_max_pop)
	return (initial_players_to_assign in min_pop to max_pop)

/// Returns the player's preference tier for a job, demoted one level if they held it last round.
/datum/controller/subsystem/job/proc/get_effective_job_priority(mob/dead/new_player/player, datum/job/job)
	if(!GLOB.fair_single_slot_loaded)
		GLOB.fair_single_slot_loaded = TRUE
		load_fair_single_slot_holders()

	var/client/player_client = player.client
	if(!player_client?.prefs)
		return null

	var/raw_priority = player_client.prefs.job_preferences[job.title]
	if(isnull(raw_priority))
		return null

	if(!job.is_fair_single_slot() || !is_fair_single_slot_restriction_active())
		return raw_priority

	if(GLOB.fair_single_slot_last_holders[job.title] != player.ckey)
		return raw_priority

	switch(raw_priority)
		if(JP_HIGH)
			return JP_MEDIUM
		if(JP_MEDIUM)
			return JP_LOW
	return raw_priority // JP_LOW (or JP_ANY) is already the lowest tier.

/// Called by assign_role() whenever a single-slot job is handed out.
/datum/controller/subsystem/job/proc/record_fair_single_slot_assignment(mob/dead/new_player/player, datum/job/job)
	if(!job.is_fair_single_slot())
		return
	GLOB.current_round_fair_single_slot_holders[job.title] = player.ckey
	register_fair_single_slot_roundend()

/datum/controller/subsystem/job/proc/register_fair_single_slot_roundend()
	if(GLOB.fair_single_slot_roundend_registered)
		return
	GLOB.fair_single_slot_roundend_registered = TRUE
	SSticker.OnRoundend(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(finish_fair_single_slot_round)))

/proc/load_fair_single_slot_holders()
	var/savefile = file(FAIR_SINGLE_SLOT_SAVEFILE)
	if(!fexists(savefile))
		return
	var/text = file2text(savefile)
	if(!length(text))
		return
	var/loaded = json_decode(text)
	if(islist(loaded))
		GLOB.fair_single_slot_last_holders = loaded

/proc/save_fair_single_slot_holders()
	WRITE_FILE(file(FAIR_SINGLE_SLOT_SAVEFILE), json_encode(GLOB.fair_single_slot_last_holders))

/proc/finish_fair_single_slot_round()
	GLOB.fair_single_slot_last_holders = GLOB.current_round_fair_single_slot_holders.Copy()
	save_fair_single_slot_holders()
	GLOB.current_round_fair_single_slot_holders.Cut()
	GLOB.fair_single_slot_roundend_registered = FALSE

#undef FAIR_SINGLE_SLOT_SAVEFILE