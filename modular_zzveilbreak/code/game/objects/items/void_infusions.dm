// Upgrading gear with voidshards.
// Modifies the items directly to apply the void effect.
// Each infusable item family has its own section below for easy reading and balancing.

// ============================================================================
// SECTION 0: BASE VOID INFUSION RECIPE & SHARED VOID RESISTANCE SYSTEM
// ============================================================================

/datum/void_infusion_recipe
	var/target_type
	/// Optional override name shown in the Void Infuser UI (useful for MODsuits whose initial name is generic).
	var/display_name
	/// Whether this recipe should be listed in the Void Infuser UI (FALSE for attached sub-items like hoods).
	var/show_in_ui = TRUE
	var/name_prefix = "Void-Infused"
	var/infusion_color = "#c8a4e9"

/datum/void_infusion_recipe/proc/matches(obj/item/target)
	if(!istype(target, target_type))
		return FALSE
	if(findtext(target.name, "[name_prefix]"))
		return FALSE
	return TRUE

/datum/void_infusion_recipe/proc/apply(obj/item/target)
	target.name = "[name_prefix] [format_text(initial(target.name))]"
	target.desc = "[initial(target.desc)] It pulses faintly with dark, purple energy."
	target.color = infusion_color // Voidshard purple glow
	target.light_range = 2
	target.light_power = 0.5
	target.light_color = infusion_color
	return TRUE

/// Returns TRUE if hitby is a void creature, a mob in FACTION_VOID, a voidbolt, or a projectile fired by a void mob.
/proc/is_void_threat(atom/movable/hitby)
	if(!hitby)
		return FALSE
	if(isliving(hitby))
		var/mob/living/attacker = hitby
		if(istype(attacker, /mob/living/basic/void_creature) || (FACTION_VOID in attacker.faction))
			return TRUE
	if(istype(hitby, /obj/projectile))
		var/obj/projectile/proj = hitby
		if(istype(proj, /obj/projectile/magic/voidbolt))
			return TRUE
		if(isliving(proj.firer))
			var/mob/living/firer = proj.firer
			if(istype(firer, /mob/living/basic/void_creature) || (FACTION_VOID in firer.faction))
				return TRUE
	return FALSE

/obj/item/clothing
	/// Tracks whether this piece of clothing has been infused with a voidshard.
	var/void_infused = FALSE
	/// Percentage chance (0-100) to completely deflect incoming attacks from void threats.
	var/void_block_chance = 0
	/// Fractional incoming damage reduction (0.0 to 1.0) against unblocked hits from void threats.
	var/void_damage_reduction = 0
	/// Reactive BURN damage dealt back to living void attackers in melee.
	var/void_retaliation_damage = 0
	/// When TRUE, completely nullifies /obj/projectile/magic/voidbolt hits.
	var/voidbolt_immune = FALSE

/// Keep the Void-Infused prefix intact when repairing damaged void-infused clothing.
/obj/item/clothing/repair(mob/user)
	. = ..()
	if(void_infused && !findtext(name, "Void-Infused"))
		name = "Void-Infused [name]"

/// Virtual check allowing subtypes (e.g. ceremonial cloaks) to disable void defense when not worn defensively.
/obj/item/clothing/proc/can_void_resist(mob/living/carbon/human/owner)
	return void_infused

/// Virtual hook for item-specific anti-void defensive effects (phase blink, siphon, disruption pulse).
/// Return TRUE to force-block the incoming attack.
/obj/item/clothing/proc/on_void_hit_react(mob/living/carbon/human/owner, atom/movable/hitby, attack_text, blocked_hit, damage, attack_type, damage_type)
	return FALSE

/obj/item/clothing/hit_reaction(mob/living/carbon/human/owner, atom/movable/hitby, attack_text = "the attack", final_block_chance = 0, damage = 0, attack_type = MELEE_ATTACK, damage_type = BRUTE)
	if(can_void_resist(owner) && is_void_threat(hitby))
		// Full immunity against voidbolt projectiles (e.g. infused MODsuits)
		if(voidbolt_immune && istype(hitby, /obj/projectile/magic/voidbolt))
			owner.visible_message(
				span_danger("[owner]'s [src] dissipates [attack_text] harmlessly across its void-insulated plating!"),
				span_notice("Your [src] completely nullifies [attack_text]!")
			)
			var/obj/effect/temp_visual/kinetic_blast/ward = new(get_turf(owner))
			ward.color = "#c8a4e9"
			playsound(owner, 'sound/effects/magic/repulse.ogg', 35, TRUE)
			on_void_hit_react(owner, hitby, attack_text, TRUE, damage, attack_type, damage_type)
			return TRUE

		// Item-specific pre-block trigger (e.g. Explorer emergency phase shift)
		if(on_void_hit_react(owner, hitby, attack_text, FALSE, damage, attack_type, damage_type))
			return TRUE

		// Passive spatial deflection roll
		if(void_block_chance > 0 && prob(void_block_chance))
			owner.visible_message(
				span_danger("[owner]'s [src] pulses with an opposing void barrier, deflecting [attack_text]!"),
				span_notice("Your [src] deflects [attack_text] with an ethereal hum!")
			)
			var/obj/effect/temp_visual/kinetic_blast/blast = new(get_turf(owner))
			blast.color = "#c8a4e9"
			playsound(owner, 'sound/effects/magic/repulse.ogg', 40, TRUE)
			trigger_void_retaliation(owner, hitby)
			return TRUE

		// Attack was not fully blocked: apply reactive retaliation and arm synchronous damage reduction
		trigger_void_retaliation(owner, hitby)
		if(void_damage_reduction > 0)
			RegisterSignal(owner, COMSIG_MOB_APPLY_DAMAGE_MODIFIERS, PROC_REF(apply_pending_void_mitigation), override = TRUE)
			addtimer(CALLBACK(src, PROC_REF(clear_pending_void_mitigation), WEAKREF(owner)), 0)

	return ..()

/obj/item/clothing/proc/trigger_void_retaliation(mob/living/carbon/human/owner, atom/movable/hitby)
	if(void_retaliation_damage <= 0 || !isliving(hitby))
		return
	var/mob/living/attacker = hitby
	if(attacker.stat == DEAD)
		return
	attacker.apply_damage(void_retaliation_damage, BURN)
	to_chat(attacker, span_userdanger("Lashing void tendrils from [owner]'s [src] sear you!"))

