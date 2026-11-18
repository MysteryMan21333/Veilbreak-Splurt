/datum/quirk/social_anxiety
	name = "Social Anxiety"
	desc = "Talking to people is very difficult for you, and you often stutter or even lock up. Taking psicodine helps calm your nerves, and you start with a bottle of it."
	icon = FA_ICON_COMMENT_SLASH
	value = -3
	gain_text = span_danger("You start worrying about what you're saying.")
	lose_text = span_notice("You feel easier about talking again.") //if only it were that easy!
	medical_record_text = "Patient is usually anxious in social encounters and prefers to avoid them."
	medical_symptom_text = "Experiences intense anxiety and discomfort in social situations, \
		leading to avoidance of social interactions and difficulty in communication."
	hardcore_value = 4
	mob_trait = TRAIT_ANXIOUS
	mail_goodies = list(/obj/item/storage/pill_bottle/psicodine/anxiety) // Veilbreak Edit - proper dosage refill
	quirk_flags = QUIRK_HUMAN_ONLY|QUIRK_TRAUMALIKE
	var/dumb_thing = TRUE
	/// The last time we were alone. Being alone for a while helps calm us down. (Veilbreak Edit)
	var/last_alone_time = 0

/datum/quirk/social_anxiety/add(client/client_source)
	RegisterSignal(quirk_holder, COMSIG_MOB_EYECONTACT, PROC_REF(eye_contact))
	RegisterSignal(quirk_holder, COMSIG_MOB_EXAMINATE, PROC_REF(looks_at_floor))
	RegisterSignal(quirk_holder, COMSIG_MOB_SAY, PROC_REF(handle_speech))
	RegisterSignal(quirk_holder, COMSIG_MOVABLE_HEAR, PROC_REF(on_hear_whisper)) // Veilbreak Edit
	quirk_holder.apply_status_effect(/datum/status_effect/speech/stutter/anxiety, INFINITY)
	// Veilbreak Edit Start - spawn with a bottle of psicodine to help mitigate the trait
	var/obj/item/storage/pill_bottle/psicodine/anxiety/bottle = new(get_turf(quirk_holder))
	quirk_holder.put_in_hands(bottle)
	// Veilbreak Edit End

/datum/quirk/social_anxiety/remove()
	UnregisterSignal(quirk_holder, list(COMSIG_MOB_EYECONTACT, COMSIG_MOB_EXAMINATE, COMSIG_MOB_SAY, COMSIG_MOVABLE_HEAR)) // Veilbreak Edit
	quirk_holder.remove_status_effect(/datum/status_effect/speech/stutter/anxiety)

/// Calculates how much to modifiy our effects based on our mood level
/datum/quirk/social_anxiety/proc/calculate_mood_mod()
	var/nearby_people = 0
	for(var/mob/living/carbon/human/listener in oview(2, quirk_holder))
		if(listener.client || listener.mind)
			nearby_people++

	// Veilbreak Edit Start - non-linear crowd scaling, so a person or two is manageable
	var/crowd_mod
	switch(nearby_people)
		if(0)
			crowd_mod = 0
		if(1)
			crowd_mod = 0.4
		if(2)
			crowd_mod = 0.8
		if(3)
			crowd_mod = 1.2
		else
			crowd_mod = 1.6 + (nearby_people - 4) * 0.2

	// Recently having some alone time helps calm us down.
	if(nearby_people == 0)
		last_alone_time = world.time
	else if(last_alone_time && world.time - last_alone_time < 30 SECONDS)
		crowd_mod *= 0.5
	// Veilbreak Edit End

	var/mod = 1
	if(quirk_holder.mob_mood)
		mod = 1 + 0.02 * (50 - (max(50, quirk_holder.mob_mood.mood_level * (SANITY_LEVEL_MAX + 1 - quirk_holder.mob_mood.sanity_level)))) //low sanity levels are better, they max at 6
	else
		mod = 1 + 0.02 * (50 - (max(50, 0.1 * quirk_holder.nutrition)))

	return mod * crowd_mod * 12.5

