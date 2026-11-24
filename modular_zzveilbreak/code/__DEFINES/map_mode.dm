// VEILBREAK ADDITION - Map mode system defines

/// Tag identifying a map's source. Veilbreak maps are tagged in their JSON; upstream maps default to this.
#define MAP_ORIGIN_VEILBREAK "veilbreak"
#define MAP_ORIGIN_UPSTREAM "upstream"

/// Map modes. STANDARD restricts rotation/voting to Veilbreak maps only; BROAD allows every map.
#define MAP_MODE_STANDARD "STANDARD"
#define MAP_MODE_BROAD "BROAD"

/// Persisted runtime override, stored in the data directory so it survives restarts until an admin flips it.
#define VEILBREAK_MAP_MODE_FILE "data/veilbreak_map_mode.txt"
#define VEILBREAK_MAP_MODE_STATS_FILE "data/veilbreak_map_mode_stats.json"