/obj/item/clothing/proc/apply_pending_void_mitigation(mob/living/source, list/damage_mods, damage, damagetype, def_zone, sharpness, attack_direction, attacking_item)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_MOB_APPLY_DAMAGE_MODIFIERS)
	if(void_damage_reduction > 0)
		damage_mods += clamp(1 - void_damage_reduction, 0, 1)

/obj/item/clothing/proc/clear_pending_void_mitigation(datum/weakref/owner_ref)
	var/mob/living/owner = owner_ref?.resolve()
	if(owner)
		UnregisterSignal(owner, COMSIG_MOB_APPLY_DAMAGE_MODIFIERS)


// ============================================================================
// SECTION 1: ELDER ATMOSIAN ARMOR & HELMET
// ============================================================================

/datum/void_infusion_recipe/elder_atmosian_suit
	target_type = /obj/item/clothing/suit/armor/elder_atmosian
	display_name = "Elder Atmosian Armor"

/datum/void_infusion_recipe/elder_atmosian_suit/apply(obj/item/clothing/suit/armor/elder_atmosian/target)
	..()
	target.desc += " Dimensional wards woven into the metal-hydrogen plates dampen strikes from creatures of the void."
	target.void_infused = TRUE
	target.set_armor(target.get_armor().generate_new_with_modifiers(list(ARMOR_ALL = 20)))
	target.attach_clothing_traits(TRAIT_RADIMMUNE)
	target.void_block_chance = 15
	target.void_damage_reduction = 0.15
	return TRUE

/datum/void_infusion_recipe/elder_atmosian_helmet
	target_type = /obj/item/clothing/head/helmet/elder_atmosian
	display_name = "Elder Atmosian Helmet"

/datum/void_infusion_recipe/elder_atmosian_helmet/apply(obj/item/clothing/head/helmet/elder_atmosian/target)
	..()
	target.desc += " Its visor shimmers with a protective anti-void ward."
	target.void_infused = TRUE
	target.set_armor(target.get_armor().generate_new_with_modifiers(list(ARMOR_ALL = 20)))
	target.attach_clothing_traits(TRAIT_RADIMMUNE)
	target.void_block_chance = 10
	target.void_damage_reduction = 0.10
	return TRUE


// ============================================================================
// SECTION 2: GOLIATH CLOAK & GOLIATH HOOD
// ============================================================================

/datum/void_infusion_recipe/goliath_cloak
	target_type = /obj/item/clothing/suit/hooded/cloak/goliath

/datum/void_infusion_recipe/goliath_cloak/apply(obj/item/clothing/suit/hooded/cloak/goliath/target)
	..()
	target.desc = "[initial(target.desc)] Infused with voidshards, the monster plates ripple like a dimensional shroud that deflects void strikes and sears attackers with lashing tendrils."
	target.void_infused = TRUE
	if(target.slot_flags & ITEM_SLOT_OCLOTHING)
		target.set_armor(target.get_armor().generate_new_with_modifiers(list(MELEE = 15, LASER = 25, ENERGY = 15, BOMB = 15)))
	target.void_block_chance = 25
	target.void_retaliation_damage = 10
	if(target.hood)
		target.infuse_goliath_hood(target.hood)
	return TRUE

/datum/void_infusion_recipe/goliath_hood
	target_type = /obj/item/clothing/head/hooded/cloakhood/goliath
	show_in_ui = FALSE

/datum/void_infusion_recipe/goliath_hood/apply(obj/item/clothing/head/hooded/cloakhood/goliath/target)
	..()
	target.desc = "[initial(target.desc)] Dark purple energy courses along its seams, warding off creatures of the void."
	target.void_infused = TRUE
	target.set_armor(target.get_armor().generate_new_with_modifiers(list(MELEE = 15, LASER = 25, ENERGY = 15)))
	target.void_block_chance = 10
	return TRUE

/obj/item/clothing/suit/hooded/cloak/goliath/proc/infuse_goliath_hood(obj/item/clothing/head/hooded/hood_item)
	if(!hood_item || hood_item.void_infused)
		return
	var/datum/void_infusion_recipe/goliath_hood/hood_recipe = new()
	hood_recipe.apply(hood_item)

/obj/item/clothing/suit/hooded/cloak/goliath/on_hood_created(obj/item/clothing/head/hooded/hood)
	..()
	if(void_infused)
		infuse_goliath_hood(hood)

/// Ceremonial neck-worn mode disables armor; only grant void resistance while worn defensively.
/obj/item/clothing/suit/hooded/cloak/goliath/can_void_resist(mob/living/carbon/human/owner)
	if(!(slot_flags & ITEM_SLOT_OCLOTHING))
		return FALSE
	return ..()

/// Re-apply void armor modifiers when toggling from ceremonial neck mode back to defensive armor mode.
/obj/item/clothing/suit/hooded/cloak/goliath/click_alt(mob/user)
	. = ..()
	if(. == CLICK_ACTION_SUCCESS && void_infused && (slot_flags & ITEM_SLOT_OCLOTHING))
		set_armor(get_armor().generate_new_with_modifiers(list(MELEE = 15, LASER = 25, ENERGY = 15, BOMB = 15)))


// ============================================================================
// SECTION 3: EXPLORER SUIT & EXPLORER HOOD
// ============================================================================

/datum/void_infusion_recipe/explorer_suit
	target_type = /obj/item/clothing/suit/hooded/explorer

/datum/void_infusion_recipe/explorer_suit/apply(obj/item/clothing/suit/hooded/explorer/target)
	..()
	target.desc = "[initial(target.desc)] Reinforced with a dampening void weave that softens blows from void beasts and emergency-blinks the wearer away when badly wounded."
	target.void_infused = TRUE
	target.set_armor(target.get_armor().generate_new_with_modifiers(list(MELEE = 20, ENERGY = 15, BOMB = 15, FIRE = 15)))
	target.attach_clothing_traits(TRAIT_RESISTCOLD)
	if(target.slowdown > 0)
		target.slowdown = 0
	target.void_damage_reduction = 0.20
	if(target.hood)
		target.infuse_explorer_hood(target.hood)
	return TRUE

/datum/void_infusion_recipe/explorer_hood
	target_type = /obj/item/clothing/head/hooded/explorer
	show_in_ui = FALSE

