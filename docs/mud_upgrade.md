# Mud, nature audio, GPS and lamps

The current version adds original approximations of off-road soil mechanics;
no MudRunner/SnowRunner game code or assets were used.

## Try it

Launch `Play-Offroad.command`. I starts the engine, W/S drives, Q selects low
range, E toggles available AWD, F toggles the available differential lock, and
T changes tires. M expands the bottom-left GPS; N changes day/night and L
cycles headlamp modes. The brown circles on the GPS mark three swamps near
X/Z -365/-425, -318/-230 and -270/22 along the valley shortcut.

Repeated stationary wheelspin digs faster than rolling. Narrow highway tires
sink more readily; mud tires, AWD and low range help. Deep ruts can leave the
chassis supported by soil with the wheels unable to pull the car free. This
is a heightfield and resistance approximation, not a fluid/soil solver or a
reproduction of Saber physics. Shallow swamp water is visual, without buoyancy.
Ruts are cached during the session (256 tiles), not saved between launches.

Real field recordings replace synthetic wildlife: forest, dawn birds, night
insects, a spatial tawny owl and nearby water. Day/night fades and altitude/water
proximity vary their mix. Engine and tire effects remain procedural. All nature
recordings are CC0; authors and source links are in `assets/audio/CREDITS.md`.

The Jeep's actual square lens faces now glow. Imported car spotlight anchors
use transformed lens bounds and the front surface, rather than node origins.
The two spotlights share those positions and cast shadows. Box truck lamps
retain their explicit lens geometry.

## Checked on this host

- Soil grip/load/slip invariants, narrow ruts, asphalt protection, shared fine
  collider edges, weather propagation and restoration of cached ruts.
- Vehicle support dropped approximately 0.38 m into dug soil; the underfloor prevented falling
  through the map. The burial meter remained active after bottoming out.
- Clods emit for wet rotating wheels, stop on dry/stationary contacts and hit soil.
- Imported Jeep/Niva/2106/2107 lens glow and spotlight positions; mode switching.
- Niva/2106/2107 wheel alignment at rest, four-wheel contact and driving;
  acceleration is checked separately because it extends the front suspension.
- Scout road acceleration reached 50 km/h in the existing 6-second test.
- Recorded streams decode/loop; engine pitch, start/stop and impacts still work.

Headless checks cannot establish appearance, audible balance, driving feel or
Metal GPU frame rate. The first nine detailed patches took about 110 ms to build
on this host; moving the window may cause brief frame-time spikes. Visible Mac
playtesting remains necessary before calling the result production-ready.
