# 2067: HORNFALL

In 2031 the Xhuul arrived over Las Vegas promising cures, cold fusion and free
Wi-Fi forever. Clause 9,112 of their terms of service let them "get to know"
Earth's wildlife. They got to know ALL of it. By 2034 a Nebraska farmer had
live-streamed it, Congress declared war in eleven minutes (Operation Freedom
Moo), and three years later the nukes flew. The Xhuul had shields. Earth
didn't.

It's 2067. The Xhuul won and kept the planet as a nature reserve for the
hybrids they made. You've got your grandpa's farm, your grandpa's rifle, and
Dale. Hunt the mutated hybrids, sell their magnificent horns to the aliens
who ended the world, and use the money to keep the ghouls off your farm,
because something keeps drawing them to you.

Built in **Godot 4.7** with the **Forward+** renderer (real-time GI on Ultra,
volumetric fog, SSAO/SSIL, soft shadows). Low/Medium/High/Ultra presets, FSR
render scaling, and an automatic OpenGL fallback so it runs on laptops and
integrated graphics. Full controller support.

## The hunt

- **Thirteen hybrids**, every one grown procedurally from its species and its
  own seed: Moorhorn (cattle), Stagwraith (deer), Tuskmaw (boar), Ramspire
  (bighorn), Crownelk (moose), Tigrath (tiger), Ursagore (bear with ram
  horns), Mammothar (elephant), Rhinox (three-horned rhino), Girafflux
  (giraffe with a crystal crown), Leonix (lion with a crystal-quill mane),
  Howler packs (wolves that hunt you at night), and the legendary
  two-hearted **Ironcrown** of the crash basin.
- **Dale**, your hunting buddy, follows you, spots game and calls it out,
  roasts your missed shots, shoots ghouls and carries two trophies.
- **Farm defense**: a wall, turrets, floodlights, spikes, and (once **Xyla**,
  a Xhuul exile, joins you at rank 5) Tesla towers and a shield dome. Ghoul
  raids come every few nights and grow with your rank, your farm and the
  horns on your wall.
- **The intro**: 2031 to 2067 as a cinematic, from the ships over Vegas to
  the bombs.
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

Keyboard: WASD move · Shift sprint · Ctrl crouch · Space jump · RMB aim ·
LMB fire · R reload · Shift (scoped) hold breath · wheel zoom · B binoculars ·
1-6 or X guns · E use / hold to harvest · F flashlight · Q caller · V scent ·
C cloak · G drone · T thermal · M map (fast travel) · J journal · F1 guide ·
Esc pause

Controller: left stick move · right stick look · LT aim · RT fire · LB hold
breath · RB next gun · A jump · B crouch · X use / hold to harvest · Y reload ·
D-pad: binoculars, light, caller, scent (up/down zoom while scoped) · R3
thermal · LB+B cloak · LB+A drone · L3 sprint · Back map · Start pause

## Running

Open the folder in Godot 4.7 and press Play, or run
`godot --path .`. Tests: `godot --headless --path . res://test/check.tscn`
(compiles every script) and `res://test/hunt_test.tscn` (gameplay).
