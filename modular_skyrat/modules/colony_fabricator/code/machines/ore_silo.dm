/obj/machinery/ore_silo/colony_lathe
	name = "colony ore silo"
	desc = "An all-in-one materials management solution. Connects resource-using machines \
		through a network of distribution systems."
	icon = 'modular_skyrat/modules/colony_fabricator/icons/ore_silo.dmi'
	circuit = null
	/// What this packs into
	var/packed_type = /obj/item/flatpacked_machine/ore_silo
	/// Whether the silo beeps when it logs a material action
	var/beeps = TRUE

/obj/machinery/ore_silo/colony_lathe/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/repackable, packed_type, 10 SECONDS)

/obj/machinery/ore_silo/colony_lathe/silo_log(obj/machinery/machinery_in_question, action, amount, noun, list/mats)
	. = ..()
	if(beeps)
		playsound(src, 'sound/machines/beep/beep.ogg', 30, TRUE)


// Veilbreak Edit Start
/obj/machinery/ore_silo/colony_lathe/ui_data(mob/user)
	var/list/data = ..()
	data["beeps"] = beeps
	return data

/obj/machinery/ore_silo/colony_lathe/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(action == "toggle_beep")
		beeps = !beeps
		var/beep_status = beeps ? "enable" : "disable"
		to_chat(ui.user, span_notice("You [beep_status] [src]'s beeping."))
		return TRUE
// Veilbreak Edit End

/obj/machinery/ore_silo/colony_lathe/default_deconstruction_crowbar()
	return

// Item for deploying ore silos
/obj/item/flatpacked_machine/ore_silo
	name = "flat-packed ore silo"
	icon = 'modular_skyrat/modules/colony_fabricator/icons/ore_silo.dmi'
	icon_state = "ore_silo"
	type_to_deploy = /obj/machinery/ore_silo/colony_lathe
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 5,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT * 5,
	)