/datum/void_infusion_recipe/explorer_hood/apply(obj/item/clothing/head/hooded/explorer/target)
	..()
	target.desc = "[initial(target.desc)] Lined with void-dampening filaments that resist anomalous strikes."
	target.void_infused = TRUE
	target.set_armor(target.get_armor().generate_new_with_modifiers(list(MELEE = 20, ENERGY = 15, BOMB = 15, FIRE = 15)))
	target.void_damage_reduction = 0.10
	return TRUE

/obj/item/clothing/suit/hooded/explorer
	/// Internal cooldown for Anomalous Phase Shift when struck below 50% health.
	COOLDOWN_DECLARE(void_phase_cooldown)

/obj/item/clothing/suit/hooded/explorer/proc/infuse_explorer_hood(obj/item/clothing/head/hooded/hood_item)
	if(!hood_item || hood_item.void_infused)
		return
	var/datum/void_infusion_recipe/explorer_hood/hood_recipe = new()
	hood_recipe.apply(hood_item)

/obj/item/clothing/suit/hooded/explorer/on_hood_created(obj/item/clothing/head/hooded/hood)
	..()
	if(void_infused)
		infuse_explorer_hood(hood)

/// Anomalous Phase Shift: if struck by a void threat while below 50% HP, blink 2 tiles away (20s cooldown).
/obj/item/clothing/suit/hooded/explorer/on_void_hit_react(mob/living/carbon/human/owner, atom/movable/hitby, attack_text, blocked_hit, damage, attack_type, damage_type)
	if(owner.health > (owner.maxHealth * 0.5) || !COOLDOWN_FINISHED(src, void_phase_cooldown))
		return FALSE

	var/turf/owner_turf = get_turf(owner)
	if(!owner_turf)
		return FALSE

	var/turf/threat_turf = get_turf(hitby)
	if(istype(hitby, /obj/projectile))
		var/obj/projectile/proj = hitby
		if(proj.firer)
			threat_turf = get_turf(proj.firer)

	var/away_dir = (threat_turf && threat_turf != owner_turf) ? get_dir(threat_turf, owner_turf) : turn(owner.dir, 180)
	var/list/candidate_dirs = list(away_dir, turn(away_dir, 45), turn(away_dir, -45), turn(away_dir, 90), turn(away_dir, -90))
	var/turf/dest_turf

	for(var/dir_choice in candidate_dirs)
		var/turf/step_one = get_step(owner_turf, dir_choice)
		if(!step_one || step_one.is_blocked_turf() || isspaceturf(step_one) || ischasm(step_one))
			continue
		var/turf/step_two = get_step(step_one, dir_choice)
		if(step_two && !step_two.is_blocked_turf() && !isspaceturf(step_two) && !ischasm(step_two))
			dest_turf = step_two
			break
		if(!dest_turf)
			dest_turf = step_one

	if(!dest_turf)
		return FALSE

	COOLDOWN_START(src, void_phase_cooldown, 20 SECONDS)
	new /obj/effect/temp_visual/void_tear(owner_turf)
	playsound(owner_turf, 'sound/effects/magic/blink.ogg', 60, TRUE)
	do_teleport(owner, dest_turf, precision = 0, no_effects = TRUE, channel = TELEPORT_CHANNEL_MAGIC, forced = TRUE)
	new /obj/effect/temp_visual/void_tear(get_turf(owner))
	owner.visible_message(
		span_danger("[owner]'s [src] flashes purple, phase-shifting [owner.p_them()] clear of [attack_text]!"),
		span_notice("Your [src] triggers an emergency phase shift, blinking you away from [attack_text]!")
	)
	return TRUE


// ============================================================================
// SECTION 4: BONE ARMOR & SKULL HELMET
// ============================================================================

/datum/void_infusion_recipe/bone_armor
	target_type = /obj/item/clothing/suit/armor/bone

/datum/void_infusion_recipe/bone_armor/apply(obj/item/clothing/suit/armor/bone/target)
	..()
	target.desc = "[initial(target.desc)] Crystallized into obsidian-like void-chitin, it siphons essence from attacking void creatures to mend its wearer."
	target.void_infused = TRUE
	target.set_armor(target.get_armor().generate_new_with_modifiers(list(MELEE = 25, BULLET = 15, ENERGY = 15, WOUND = 15)))
	target.void_block_chance = 15
	target.void_damage_reduction = 0.30
	return TRUE

/datum/void_infusion_recipe/skull_helmet
	target_type = /obj/item/clothing/head/helmet/skull

/datum/void_infusion_recipe/skull_helmet/apply(obj/item/clothing/head/helmet/skull/target)
	..()
	target.desc = "[initial(target.desc)] Hollow sockets glow with hungry void light, drinking in hostile void energy."
	target.void_infused = TRUE
	target.set_armor(target.get_armor().generate_new_with_modifiers(list(MELEE = 20, BULLET = 15, ENERGY = 15)))
	target.void_block_chance = 10
	target.void_damage_reduction = 0.10
	return TRUE

/// Essence Siphon (Bone Armor): absorbs void energy on impact to heal 3 brute/burn and restore 8 stamina.
/obj/item/clothing/suit/armor/bone/on_void_hit_react(mob/living/carbon/human/owner, atom/movable/hitby, attack_text, blocked_hit, damage, attack_type, damage_type)
	owner.heal_overall_damage(brute = 3, burn = 3)
	owner.adjust_stamina_loss(-8)
	new /obj/effect/temp_visual/heal(get_turf(owner), "#c8a4e9")
	return FALSE

/// Essence Siphon (Skull Helmet): minor companion siphon restoring 1 brute/burn and 4 stamina.
/obj/item/clothing/head/helmet/skull/on_void_hit_react(mob/living/carbon/human/owner, atom/movable/hitby, attack_text, blocked_hit, damage, attack_type, damage_type)
	owner.heal_overall_damage(brute = 1, burn = 1)
	owner.adjust_stamina_loss(-4)
	return FALSE


// ============================================================================
// SECTION 5: SECURITY RIOT SUIT & RIOT HELMET
// ============================================================================

/datum/void_infusion_recipe/riot_suit
	target_type = /obj/item/clothing/suit/armor/riot

/datum/void_infusion_recipe/riot_suit/apply(obj/item/clothing/suit/armor/riot/target)
	..()
	target.desc = "[initial(target.desc)] Laced with rift-disrupting coils that repel anomalous energy and blast swarming void creatures back."
	target.void_infused = TRUE
	target.set_armor(target.get_armor().generate_new_with_modifiers(list(MELEE = 15, LASER = 20, ENERGY = 30, FIRE = 15, ACID = 15)))
	if(target.slowdown > 0)
		target.slowdown = max(0, target.slowdown - 0.5)
	target.void_block_chance = 20
	target.void_damage_reduction = 0.20
	return TRUE

