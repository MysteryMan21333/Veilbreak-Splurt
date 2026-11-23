// This patch expands medical monitoring globally across all non-contiguous Z-levels for offstation operations.
// It enforces absolute privacy boundaries via strict faction isolation verification loops across consoles.

/obj/machinery/computer/crew/tarkon
	name = "Tarkon Crew Monitoring Console"
	desc = "Used to monitor active health sensors built into Tarkon military uniforms."
	icon_state = "crew_tarkon"

/obj/machinery/computer/crew/admin
	name = "Master Crew Monitoring Console"
	desc = "An unrestricted, high-clearance terminal that aggregates all medical sensor signatures across all networks."
	icon_state = "crew_admin"

/// Syndicate Persistence (landcrawler) crew monitor. Sees everyone sharing the Syndicate faction or the Persistence ghost role.
/obj/machinery/computer/crew/syndie/persistence
	name = "Persistence Crew Monitoring Console"
	desc = "Used to monitor active health sensors of Syndicate operatives and Persistence crew."

/// Faction tags that mark someone as syndicate-aligned (open antagonist roles and
/// syndicate ghost roles alike).
GLOBAL_LIST_INIT(syndicate_factions, list(
	ROLE_SYNDICATE,
	"syndicate", // legacy lowercase tag used by some spawners
	ROLE_PERSISTENCE,
	ROLE_SYNDICATE_INFILTRATOR,
	ROLE_LONE_OPERATIVE,
	ROLE_OPERATIVE,
	ROLE_SYNDICATE_BOARDER,
	ROLE_DS2,
	ROLE_DAUNTLESS,
	ROLE_SYNDICATE_CYBERSUN,
	ROLE_SYNDICATE_CYBERSUN_CAPTAIN,
	ROLE_SPACE_SYNDICATE,
	ROLE_LAVALAND_SYNDICATE,
	ROLE_SYNDICATE_DRONE,
	ROLE_SYNDICATE_MONKEY,
	ROLE_SYNDICATE_SABOBORG,
	ROLE_SYNDICATE_MEDBORG,
	ROLE_SYNDICATE_ASSAULTBORG,
))

/// Nanotrasen employees hold a Station-faction job (includes silicons and undercover
/// station antagonists, who keep their cover job). ERT and Nanotrasen private security
/// are special-cased because they don't hold a normal Station job but are still NT.
/proc/is_nanotrasen_employee(mob/living/M)
	if(M.mind?.assigned_role?.faction == FACTION_STATION)
		return TRUE
	if(M.faction && ((FACTION_ERT in M.faction) || (FACTION_NANOTRASEN_PRIVATE in M.faction)))
		return TRUE
	// Secondary filter: an infiltrator card presenting its cover identity reads
	// as Nanotrasen, so an undercover operative shows on the NT crew monitor.
	var/obj/item/card/id/id_card = M.get_idcard()
	if(istype(id_card, /obj/item/card/id/advanced/chameleon/infiltrator))
		var/obj/item/card/id/advanced/chameleon/infiltrator/infiltrator_card = id_card
		if(infiltrator_card.is_cover_identity())
			return TRUE
	return FALSE

/// Syndicate-aligned: open syndicate antagonist roles and syndicate ghost roles.
/proc/is_syndicate(mob/living/M)
	if(M.faction)
		for(var/syndicate_faction in GLOB.syndicate_factions)
			if(syndicate_faction in M.faction)
				return TRUE
	return FALSE

/// Tarkon-affiliated workers (Port Tarkon survivors and Tarkon Industries crew).
/proc/is_tarkon_crew(mob/living/M)
	if(M.faction && ((FACTION_TARKON in M.faction) || (ROLE_PORT_TARKON in M.faction)))
		return TRUE
	return FALSE

/obj/machinery/computer/crew/proc/is_faction_authorized(mob/living/M)
	if(!istype(M))
		return FALSE

	switch(get_console_faction())
		if("admin")
			return TRUE
		if("tarkon")
			return is_tarkon_crew(M)
		if("syndicate")
			return is_syndicate(M)
		if("nanotrasen")
			return is_nanotrasen_employee(M)

	return FALSE

/// Returns a masked display name for syndicate operatives when viewed from a syndicate
/// console, so the monitor never leaks their real identity. Returns null otherwise.
/obj/machinery/computer/crew/proc/get_display_name(mob/living/M)
	if(get_console_faction() != "syndicate" || !is_syndicate(M))
		return null
	if(M.mind)
		return M.mind.give_syndicate_codename(silent = TRUE)
	return get_syndicate_codename(M)

/// Deterministic anonymous fallback for mindless syndicates.
/obj/machinery/computer/crew/proc/get_syndicate_codename(mob/living/M)
	var/static/list/syndicate_codenames = list(
		"Viper", "Wraith", "Cobra", "Phantom", "Raven", "Onyx", "Specter",
		"Havoc", "Nomad", "Rogue", "Ghost", "Falcon", "Jackal", "Widow",
		"Basilisk", "Revenant", "Umbra", "Zephyr", "Kraken", "Mirage",
	)
	var/codename_hash = 0
	var/ref_text = REF(M)
	for(var/index in 1 to length(ref_text))
		codename_hash += text2ascii(copytext(ref_text, index, index + 1))
	return "[syndicate_codenames[(codename_hash % length(syndicate_codenames)) + 1]]-[codename_hash % 100]"

/obj/machinery/computer/crew/proc/get_console_faction()
	if(src.type == /obj/machinery/computer/crew/tarkon || initial(src.icon_state) == "crew_tarkon")
		return "tarkon"
	if(src.type == /obj/machinery/computer/crew/admin || initial(src.icon_state) == "crew_admin")
		return "admin"
	if(istype(src, /obj/machinery/computer/crew/syndie))
		return "syndicate"
	// Consoles already mapped (or rebuilt) inside the Persistence landcrawler act as Syndicate consoles.
	if(istype(get_area(src), /area/ruin/space/has_grav/bubbers/persistance))
		return "syndicate"
	return "nanotrasen"
