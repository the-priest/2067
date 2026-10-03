# 2067: HORNFALL

A post-apocalyptic hunting game. Twenty years ago the Visitors' fleet fell
out of the sky over the valley. They didn't die. They bred with the herds.
You're a farmer on what's left of your grandfather's homestead, and the only
thing worth money anymore is what walks out of the ash: alien-animal hybrids
with hides worth trading and horns worth hanging on a wall.

Built in **Godot 4.7** with the **Forward+** renderer (real-time GI on Ultra,
volumetric fog, SSAO/SSIL, soft shadows). Low/Medium/High/Ultra presets, FSR
render scaling, and an automatic OpenGL fallback so it runs on laptops and
integrated graphics.

## The hunt

- **Seven hybrids**, every one grown procedurally from its species and its
  own seed: Moorhorn (cattle), Stagwraith (deer), Tuskmaw (boar), Ramspire
  (bighorn), Crownelk (moose), Howler packs (wolves that hunt you at night),
  and the legendary two-hearted **Ironcrown** of the crash basin.
- **Every heart is somewhere different.** No two animals keep it in the same
  spot. Put a round through it and the animal runs a few seconds and drops: a
  clean kill and a whole hide. Lungs, gut, spine and brain all behave
  differently, and wounded animals leave a glowing blood trail you can track.
- **Real ballistics**: bullet drop, travel time, zeroed at 100 m. Scopes,
  breath holding, rangefinding.
- **Senses**: hybrids see movement, hear footsteps, and smell you when the
  wind carries your scent to them. Crouch, watch the wind gauge, use cover.
- **Harvest** hides (graded Pristine to Ruined by every hole you put in them)
  and **horns**: each set grown from the animal's seed and scored Bronze,
  Silver, Gold, Diamond or Mythic. Sell them or mount the real thing on your
  farmhouse trophy wall.
- **Progression**: from Grandpa's .30-30 lever gun to a ranch .308, the
  Thumper .45-70, then salvaged Visitor tech: the near-silent Whisper Coil
  Rifle, the Helix Plasma Lance and the Skypiercer Rail. Gear: rangefinder,
  wind gauge, Bio-Tracker visor, heart scanners Mk I-III, thermal optic,
  hybrid caller, scent mask, phase cloak, recon drone, bigger packs.
- **The valley**: 2 km of farmland, dead forest, badlands, the northern
  ridges, a lake and marsh, and the mothership broken across the crash basin.
  Escape pods to salvage. A full day/night cycle under the wreckage ring.
- **Mae** on the trading net guides you through it, and her contract board
  always wants something.

## Controls

WASD move · Shift sprint · Ctrl crouch · Space jump · RMB aim · LMB fire ·
R reload · Shift (scoped) hold breath · wheel zoom · B binoculars · 1-6 guns ·
E use / hold to harvest · F flashlight · Q caller · V scent mask · C cloak ·
G drone · T thermal · M map · J journal · F1 field guide · Esc pause

## Running

Open the folder in Godot 4.7 and press Play, or run
`godot --path .`. Tests: `godot --headless --path . res://test/check.tscn`
(compiles every script) and `res://test/hunt_test.tscn` (gameplay).