/datum/void_infusion_recipe/riot_helmet
	target_type = /obj/item/clothing/head/helmet/toggleable/riot

/datum/void_infusion_recipe/riot_helmet/apply(obj/item/clothing/head/helmet/toggleable/riot/target)
	..()
	target.desc = "[initial(target.desc)] Treated with purple rift-shielding polycarbonate to resist void incursions."
	target.void_infused = TRUE
	target.set_armor(target.get_armor().generate_new_with_modifiers(list(MELEE = 15, LASER = 20, ENERGY = 30, FIRE = 15, ACID = 15)))
	target.void_block_chance = 10
	target.void_damage_reduction = 0.10
	return TRUE

/obj/item/clothing/suit/armor/riot
	/// Cooldown for the Rift Disruption Field shockwave when swarmed by void creatures.
	COOLDOWN_DECLARE(void_disruption_cooldown)

/// Rift Disruption Field: knocks adjacent void creatures back 2 tiles and briefly immobilizes them.
/obj/item/clothing/suit/armor/riot/on_void_hit_react(mob/living/carbon/human/owner, atom/movable/hitby, attack_text, blocked_hit, damage, attack_type, damage_type)
	if(!isliving(hitby) || !COOLDOWN_FINISHED(src, void_disruption_cooldown))
		return FALSE

	var/turf/owner_turf = get_turf(owner)
	if(!owner_turf)
		return FALSE

	COOLDOWN_START(src, void_disruption_cooldown, 8 SECONDS)
	new /obj/effect/temp_visual/void_tear(owner_turf)
	playsound(owner_turf, 'sound/effects/magic/repulse.ogg', 55, TRUE)
	owner.visible_message(
		span_danger("[owner]'s [src] discharges a rift disruption pulse, hurling nearby void creatures back!"),
		span_notice("Your [src] emits a rift disruption pulse!")
	)

	for(var/mob/living/creature in orange(1, owner_turf))
		if(creature == owner || creature.stat == DEAD)
			continue
		if(!istype(creature, /mob/living/basic/void_creature) && !(FACTION_VOID in creature.faction))
			continue
		var/turf/push_target = get_edge_target_turf(owner_turf, get_dir(owner_turf, creature))
		creature.safe_throw_at(push_target, 2, 2, force = MOVE_FORCE_STRONG)
		if(istype(creature, /mob/living/basic/void_creature))
			creature.Immobilize(1.5 SECONDS)
	return FALSE


// ============================================================================
// SECTION 6: MINING & SECURITY MODSUITS
// ============================================================================

/datum/void_infusion_recipe/mining_modsuit
	target_type = /obj/item/mod/control/pre_equipped/mining
	display_name = "mining MOD control unit"

/datum/void_infusion_recipe/mining_modsuit/matches(obj/item/target)
	if(!istype(target, /obj/item/mod/control))
		return FALSE
	if(findtext(target.name, "[name_prefix]"))
		return FALSE
	var/obj/item/mod/control/mod = target
	return istype(mod, /obj/item/mod/control/pre_equipped/mining) || istype(mod.theme, /datum/mod_theme/mining)

/datum/void_infusion_recipe/mining_modsuit/apply(obj/item/mod/control/target)
	apply_void_modsuit_infusion(target, infusion_color, name_prefix)
	return TRUE

/datum/void_infusion_recipe/security_modsuit
	target_type = /obj/item/mod/control/pre_equipped/security
	display_name = "security MOD control unit"

/datum/void_infusion_recipe/security_modsuit/matches(obj/item/target)
	if(!istype(target, /obj/item/mod/control))
		return FALSE
	if(findtext(target.name, "[name_prefix]"))
		return FALSE
	var/obj/item/mod/control/mod = target
	return istype(mod, /obj/item/mod/control/pre_equipped/security) || istype(mod.theme, /datum/mod_theme/security)

/datum/void_infusion_recipe/security_modsuit/apply(obj/item/mod/control/target)
	apply_void_modsuit_infusion(target, infusion_color, name_prefix)
	return TRUE

/// Shared helper that upgrades a MODsuit control unit and all of its deployable armor parts.
/proc/apply_void_modsuit_infusion(obj/item/mod/control/mod, infusion_color, name_prefix)
	mod.name = "[name_prefix] [mod.name]"
	mod.desc = "[mod.desc] Void-insulated actuators lighten its frame and nullify voidbolt projectiles while absorbing void creature blows."
	mod.light_range = 2
	mod.light_power = 0.5
	mod.light_color = infusion_color
	mod.slowdown_deployed *= 0.5
	mod.update_speed()
	mod.set_mod_color(infusion_color)

	for(var/obj/item/clothing/part in mod.get_parts())
		if(!findtext(part.name, "[name_prefix]"))
			part.name = "[name_prefix] [part.name]"
		part.desc = "[part.desc] Insulated with dark purple voidshard energy."
		part.void_infused = TRUE
		part.set_armor(part.get_armor().generate_new_with_modifiers(list(MELEE = 15, BULLET = 10, LASER = 15, ENERGY = 20, BOMB = 15)))
		if(istype(part, /obj/item/clothing/suit/mod))
			part.attach_clothing_traits(TRAIT_RADIMMUNE)
			part.voidbolt_immune = TRUE
			part.void_block_chance = 20
			part.void_damage_reduction = 0.35
		else if(istype(part, /obj/item/clothing/head/mod))
			part.void_block_chance = 10


// ============================================================================
// SECTION 7: RIOT SHIELD & GOLIATH SHIELD
// ============================================================================

/datum/void_infusion_recipe/riot_shield
	target_type = /obj/item/shield/riot

/datum/void_infusion_recipe/riot_shield/apply(obj/item/shield/riot/target)
	..()
	target.desc = "[initial(target.desc)] Tempered with voidshard energy, it effortlessly turns aside void creatures and unleashes a concussive rift wave on block."
	target.void_infused_shield = TRUE
	target.max_integrity += 75
	target.atom_integrity = target.max_integrity
	target.set_armor(target.get_armor().generate_new_with_modifiers(list(MELEE = 15, LASER = 25, ENERGY = 30)))
	return TRUE

/datum/void_infusion_recipe/goliath_shield
	target_type = /obj/item/shield/goliath

