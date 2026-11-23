/obj/item/sensor_device
	name = "handheld crew monitor" //Thanks to Gun Hog for the name!
	desc = "A miniature machine that tracks suit sensors across the station."
	icon = 'icons/obj/devices/scanner.dmi'
	icon_state = "crew_monitor"
	inhand_icon_state = "electronic"
	worn_icon_state = "electronic"
	lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_BELT
	custom_price = PAYCHECK_CREW * 5
	custom_premium_price = PAYCHECK_CREW * 6
	sound_vary = TRUE
	pickup_sound = SFX_GENERIC_DEVICE_PICKUP
	drop_sound = SFX_GENERIC_DEVICE_DROP
	/// Whether the death alarm beep is muted.
	var/muted = FALSE
	/// Timer handle for the death alarm loop.
	var/alarm_timer
	COOLDOWN_DECLARE(alarm_cooldown)

/obj/item/sensor_device/attack_self(mob/user)
	GLOB.crewmonitor.show(user,src) //Proc already exists, just had to call it

/obj/item/sensor_device/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/drag_to_activate)
	alarm_timer = addtimer(CALLBACK(src, PROC_REF(alarm)), 5 SECONDS)

/obj/item/sensor_device/Destroy()
	if(alarm_timer)
		deltimer(alarm_timer)
	return ..()

/// Beeps while a Nanotrasen-aligned crew member is critically injured or dead.
/obj/item/sensor_device/proc/alarm()
	alarm_timer = addtimer(CALLBACK(src, PROC_REF(alarm)), 5 SECONDS)

	if(muted)
		return

	for(var/mob/living/carbon/human/mob in GLOB.suit_sensors_list)
		if(!istype(mob))
			GLOB.suit_sensors_list -= mob
			continue

		if(!is_nanotrasen_employee(mob))
			continue

		var/obj/item/clothing/under/uniform = mob.w_uniform
		if(!istype(uniform) || uniform.has_sensor <= NO_SENSORS || !uniform.sensor_mode)
			GLOB.suit_sensors_list -= mob
			continue

		if(uniform.sensor_mode == SENSOR_COORDS && (uniform.has_sensor != BROKEN_SENSORS) && IS_CRITICAL(mob) || mob.stat == DEAD || isprotean(mob))
			if(mob.get_dnr())
				continue
			if(isprotean(mob))
				var/obj/item/organ/brain/protean/protean_brain = mob.get_organ_slot(ORGAN_SLOT_BRAIN)
				if(!protean_brain?.dead)
					continue
			if(COOLDOWN_FINISHED(src, alarm_cooldown))
				playsound(src, 'sound/machines/beep/twobeep.ogg', 50, FALSE)
				COOLDOWN_START(src, alarm_cooldown, 5 SECONDS)
			break

/obj/item/sensor_device/verb/toggle_alarm_sound()
	set name = "Toggle Alarm Sound"
	set category = "Object"
	muted = !muted
	to_chat(usr, span_notice("The alarm sound is now [muted ? "muted" : "on"]."))