/datum/quirk/social_anxiety/proc/handle_speech(datum/source, list/speech_args)
	SIGNAL_HANDLER

	if(HAS_TRAIT(quirk_holder, TRAIT_FEARLESS))
		return
	if(HAS_TRAIT(source, TRAIT_SIGN_LANG)) // No modifiers for signers, so you're less anxious when you go non-verbal
		return

	var/list/message_mods = speech_args[SPEECH_MODS]
	// Veilbreak Edit Start - radio/announcement speech isn't "talking to a crowd"
	if(message_mods && message_mods[RADIO_EXTENSION])
		return
	// Veilbreak Edit End

	// Whispering is much easier than addressing the room.
	var/is_whisper = (message_mods && message_mods[WHISPER_MODE] == MODE_WHISPER)

	var/moodmod = calculate_mood_mod()
	if(is_whisper)
		moodmod *= 0.25

	var/message = speech_args[SPEECH_MESSAGE]
	if(message)
		var/list/message_split = splittext(message, " ")
		var/list/new_message = list()
		for(var/word in message_split)
			if(prob(max(5, moodmod)) && word != message_split[1]) //Minimum 1/20 chance of filler
				new_message += pick("uh,","erm,","um,")
				if(prob(min(3, moodmod * 0.2))) //Veilbreak Edit - much rarer cutoff after a filler
					quirk_holder.set_silence_if_lower(4 SECONDS)
					to_chat(quirk_holder, span_danger("You feel self-conscious and stop talking. You need a moment to recover!"))
					break
			new_message += word

		message = jointext(new_message, " ")

	if(prob(min(35, (0.35 * moodmod)))) //Veilbreak Edit - full replacement should be occasional, not constant
		if(dumb_thing)
			to_chat(quirk_holder, span_userdanger("You think of a dumb thing you said a long time ago and scream internally."))
			dumb_thing = FALSE //only once per life
			if(prob(1))
				new/obj/item/food/spaghetti/pastatomato(get_turf(quirk_holder)) //now that's what I call spaghetti code
		else
			to_chat(quirk_holder, span_warning("You think that wouldn't add much to the conversation and decide not to say it."))
			if(prob(min(15, (0.15 * moodmod)))) //Veilbreak Edit - rarer and shorter lock-up
				to_chat(quirk_holder, span_danger("You retreat into yourself. You <i>really</i> don't feel up to talking."))
				quirk_holder.set_silence_if_lower(5 SECONDS)

		speech_args[SPEECH_MESSAGE] = pick("Uh.","Erm.","Um.")
	else
		speech_args[SPEECH_MESSAGE] = message

// small chance to make eye contact with inanimate objects/mindless mobs because of nerves
/datum/quirk/social_anxiety/proc/looks_at_floor(datum/source, atom/A)
	SIGNAL_HANDLER

	var/mob/living/mind_check = A
	if(prob(85) || (istype(mind_check) && mind_check.mind))
		return

	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(to_chat), quirk_holder, span_smallnotice("You make eye contact with [A].")), 0.3 SECONDS)

/datum/quirk/social_anxiety/proc/eye_contact(datum/source, mob/living/other_mob, triggering_examiner)
	SIGNAL_HANDLER

	if(prob(75))
		return
	var/msg
	if(triggering_examiner)
		msg = "You make eye contact with [other_mob], "
	else
		msg = "[other_mob] makes eye contact with you, "

	switch(rand(1,3))
		if(1)
			quirk_holder.set_jitter_if_lower(20 SECONDS)
			msg += "causing you to start fidgeting!"
		if(2)
			quirk_holder.set_stutter_if_lower(6 SECONDS)
			msg += "causing you to start stuttering!"
		if(3)
			quirk_holder.Stun(2 SECONDS)
			msg += "causing you to freeze up!"

	quirk_holder.add_mood_event("anxiety_eyecontact", /datum/mood_event/anxiety_eyecontact)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(to_chat), quirk_holder, span_userdanger("[msg]")), 3) // so the examine signal has time to fire and this will print after
	return COMSIG_BLOCK_EYECONTACT

/datum/mood_event/anxiety_eyecontact
	description = "Sometimes eye contact makes me so nervous..."
	mood_change = -5
	timeout = 3 MINUTES

// Veilbreak Edit Start - getting whispered to while submissive flusters us more
/datum/quirk/social_anxiety/proc/on_hear_whisper(datum/source, list/hearing_args)
	SIGNAL_HANDLER

	var/list/message_mods = hearing_args[HEARING_MESSAGE_MODE]
	if(!message_mods || message_mods[WHISPER_MODE] != MODE_WHISPER)
		return
	if(!quirk_holder.has_quirk(/datum/quirk/well_trained))
		return

	quirk_holder.set_stutter_if_lower(6 SECONDS)
	quirk_holder.add_mood_event("anxiety_whisper", /datum/mood_event/anxiety_whisper)
	quirk_holder.adjust_arousal(10) // Veilbreak Edit

/datum/mood_event/anxiety_whisper
	description = "Someone just whispered to me..."
	mood_change = -2
	timeout = 2 MINUTES

// A proper supply of psicodine for managing the trait.
/obj/item/storage/pill_bottle/psicodine/anxiety
	spawn_count = 12
// Veilbreak Edit End