/datum/void_infusion_recipe/goliath_shield/apply(obj/item/shield/goliath/target)
	..()
	target.desc = "[initial(target.desc)] Interwoven with pulsing void-chitin, it forms an almost impenetrable bulwark against creatures of the void."
	target.void_infused_shield = TRUE
	target.max_integrity += 75
	target.atom_integrity = target.max_integrity
	target.set_armor(target.get_armor().generate_new_with_modifiers(list(MELEE = 20, LASER = 20, ENERGY = 25)))
	return TRUE

/obj/item/shield
	/// Tracks whether this shield has been void-infused for anti-void bulwark effects.
	var/void_infused_shield = FALSE
	/// Cooldown between concussive shockwaves when blocking void threats.
	COOLDOWN_DECLARE(void_shield_shockwave_cd)

/obj/item/shield/hit_reaction(mob/living/carbon/human/owner, atom/movable/hitby, attack_text = "the attack", final_block_chance = 0, damage = 0, attack_type = MELEE_ATTACK, damage_type = BRUTE)
	if(void_infused_shield && is_void_threat(hitby))
		if(prob(80))
			owner.visible_message(
				span_danger("[owner] intercepts [attack_text] squarely with [src], unleashing a resonant purple shockwave!"),
				span_notice("You block [attack_text] with [src]!")
			)
			var/turf/owner_turf = get_turf(owner)
			var/obj/effect/temp_visual/kinetic_blast/blast = new(owner_turf)
			blast.color = "#c8a4e9"
			playsound(src, block_sound, BLOCK_SOUND_VOLUME, vary = TRUE)

			if(owner_turf && COOLDOWN_FINISHED(src, void_shield_shockwave_cd))
				COOLDOWN_START(src, void_shield_shockwave_cd, 5 SECONDS)
				new /obj/effect/temp_visual/void_tear(owner_turf)
				playsound(owner_turf, 'sound/effects/magic/repulse.ogg', 45, TRUE)
				for(var/mob/living/basic/void_creature/void_mob in orange(1, owner_turf))
					if(void_mob.stat == DEAD)
						continue
					void_mob.Immobilize(2 SECONDS)
					var/turf/knock_turf = get_step(void_mob, get_dir(owner_turf, void_mob))
					if(knock_turf && !knock_turf.is_blocked_turf())
						void_mob.safe_throw_at(knock_turf, 1, 2, force = MOVE_FORCE_STRONG)
			return TRUE
	return ..()


// ============================================================================
// SECTION 8: HYDRO DUFFEL BACKPACK
// ============================================================================

/datum/void_infusion_recipe/hydro_duffel
	target_type = /obj/item/storage/backpack/hydro_duffel

/datum/void_infusion_recipe/hydro_duffel/apply(obj/item/storage/backpack/hydro_duffel/target)
	target.name = "[name_prefix] [format_text(initial(target.name))]"
	target.desc = "[initial(target.desc)] It pulses faintly with dark, purple energy, seeming bigger on the inside."
	target.color = infusion_color
	target.light_range = 2
	target.light_power = 0.5
	target.light_color = infusion_color
	if(target.atom_storage)
		target.atom_storage.max_slots += 5
		target.atom_storage.max_total_storage += 25
		target.atom_storage.max_specific_storage = WEIGHT_CLASS_GIGANTIC
	return TRUE


// ============================================================================
// SECTION 9: METAL H2 FIREAXE
// ============================================================================

/datum/void_infusion_recipe/metal_h2_axe
	target_type = /obj/item/fireaxe/metal_h2_axe

/datum/void_infusion_recipe/metal_h2_axe/apply(obj/item/fireaxe/metal_h2_axe/target)
	target.name = "[name_prefix] [format_text(initial(target.name))]"
	target.desc = "[initial(target.desc)] The blade hums with dark, purple energy, eager to strike down the void."
	target.color = infusion_color
	target.light_range = 2
	target.light_power = 0.5
	target.light_color = infusion_color
	return TRUE

/obj/item/fireaxe/metal_h2_axe/attack(mob/living/target, mob/living/user, def_zone)
	if(findtext(name, "Void-Infused") && isliving(target) && (FACTION_VOID in target.faction))
		target.apply_damage(12, BRUTE, def_zone)
		to_chat(user, "<span class='warning'>\The [src] burns [target] with void energy!</span>")
	return ..()


// ============================================================================
// SECTION 10: PROTO-KINETIC ACCELERATOR
// ============================================================================

/datum/void_infusion_recipe/kinetic_accelerator
	target_type = /obj/item/gun/energy/recharge/kinetic_accelerator

/datum/void_infusion_recipe/kinetic_accelerator/apply(obj/item/gun/energy/recharge/kinetic_accelerator/target)
	target.name = "[name_prefix] [format_text(initial(target.name))]"
	target.desc = "[initial(target.desc)] Dark energy coils through the core; bolts strike harder and tear deeper into creatures of the void."
	target.color = infusion_color
	target.light_range = 2
	target.light_power = 0.5
	target.light_color = infusion_color
	target.void_infusion_damage_bonus = 10
	target.void_infusion_antivoid_bonus = 30
	return TRUE

/obj/item/gun/energy/recharge/kinetic_accelerator
	icon = 'modular_zzveilbreak/icons/item_icons/void_gun_void_KPA.dmi'
	icon_state = "vkineticgun"
	base_icon_state = "vkineticgun"
	inhand_icon_state = "vkineticgun"
	lefthand_file = 'modular_zzveilbreak/icons/item_icons/lefthand.dmi'
	righthand_file = 'modular_zzveilbreak/icons/item_icons/righthand.dmi'
	/// Bonus projectile damage from void infusion (all targets).
	var/void_infusion_damage_bonus = 0
	/// Extra damage vs mobs in FACTION_VOID; applied when the bolt pre-hits a living target.
	var/void_infusion_antivoid_bonus = 0

/obj/item/gun/energy/recharge/kinetic_accelerator/modify_projectile(obj/projectile/kinetic/kinetic_projectile)
	kinetic_projectile.kinetic_gun = src
	for(var/obj/item/borg/upgrade/modkit/modkit_upgrade as anything in modkits)
		modkit_upgrade.modify_projectile(kinetic_projectile)
	kinetic_projectile.bonus_vs_void = void_infusion_antivoid_bonus
	if(void_infusion_damage_bonus)
		kinetic_projectile.damage += void_infusion_damage_bonus

/obj/projectile/kinetic
	var/bonus_vs_void = 0

