// Tattoo kit research node and design.
// Kept in a single modular file with an inline node id define so no base techweb
// defines need to be modified. The kit is gated behind this node, so it cannot be
// printed at the Service protolathe until the research is completed.

#define TECHWEB_NODE_TATTOO "tattoo"

/datum/design/custom_tattoo_kit
	name = "Professional Tattoo Kit"
	desc = "A complete tattoo application system with multiple ink reservoirs and precision needles."
	id = "custom_tattoo_kit"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
	)
	build_path = /obj/item/custom_tattoo_kit
	category = list(
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_SERVICE,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SERVICE

/datum/techweb_node/tattoo
	id = TECHWEB_NODE_TATTOO
	display_name = "Tattoo Technology"
	description = "Advanced dermal engraving systems for permanent, customizable body art."
	prereq_ids = list(TECHWEB_NODE_OFFICE_EQUIP)
	design_ids = list(
		"custom_tattoo_kit",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_1_POINTS)
	announce_channels = list(RADIO_CHANNEL_SERVICE)
