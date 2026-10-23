# Visible vegetation wind

Small imported grass variants are only 6–20 cm high before their 2–4× forest
instance scale. The former shared 0.8 m normalization suppressed their tip
weights; world-to-local conversion also discarded instance scale from the
bend amplitude. This left many blades moving by fractions of a millimetre.

Materials now use each variant's actual LOD0 root/top bounds, consistently
across its LODs and surfaces. World-height-scaled bending, root anchoring,
species-specific response and separate blade/leaf flutter replace the common
height assumption. Trees keep stiff bases. Dead wood remains rigid. Culling
margins include the displaced canopy/blades; placement, RNG, collisions,
textures, alpha thresholds and LOD distances are unchanged. No per-frame forest
instance transforms are rewritten. The existing shared wind clock/strength,
night breeze and speed-independent environmental audio are retained.

Validation: macOS / Godot 4.7.2 headless, vegetation_wind_test (862 checks) and
recovery_effects_test pass. Material/geometry tests verify real imported asset
coverage, variant-height normalization, LOD agreement and clock propagation.
They do not execute GPU vertex deformation or certify visual appearance/FPS.

Use Play-Offroad.command in the updated checkout. A separate Desktop checkout
was observed at 5ca86d7 with no WindField wiring; a GitHub push alone does not
update that local copy. Close the previous game before launching the new build.