/obj/projectile/kinetic/prehit_pierce(atom/target)
	if(is_type_in_typecache(target, kinetic_gun?.ignored_mob_types))
		return PROJECTILE_PIERCE_PHASE
	. = ..()
	if(. == PROJECTILE_PIERCE_PHASE)
		return
	for(var/obj/item/borg/upgrade/modkit/modkit_upgrade as anything in kinetic_gun?.modkits)
		modkit_upgrade.projectile_prehit(src, target, kinetic_gun)
	if(!pressure_decrease_active && !lavaland_equipment_pressure_check(get_turf(target)))
		name = "weakened [name]"
		damage = damage * pressure_decrease
		pressure_decrease_active = TRUE
	if(bonus_vs_void && isliving(target))
		var/mob/living/living_target = target
		if(FACTION_VOID in living_target.faction)
			damage += bonus_vs_void


// ============================================================================
// SECTION 11: HEATED REBAR CROSSBOW
// ============================================================================
// Mob-only heat bursts (no turf/obj ex_act). One burst per projectile hit (each pierce counts).

/datum/void_infusion_recipe/heated_rebar_crossbow
	target_type = /obj/item/gun/ballistic/rifle/rebarxbow

/datum/void_infusion_recipe/heated_rebar_crossbow/apply(obj/item/gun/ballistic/rifle/rebarxbow/target)
	..()
	target.desc += " Each shot detonates with a snap of contained heat."
	target.void_heat_infused = TRUE
	return TRUE

/obj/item/gun/ballistic/rifle/rebarxbow
	/// When TRUE (void infusion), rebar projectiles trigger a small mob-only burn burst on each impact.
	var/void_heat_infused = FALSE

/obj/item/ammo_casing/rebar/ready_proj(atom/target, mob/living/user, quiet, zone_override = "", atom/fired_from)
	. = ..()
	if(!loaded_projectile || !istype(loaded_projectile, /obj/projectile/bullet/rebar))
		return
	var/obj/item/gun/ballistic/rifle/rebarxbow/bow = fired_from
	if(!istype(bow) || !bow.void_heat_infused)
		return
	var/obj/projectile/bullet/rebar/bolt = loaded_projectile
	bolt.void_heat_burst = TRUE

/obj/projectile/bullet/rebar
	/// Set when fired from a void-infused rebar crossbow; triggers [/proc/void_crossbow_heat_burst] on each [/obj/projectile/bullet/rebar/proc/on_hit].
	var/void_heat_burst = FALSE

/obj/projectile/bullet/rebar/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	if(!void_heat_burst || . == BULLET_ACT_BLOCK || blocked >= 100)
		return
	var/turf/epicenter = get_turf(target)
	if(epicenter)
		void_crossbow_heat_burst(epicenter)

/// Applies a tight heat "explosion" to living mobs in range only — no station damage.
/proc/void_crossbow_heat_burst(turf/epicenter)
	if(!epicenter)
		return
	new /obj/effect/temp_visual/kinetic_blast(epicenter)
	playsound(epicenter, 'sound/effects/explosion/explosion1.ogg', 35, TRUE)

	for(var/mob/living/victim in orange(1, epicenter))
		if(victim.stat == DEAD)
			continue
		var/dist = get_dist(victim, epicenter)
		var/damage = dist ? 8 : 15
		victim.apply_damage(damage, BURN, spread_damage = TRUE, wound_bonus = CANT_WOUND)


// ============================================================================
// SECTION 12: KINETIC CRUSHER
// ============================================================================

/datum/void_infusion_recipe/kinetic_crusher
	target_type = /obj/item/kinetic_crusher

/datum/void_infusion_recipe/kinetic_crusher/matches(obj/item/target)
	if(!istype(target, target_type))
		return FALSE
	if(findtext(target.name, name_prefix))
		return FALSE
	return TRUE

/datum/void_infusion_recipe/kinetic_crusher/apply(obj/item/kinetic_crusher/target)
	..()
	target.name = "[name_prefix] [format_text(initial(target.name))]"
	target.desc += " Dark void energy coils around its chassis. Striking a marked target has a chance to unleash a crushing void cleave that tears through space behind them."
	target.void_infused = TRUE
	return TRUE

/obj/item/kinetic_crusher
	/// Tracks whether this specific crusher has been void-infused
	var/void_infused = FALSE

/// RANGED ATTACK: Changes the projectile color and name to fit the void theme
/obj/item/kinetic_crusher/fire_kinetic_blast(atom/target, mob/living/user, list/modifiers)
	. = ..()
	if(!void_infused)
		return

	for(var/obj/projectile/destabilizer/D in range(1, user))
		if(D.fired_from == src)
			D.name = "void-infused destabilizing force"
			D.color = "#c8a4e9"
			break

/// RANGED HIT (MARKING): Applies both native and custom marks when the projectile hits a void creature
/obj/projectile/destabilizer/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	var/obj/item/kinetic_crusher/crusher = fired_from

	if(istype(crusher) && crusher.void_infused && isliving(target))
		var/mob/living/living_target = target

		if(istype(living_target, /mob/living/basic/void_creature) || (FACTION_VOID in living_target.faction))
			// Apply native status effect so the engine processes the mark correctly
			living_target.apply_status_effect(/datum/status_effect/crusher_mark, boosted, crusher)
			// Hard guarantee variable mark backup
			living_target.void_crusher_marked = TRUE

			// Visual indicator for a successful ranged mark hit
			new /obj/effect/temp_visual/kinetic_blast(get_turf(living_target))

			if(isliving(firer))
				to_chat(firer, span_notice("You have marked [living_target] with void destabilization!"))

/// MELEE ATTACK (DETONATION): Triggered when striking the target up close
/obj/item/kinetic_crusher/attack(mob/living/target, mob/living/carbon/user)
	if(!void_infused || !isliving(target))
		return ..()

	// Capture the mark status BEFORE the native code detonates and clears it
	var/has_mark = (target.void_crusher_marked || target.has_status_effect(/datum/status_effect/crusher_mark))
	var/is_wielded = HAS_TRAIT(src, TRAIT_WIELDED)

	// Adjust force variables for void faction if needed
	var/old_force = force
	if(is_wielded && (FACTION_VOID in target.faction))
		force = force_wielded

	// Execute parent call. Thanks to relay_attackers element on the mob,
	// the native code will now fully recognize the target, detonate the mark, and play standard animations/sounds.
	. = ..()

	force = old_force

	// If the target was successfully marked and hit while wielded, roll for a 65% chance to unleash Void Cleave
	if(is_wielded && has_mark && !QDELETED(target))
		target.void_crusher_marked = FALSE
		if(prob(65))
			handle_void_cleave(target, user)
		else
			to_chat(user, span_warning("The void mark detonates, but the spatial rift fails to materialize!"))

	return .

