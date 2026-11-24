# Veilbreak Map Mode

This system lets administrators switch the server's map rotation between two modes:

- **STANDARD** (default) — only Veilbreak maps are votable / in rotation.
- **BROAD** — every map (Veilbreak + upstream tg/Bubber/Splurt/Skyrat maps) is votable, with no weighting.

The chosen mode is a server-level setting: it survives round ends **and** restarts until an
admin flips it again.

## How to switch modes

- **Admin verb** `Set Map Mode` (Server panel, `R_SERVER`) — flips the mode live, broadcasts an
  announcement, and refreshes the map vote cache.
- **Admin verb** `Map Mode Statistics` (Server panel, `R_ADMIN`) — prints the current mode, the
  allowed-map list, the full map table (origin/votable/tally/etc.), and the switch history.

The runtime mode is persisted to `data/veilbreak_map_mode.txt`. The shipped default lives in
`config/config.txt` under `VEILBREAK_MAP_MODE` (fallback if the persisted file is absent).

## Tagging a Veilbreak map

For a map to be considered a "Veilbreak" map in STANDARD mode, set `"map_origin": "veilbreak"`
in its `_maps/*.json` (upstream maps default to `"upstream"`). Also make sure its `.dmm` is
included under `#ifdef ALL_MAPS` in `_maps/_basemap.dm`.
