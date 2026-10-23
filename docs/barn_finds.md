# Barn finds

Three old garages (`BarnFinds.SITES`) hide the UAZ Expedition, UAZ 452 Bukhanka and UAZ 469 Classic.
They are locked at the start (`VehicleProgress.BARN_VEHICLES`): greyed in the garage and skipped by the
number keys. Each barn has a tarp-covered vehicle at its doors. Driving within 16 m removes the tarp and
unlocks the vehicle; press **C** within 10 m to take it (the player switches into it on the spot).
The GPS shows a "?" rumour circle around unfound barns and a house icon once found (orange: not yet taken,
green: taken). Progress lives in `user://offroad_progress.cfg`; delete it to hide the cars again.

Model: `assets/barn/old_garage.glb` (photoscan rotated ~23° in the source; `MODEL_YAW` straightens it so the
doors face +Z, towards the nearest road). The hole at the front-right corner is closed with
`assets/barn/corner_fill.res`, produced by `tools/make_barn_corner.gd` (mirrors the intact left corner).
Vegetation is cleared within 13 m of every barn via `MudTerrain.activity_clearing`.