/// Unleashes a 3-tile wide area sweep behind the target, dealing brute damage
/obj/item/kinetic_crusher/proc/handle_void_cleave(mob/living/target, mob/living/user)
	var/cleave_dir = user.dir
	var/turf/origin_turf = get_step(target, cleave_dir)

	if(!origin_turf)
		return

	var/list/target_turfs = list(origin_turf)
	var/turf/left_cleave = get_step(origin_turf, turn(cleave_dir, 90))
	if(left_cleave)
		target_turfs += left_cleave

	var/turf/right_cleave = get_step(origin_turf, turn(cleave_dir, -90))
	if(right_cleave)
		target_turfs += right_cleave

	// Payload damage calculation (Wielded force + Detonation damage)
	var/sweep_damage = force_wielded + detonation_damage

	for(var/turf/T in target_turfs)
		var/obj/effect/temp_visual/kinetic_blast/blast = new(T)
		if(blast)
			blast.color = "#c8a4e9" // Beautiful purple void effect

		for(var/mob/living/victim in T)
			if(victim == user || victim == target)
				continue

			victim.apply_damage(sweep_damage, BRUTE)
			to_chat(victim, span_userdanger("A devastating purple void cleave from [user]'s crusher cuts through space and batters you!"))

	to_chat(user, span_notice("Void Cleave successful! Space ruptures behind your target."))

/mob/living
	var/void_crusher_marked = FALSE



// ============================================================================
// SHARED HELPER: VOID-INFUSED ENERGY WEAPON FRAMEWORK
// ============================================================================

/obj/item/gun/energy
	/// Whether this energy weapon has been infused with a voidshard.
	var/void_infused_egun = FALSE
	/// Bonus BURN damage dealt when a shot from this weapon hits a void creature.
	var/void_bonus_damage = 0
	/// Flat base damage added to projectiles readied by this weapon.
	var/void_base_damage_bonus = 0
	/// Extra tile range added to projectiles readied by this weapon.
	var/void_extra_range = 0

/// Enables slow passive cell self-regen, purple void projectile styling, anti-void bonus damage, and hit hooks.
/obj/item/gun/energy/proc/enable_void_energy_infusion(bonus_void_dmg = 20, base_dmg_bonus = 0, extra_range = 0, charge_rate_mult = 0.025, delay_seconds = 10)
	void_infused_egun = TRUE
	void_bonus_damage = bonus_void_dmg
	void_base_damage_bonus = base_dmg_bonus
	void_extra_range = extra_range

	// Enable slow passive self-regeneration (or gently boost existing self-charging weapons)
	if(!selfcharge)
		selfcharge = TRUE
		charge_delay = delay_seconds
		self_charge_amount = charge_rate_mult * STANDARD_CELL_CHARGE
		START_PROCESSING(SSobj, src)
	else
		self_charge_amount = max(self_charge_amount, charge_rate_mult * STANDARD_CELL_CHARGE * 1.5)

	for(var/obj/item/ammo_casing/energy/shot in ammo_type)
		shot.muzzle_flash_color = "#c8a4e9"
		RegisterSignal(shot, COMSIG_CASING_READY_PROJECTILE, PROC_REF(on_void_energy_ready_proj), override = TRUE)

	RegisterSignal(src, COMSIG_PROJECTILE_ON_HIT, PROC_REF(on_void_energy_proj_hit), override = TRUE)

/obj/item/gun/energy/proc/on_void_energy_ready_proj(obj/item/ammo_casing/source, atom/target, mob/living/user, quiet, zone_override, atom/fired_from)
	SIGNAL_HANDLER
	var/obj/projectile/proj = source.loaded_projectile
	if(!proj)
		return
	proj.color = "#c8a4e9"
	proj.light_color = COLOR_STRONG_VIOLET
	proj.impact_effect_type = /obj/effect/temp_visual/impact_effect/purple_laser
	if(void_base_damage_bonus)
		proj.damage += void_base_damage_bonus
	if(void_extra_range)
		proj.range += void_extra_range

/obj/item/gun/energy/proc/on_void_energy_proj_hit(datum/source, atom/movable/firer, atom/target, angle, hit_limb_zone, blocked = 0, pierce_hit)
	SIGNAL_HANDLER
	if(blocked >= 100 || !isliving(target))
		return
	var/mob/living/living_target = target
	if(!istype(living_target, /mob/living/basic/void_creature) && !(FACTION_VOID in living_target.faction))
		return

	if(void_bonus_damage > 0 && living_target.stat != DEAD)
		living_target.apply_damage(void_bonus_damage, BURN, spread_damage = TRUE, wound_bonus = CANT_WOUND)

	on_void_creature_shot(isliving(firer) ? firer : null, living_target, blocked)

/// Virtual hook for each infused energy gun's unique anti-void signature ability.
/obj/item/gun/energy/proc/on_void_creature_shot(mob/living/firer, mob/living/void_target, blocked = 0)
	return


// ============================================================================
// SECTION 13: HYBRID ENERGY GUN
// ============================================================================

/datum/void_infusion_recipe/energy_gun
	target_type = /obj/item/gun/energy/e_gun

/datum/void_infusion_recipe/energy_gun/matches(obj/item/target)
	if(!..())
		return FALSE
	var/obj/item/gun/energy/e_gun/egun = target
	if((egun.gun_flags & NOT_A_REAL_GUN) || egun.use_cyborg_cell || istype(egun, /obj/item/gun/energy/e_gun/dragnet))
		return FALSE
	return TRUE

/datum/void_infusion_recipe/energy_gun/apply(obj/item/gun/energy/e_gun/target)
	..()
	target.desc = "[initial(target.desc)] A voidshard core slowly trickles charge into its cell, empowers every firemode against void creatures, and siphons energy back upon striking them."
	target.enable_void_energy_infusion(bonus_void_dmg = 20, base_dmg_bonus = 3, charge_rate_mult = 0.025, delay_seconds = 10)
	return TRUE

