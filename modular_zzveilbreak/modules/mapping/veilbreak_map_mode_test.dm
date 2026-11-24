// VEILBREAK ADDITION - Unit test: map mode win statistics are mode-separated
// Gated and using Fail() directly because the TEST_ASSERT macros are #undef'd after _unit_tests.dm.

#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/datum/unit_test/veilbreak_map_mode_wins

/datum/unit_test/veilbreak_map_mode_wins/Run()
	veilbreak_map_mode_stats = null

	veilbreak_record_map_win("Veilbreak", MAP_MODE_STANDARD)
	veilbreak_record_map_win("Veilbreak", MAP_MODE_STANDARD)
	veilbreak_record_map_win("Veilbreak", MAP_MODE_BROAD)
	veilbreak_record_map_win("DeltaStation", MAP_MODE_BROAD)

	var/list/wins = veilbreak_get_map_mode_wins()
	if(wins[MAP_MODE_STANDARD]["Veilbreak"] != 2)
		return Fail("Veilbreak should have two STANDARD wins.", __FILE__, __LINE__)
	if(wins[MAP_MODE_BROAD]["Veilbreak"] != 1)
		return Fail("Veilbreak should have one BROAD win.", __FILE__, __LINE__)
	if(wins[MAP_MODE_BROAD]["DeltaStation"] != 1)
		return Fail("DeltaStation should have one BROAD win.", __FILE__, __LINE__)
	if(wins[MAP_MODE_STANDARD]["DeltaStation"])
		return Fail("DeltaStation should have no STANDARD wins.", __FILE__, __LINE__)

#endif
