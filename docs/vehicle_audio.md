# Vehicle instruments and recorded audio

The first six vehicles have individual powertrains in `vehicle_dynamics.gd`.
The values are prototype tuning, not certified factory specifications.
Quadratic aerodynamic drag replaces the old large hidden linear speed damping.

| Vehicle | Idle / limit RPM | Gears | Target KM/H | Peak torque Nm |
| --- | --- | --- | --- | --- |
| Skaut | 720 / 5600 | 5 | 135 | 340 |
| Yük maşını | 650 / 3200 | 6 | 100 | 650 |
| Ağır tır | 600 / 2600 | 8 | 85 | 1250 |
| Lada Niva | 850 / 6000 | 5 | 130 | 140 |

Top speeds are propulsion cutoff targets, not measured performance claims.
Body velocity is never clamped: downhill momentum, sliding and mud still use
Godot physics. Gear-specific wheel RPM drives the tachometer, shifting unloads
the drivetrain, and a time-based throttle response distinguishes heavy diesels
from passenger cars. Existing wheel geometry, suspension and contact handling
remain in use. Low range multiplies the selected gearbox; AWD/differential and
all controls remain available. Previously added UAZs remain selectable.

The lower-right instrument panel shows horizontal ground speed in KM/H (falling
vertically cannot inflate road speed), RPM, current gear/shift, fuel, AWD,
differential, range, tire selection and mud. Dial scales follow the vehicle.
The lower-left GPS remains separate.

## Actual recordings

Six different source recordings feed eighteen prepared idle/rev/load WAVs.
Cargo uses an additional Iveco acceleration recording for its upper layers.
All recordings are freely downloadable from BigSoundBank; source links are in
`CREDITS.md` and `assets/audio/engines/SOURCES.json`. Files are prepared offline
with `tools/prepare_engine_audio.py` (numpy/ffmpeg), DC removed, level matched,
and circularly crossfaded. Playback uses continuous loops, constant-power layer
mixing, RPM band pitch adjustment, throttle/grade/mud load and shift ducking.
Starting/stopping uses recorded AC Cobra/Peugeot excerpts as disclosed effects.
Gravel rolling uses MTB foley; liquid mud uses footsteps. Tire hiss, wind,
collision thuds and mechanical UI/shift cues remain synthesized effects.

These are **substitutes**, never authentic Skaut/Jeep/Lada recordings. In
particular the short retro-car captures do not contain a dedicated idle, and
the Peugeot/truck captures are mostly steady RPM. Their idle/rev/load layers
are edited sound design; the reference RPMs are playback estimates. Genuine
vehicle-specific start/idle/rev/load capture sets remain missing. The UAZs use
the disclosed Skaut substitute without claiming to be another recorded vehicle.

Automated tests verify sample loading, loop boundaries, mixing, pitch response,
engine stop, gear ducking, real four-wheel contacts, acceleration and automatic
shifts. Headless tests cannot establish listening quality, perfect audible loop
seams, visual polish under Metal, or achieved real-world top speeds. Those need
a normal game session and further tuning.


## Automated run, 23 October 2026

All four vehicles maintained four initial wheel contacts and accelerated for
12 seconds on the same flat collider: Skaut 107.8, cargo 86.5, heavy 79.0,
Niva 87.1 KM/H. These are simulated test results,
not real-car measurements or achieved maximum speeds. The tests also exercised
braking, reverse, shift events and propulsion cutoffs without clamping velocity.

The 24 bundled WAVs total 6.9 MB; their hashes and decode checks pass. PCM
import sidecars are intentionally versioned for reliable frame-count loops.
Existing audio/environment, Lada driving, menu, 14 surface checks, mud sinking,
95 Hill Climb assertions, full-scene Hill Climb integration and Jeep alignment
checks pass. The corrupt-save Hill test intentionally logs a ConfigFile parse
error and verifies that the damaged save is not overwritten. It is not a
missing resource. Editor settings cannot be written outside the sandbox;
project imports and headless runtime still complete.