/// Unique Ability — Void Siphon Capacitor: refunds 35% of shot cost on hitting a void creature (100% if the hit kills it).
/obj/item/gun/energy/e_gun/on_void_creature_shot(mob/living/firer, mob/living/void_target, blocked = 0)
	if(!cell || !LAZYLEN(ammo_type))
		return
	var/obj/item/ammo_casing/energy/current_shot = ammo_type[ clamp(select, 1, ammo_type.len) ]
	if(!istype(current_shot) || current_shot.e_cost <= 0)
		return
	var/refund_ratio = (void_target.stat == DEAD) ? 1.0 : 0.35
	cell.give(round(current_shot.e_cost * refund_ratio))
	if(!chambered)
		recharge_newshot(TRUE)
	update_appearance()


// ============================================================================
// SECTION 14: TYPE 5 LASER GUN
// ============================================================================

/datum/void_infusion_recipe/laser_gun
	target_type = /obj/item/gun/energy/laser
	display_name = "Type 5 laser gun"

/datum/void_infusion_recipe/laser_gun/matches(obj/item/target)
	if(!..())
		return FALSE
	var/obj/item/gun/energy/laser/lasgun = target
	if((lasgun.gun_flags & NOT_A_REAL_GUN) || lasgun.use_cyborg_cell)
		return FALSE
	return TRUE

/datum/void_infusion_recipe/laser_gun/apply(obj/item/gun/energy/laser/target)
	..()
	target.desc = "[initial(target.desc)] Its focusing crystal hums with self-regenerating void energy; beams sear void creatures and arc purple void-lightning to nearby packmates."
	target.enable_void_energy_infusion(bonus_void_dmg = 25, base_dmg_bonus = 5, charge_rate_mult = 0.025, delay_seconds = 10)
	return TRUE

/// Unique Ability — Chain Void Arc: arcs purple void-lightning from the struck void target to up to 2 nearby void creatures within 3 tiles.
/obj/item/gun/energy/laser/on_void_creature_shot(mob/living/firer, mob/living/void_target, blocked = 0)
	var/turf/target_turf = get_turf(void_target)
	if(!target_turf)
		return

	var/arcs_left = 2
	for(var/mob/living/nearby in oview(3, void_target))
		if(arcs_left <= 0)
			break
		if(nearby == firer || nearby == void_target || nearby.stat == DEAD)
			continue
		if(!istype(nearby, /mob/living/basic/void_creature) && !(FACTION_VOID in nearby.faction))
			continue

		arcs_left--
		void_target.Beam(nearby, icon_state = "purple_lightning", time = 0.4 SECONDS)
		nearby.apply_damage(15, BURN, spread_damage = TRUE, wound_bonus = CANT_WOUND)

	if(arcs_left < 2)
		playsound(target_turf, 'sound/effects/sparks/sparks4.ogg', 40, TRUE)


// ============================================================================
// SECTION 15: PLASMA CUTTER & ADVANCED PLASMA CUTTER
// ============================================================================

/datum/void_infusion_recipe/plasma_cutter
	target_type = /obj/item/gun/energy/plasmacutter

/datum/void_infusion_recipe/plasma_cutter/matches(obj/item/target)
	if(!..())
		return FALSE
	var/obj/item/gun/energy/plasmacutter/cutter = target
	if(cutter.use_cyborg_cell)
		return FALSE
	return TRUE

/datum/void_infusion_recipe/plasma_cutter/apply(obj/item/gun/energy/plasmacutter/target)
	..()
	target.desc = "[initial(target.desc)] Void-infused coils slowly regenerate its cell, extend plasma arc range, and collapse micro-rifts that yank and scorch nearby void creatures."
	target.can_charge = TRUE
	target.enable_void_energy_infusion(bonus_void_dmg = 30, base_dmg_bonus = 6, extra_range = 2, charge_rate_mult = 0.03, delay_seconds = 10)
	return TRUE

/// Unique Ability — Micro-Rift Collapse: tears a momentary rift on hit, pulling nearby void creatures within 2 tiles inward and scorching them.
/obj/item/gun/energy/plasmacutter/on_void_creature_shot(mob/living/firer, mob/living/void_target, blocked = 0)
	var/turf/epicenter = get_turf(void_target)
	if(!epicenter)
		return

	new /obj/effect/temp_visual/void_tear(epicenter)
	for(var/mob/living/nearby in orange(2, epicenter))
		if(nearby == firer || nearby == void_target || nearby.stat == DEAD || nearby.anchored)
			continue
		if(!istype(nearby, /mob/living/basic/void_creature) && !(FACTION_VOID in nearby.faction))
			continue
		step_towards(nearby, epicenter)
		nearby.apply_damage(10, BURN, spread_damage = TRUE, wound_bonus = CANT_WOUND)


// ============================================================================
// SECTION 16: DISABLER & DISABLER SMG
// ============================================================================

/datum/void_infusion_recipe/disabler
	target_type = /obj/item/gun/energy/disabler

/datum/void_infusion_recipe/disabler/matches(obj/item/target)
	if(!..())
		return FALSE
	var/obj/item/gun/energy/disabler/dis = target
	if(dis.use_cyborg_cell)
		return FALSE
	return TRUE

/datum/void_infusion_recipe/disabler/apply(obj/item/gun/energy/disabler/target)
	..()
	target.desc = "[initial(target.desc)] Re-tuned to dimensional frequencies: slowly regenerates charge, sears void creatures, anchors their movement, and silences voidbug pack alerts."
	var/bonus_dmg = istype(target, /obj/item/gun/energy/disabler/smg) ? 12 : 22
	target.enable_void_energy_infusion(bonus_void_dmg = bonus_dmg, base_dmg_bonus = 0, charge_rate_mult = 0.025, delay_seconds = 10)
	return TRUE

/// Unique Ability — Dimensional Neural Anchor: briefly pins basic void creatures in place and jams Voidbug swarm-alert hums.
/obj/item/gun/energy/disabler/on_void_creature_shot(mob/living/firer, mob/living/void_target, blocked = 0)
	if(void_target.stat == DEAD)
		return
	if(istype(void_target, /mob/living/basic/void_creature/voidbug))
		var/mob/living/basic/void_creature/voidbug/bug = void_target
		bug.last_alert_time = world.time
	if(istype(void_target, /mob/living/basic/void_creature))
		var/pin_duration = istype(src, /obj/item/gun/energy/disabler/smg) ? (0.5 SECONDS) : (1.5 SECONDS)
		void_target.Immobilize(pin_duration)
