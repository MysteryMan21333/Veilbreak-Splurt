// Veilbreak Implement Start

// Holosynths are a synthetic lifeform and should be excluded from quirks that don't apply to machines.
/datum/quirk/item_quirk/allergic/is_species_appropriate(datum/species/mob_species)
	var/list/species_traits = GLOB.species_prototypes[mob_species].inherent_traits
	if(TRAIT_HOLOSYNTH in species_traits)
		return FALSE
	return ..()

/datum/quirk/body_purist/is_species_appropriate(datum/species/mob_species)
	var/list/species_traits = GLOB.species_prototypes[mob_species].inherent_traits
	if(TRAIT_HOLOSYNTH in species_traits)
		return FALSE
	return ..()

/datum/quirk/item_quirk/food_allergic/is_species_appropriate(datum/species/mob_species)
	var/list/species_traits = GLOB.species_prototypes[mob_species].inherent_traits
	if(TRAIT_HOLOSYNTH in species_traits)
		return FALSE
	return ..()

/datum/quirk/item_quirk/asthma/is_species_appropriate(datum/species/mob_species)
	var/list/species_traits = GLOB.species_prototypes[mob_species].inherent_traits
	if(TRAIT_HOLOSYNTH in species_traits)
		return FALSE
	return ..()

/datum/quirk/item_quirk/anosmia/is_species_appropriate(datum/species/mob_species)
	var/list/species_traits = GLOB.species_prototypes[mob_species].inherent_traits
	if(TRAIT_HOLOSYNTH in species_traits)
		return FALSE
	return ..()

/datum/quirk/item_quirk/immunodeficiency/is_species_appropriate(datum/species/mob_species)
	var/list/species_traits = GLOB.species_prototypes[mob_species].inherent_traits
	if(TRAIT_HOLOSYNTH in species_traits)
		return FALSE
	return ..()

// Veilbreak Implement End
