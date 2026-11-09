# Rules (R-nn)

What holds now. Per rule only `Rule:` and `Source:`. Ids never change; a merged rule names the ids it took in its title.
Add with `tools/knowledge/learn.py rule`. Full wording before 2026-11-04: archief/knowledge-2026-11-04/.

## World shape

### R-01 Hoenn is a staircase of plateaus
Rule: every outdoor map is flat plateaus one course (sometimes two) apart, from 0 at the water or map edge; never a 0 floor with isolated spikes, never a jump of 3+ courses unless Petya drew one. Sea rocks stand 1/2/3 by footprint.
Source: Petya 2026-10-27: "cant you see that the worlds are built out of a bunch of plateaus?"

### R-02 Classify every cell first, build second (takes R-03, R-15)
Rule: on a pinned map every cell is PLATEAU (at its number; trees and props stand on it), FACE (unnumbered band between two plateaus: top = upper, foot = lower), MASS (numbered rock, top = its number), WATER, DECK or BORDER. No unclassified rock.
Source: Petya 2026-10-27: "we NEED to make sure we do everything per platform and not just gung-ho build rocks everywhere."

### R-05 Rock tops are flat (takes R-20)
Rule: a numbered mass is a flat-topped block at its number; no rounded, ridged or profile tops on a pinned map. Unpinned maps and caves: rounded shoulders stay small.
Source: Petya 2026-10-27: "the tops of all those rocks are flat!"; 2026-10-14: "its not a bouncy castle".

### R-07 One course = 16 px everywhere
Rule: one drawn course is 16 px of height in every builder (Gen3Elevation.PIN_PX, Gen3Rock.COURSE).
Source: Petya 2026-10-27: "if a tile is 16x16px lets do 16px height as well".

### R-08 More depth than the flat original, from the object's own pixels (takes R-19)
Rule: props, furniture and structures get believable 3D depth by repeating their own pixels (never stretched, no invented colours). PCs and TVs are CRT tube sets, depth about 4/5 of the width. Terrain heights come from the pins (R-10).
Source: Petya 2026-10-05: "we must introduce more depth since we are making it 3d, the OG was super flat"; 2026-10-06: tube sets "a bit more like a cube".

### R-09 Same world as the original, in 3D
Rule: the 3D need not match the 2D pixel for pixel but must read as the same world; pixel checks find faults (scrambled rows, missing or doubled parts, wrong placement), they are not the goal.
Source: Petya 2026-10-13: "it doesnt need to be exactly like the og but it does [need] to be aesthetically in the same world as the og but in 3d".

### R-33 Never a slope on grass or sand
Rule: grass and sand are always flat; a level change happens only at a rock ledge or a stair. A bare drop between grass cells in the pins is a rock ledge, or the pins are wrong.
Source: Petya 2026-10-28: "there are never 45 degree ridges or plateau differences on grass or sand! never. only rock ledges or stairs do that".

### R-35 Rock ledges ring the whole plateau, hidden edges included
Rule: every plateau edge is a 45-degree ledge (R-38), also where the top-down art hides it (north rims drawn as a line, behind a boulder, under a tree row): the lower plain cell becomes the wedge in the nearest band's face art; where it cannot (tree, tall grass, stair) the riser is rock face art.
Source: Petya 2026-10-28: "elevating rocks are on a 45 degree angle, they are all around the platform".

### R-38 No vertical rock walls: every drop is a 45-degree slope (takes R-04, R-06, R-34, R-37, R-41, R-ridge-slope)
Rule: every drop between rock or plateau levels, any height, tileset, outdoors, in caves (lit rim = up side) and underwater, is a 45-degree slope. Each band, ledge or stair tile is a wedge (a cube cut by its diagonal, one course per tile); consecutive tiles stack into one slant (N rows = N courses); a convex corner is a quarter cone, an inside corner the inverse cone; where the art has fewer rows than courses the wedges continue over the lower cells (R-35). Stairs too: never a vertical step or a flat deck with a riser; equal pins at both ends = flat deck.
Source: Petya 2026-10-27: ridges go "almost 45 degrees until the top ... They dont go up 90 degrees at all"; 2026-10-28: "stairs also adhere to the 45 degree principle"; 2026-11-01: "there are actually no stacked vertical walls in the game, its always a 45 degree slope", "alle richel tiles in de hele game op 45 graden zetten. ook als ze stacken".

### R-40 Jump ledges are a small ramp
Rule: a one-way jump ledge is a low wedge: a long gentle slope up to the lip, a short steep face on the jump side (sketch docs/aanwijzingen/richel-schets-zijaanzicht.webp).
Source: Petya 2026-11-01: "ze moeten meer als een kleine ramp zijn".

### R-42 A tile drawn on a wall belongs to the wall; height only at ledges and stairs
Rule: art on a rock wall in the 2D (secret-base square 0x33B/0x33C, a dark cave mouth) takes the wall's height and slope; a black entrance is a black hole with rock on top; a grey stair is always a real 45-degree stair. Height changes ONLY at a rock ledge tile (one block of rise) or a stair: a ledge with no rise beside it, or a rise without a ledge, is a height-data bug (fix the pins/field).
Source: Petya 2026-11-01 (Route 116 screenshots): "dat is de fucking regel".

## Heights and water

### R-10 Terrain heights are hand-drawn by Petya, per map (takes R-11, R-12)
Rule: the cartridge has no heights; Petya draws one number per flat area on the draw sheets (docs/elevation, local only), baked into mod/lib/Gen3PinData.lua; relative to the map's own 0, water 0, one offset at a seam; the pins beat the 2D's course count. Reading: a loop = 0, a struck 2 = 7, a comma = decimal, `^ up` = stair arrow, a number under a tree = the ground there, on a rock = its top, `top` = ledge top. Read marks from the PNG on disk at full size; never regenerate the draw sheets.
Source: Petya 2026-10-27: "just skip the proposal sheets. im just gonna do everything by hand."

### R-13 Water is 0, waterfalls go straight up, bridges are flat (takes R-14)
Rule: water stands at 0 in its map (a pool above a waterfall may carry its own number); a waterfall is a vertical sheet, never a ramp, its tiles take the highest water beside them. A number on a bridge is the deck height, the cells under it are water, the deck runs flat bank to bank; runs between two equal numbers are flat.
Source: Petya 2026-10-27: "the area UNDER a bridge is obviously WATER and should be the same height as the water around it"; waterfalls "always go straight up, 90 degrees, never on a slant".

### R-16 Height fixes go in the field, never in c.base
Rule: Scene.groundAt (player, NPCs, camera) reads the floor field, so shifting c.base lowers the drawing and leaves actors floating; per-map shifts go in the Gen3Elevation field. Check c.base and groundAt for a few cells with a driver.
Source: Petya 2026-10-26, Mossdeep "1 block too high" (first fix looked right, actors floated).

### R-18 Walk-under structures stay walk-under
Rule: before flattening or raising an over-layer piece drawn across a path, check whether the path continues under it (Ever Grande gates are arches).
Source: Petya 2026-10-07: "arches where you walk through underneath".

### R-21 Beyond the map edge: the border tile's family, never green steps
Rule: off-map fill follows the nearest edge cell's family (forest/mountain/water) or the map's border block, continuing the edge heights; a rim of flat rock over sea gets sea at 0 (Gen3Boundary M.SEA). Check which cells are border cells before judging a shot.
Source: Petya 2026-10-27 (Sootopolis): crater rock or nothing, never green steps.

### R-47 A map without a drawing gets pins from its own art
Rule: when Petya has not drawn a map, Claude sets its pins: ground 0, each band or stair row one course (R-38), seam heights copied from the neighbour's pins, a pond on a plateau at the plateau's height. One pin per enclosed area (the GBA level often does not tell a plateau from the ground); stairs 0xAF/0xCF/0xE8 stop the flood.
Source: Petya 2026-11-02 on Safari Zone Southwest (pins 0ea2e44): "wat je hebt gedaan bij safarizone is echt perfect"

### R-48 Drawn arrows are 45-degree wedges
Rule: on a map with a drawn height map (data/gen3_heightmaps.lua, baked by tools/heightmaps.py from docs/elevation/draw/claude_heightmaps) each ramp tile's arrow is the direction it rises at 45 degrees, one course per tile, from the floor behind to the floor ahead; a diagonal arrow is a corner (inner = inverse cone, outer = quarter cone). The arrows replace Gen3Blocks' own ramp guessing there; floor heights come from the map, not a pin flood.
Source: Petya 2026-11-02: "die pijlen geven aan in welke richting de tile omhoog gaat met 45 graden!!!"

## Checking

### R-22 Judge from three cameras and from behind, against the 2D art
Rule: before installing, look at the play camera (level 4, zoom -2), the low camera (6) and the orbit camera (7) at several yaws, including the back of objects, beside the original 2D crop.
Source: Petya 2026-10-05: "check in 3D from all angles, also the back".

### R-23 QA must match Petya's game
Rule: capture with QA_ZOOM=-2, sceneryProps "modeled", daytime, tilt 2, tour=true and camera 7 (L-65), and wait for the full build (tools/qa_tryp.sh copies the QA options); rerun a run with unexpected fallbacks before judging.
Source: Petya 2026-10-14 (Routes 104-115 walk: the shots did not match the game).

### R-27 QA runs are batched; never start the game by hand
Rule: every check goes in one tools/qa_tryp.sh call (boot ~8 s, a shot ~1 s), at most 3 runs at once; never start the game binary directly and never `pkill -x love` (kills Petya's game).
Source: Petya 2026-10-06 (asked all agents to batch).

### R-28 Check rock placement with the ortho-45 overlay
Rule: before judging a rock change, render the 3D from the 2D's own angle beside the art (tools/drivers/em_ortho_driver.lua + tools/ortho45) and look where bands and tops sit; then the play camera.
Source: the fix after "the stones are in completely different places. completely mangled." (Petya 2026-10-27).

### R-29 Measure what draws it; never guess from the picture (takes R-17)
Rule: when the cause is unclear, measure first: dump the height field for the cells (a wrong pin is the usual cause), probe which code draws the quads, log the actors; then change a builder.
Source: Petya 2026-10-14: "you need to recheck the height map"; an hour lost on Petalburg Woods' "floating object" (2026-10-13).

## Workflow

### R-39 One mod: fix what Petya points at, install with tools/install.sh (takes R-26)
Rule: mod/ is the only mod and all its code is Petya's. Petya names one wrong thing; fix it in mod/, test with tools/qa_tryp.sh, show before/after, commit, install with tools/install.sh (game closed). Install QA-checked work without asking; push main every few commits; never push ROM-derived files.
Source: Petya 2026-11-01: "de oude code mag gewoon gebruikt worden. ik wil gewoon dat het werkt"; 2026-10-05: "you can install your work, we can always refine".

### R-43 Fixes are game-wide tile rules, never per-route code
Rule: write every fix as a rule for a kind of tile or terrain that holds in the whole game, never `if map == X` nor per house or ledge; per-map DATA the 2D lacks (pins) is fine, per-map CODE is not.
Source: Petya 2026-11-01: "ik wil juist meer algemene regels hebben voor tiles. dus dat we niet per route allemaal weirde stukjes code hebben".

### R-44 Emerald only
Rule: code, tests, docs and assets that only serve other games (Gen 1/2, FireRed/LeafGreen, other ports) go; code Emerald runs stays even if named Gen2/FireRed. Battles: only Gen 3 sprites, plus Stadium 2 and Colosseum models. Applies to the bundled wilds and importer too.
Source: Petya 2026-11-01: "even get rid of any fire red leaf green code. this is only for emerald!"; 2026-11-02: "haal alle sprites er uit behalve gen 3"; 2026-11-04: "get rid of anything that Emerald or our mod doesn't use".

### R-45 Short code
Rule: lib/ around 30k lines. Comments only where essential, one short line (why or trap), no history or dates. Anything Emerald never calls may go without asking, but measure "never called" first (tools/deadcode, tools/probe_main.lua).
Source: Petya 2026-11-02: "ik vind 56k lines of code echt veel", "haal de comments weg en hou ze alleen als ze essentieel zijn! en verkort ze"; 2026-11-01: "anything emerald doesnt call can go".

### R-46 One system per job: the new one replaces the old in the same change
Rule: when a new builder, tool or note takes over a job, the old one goes in the same change; never stack a second system next to the first. Before building, check whether one exists (docs/dubbel-werk.md) and extend it.
Source: Petya 2026-11-02: "ik heb het gevoel dat we heel vaak dezelfde shit hebben geprobeerd en opgeschreven"; "precies bij rots trap en bomen veel werk ... veel parallelle dingen".

### R-49 Uiteinden van rotsrijen zijn rond
Rule: een helling met lage vloer aan de ene zijkant en rots aan de andere is een kwart-kegel om de hoge hoek aan de rotskant, geen rechte wig met puntige zijkant (Gen3Blocks roundEnd).
Source: Petya 2026-11-02: hoekjes van stenen zijn in de game rond

### R-50 Een deur in een grotwand staat er een keer
Rule: een grotdeur is twee tegels: de boog (rechtop in de wand, een laag hoog, rotswand erboven, donkere vloer binnenin) en de drempel op de vloer; de boog nooit dubbel of per laag herhaald (Gen3Blocks door).
Source: Petya 2026-11-02, Seafloor Cavern kamer 1: 'die moet nooit dubbel zijn', 'hij bestaat eigenlijk uit twee tiles'

### R-51 Losse stenen zijn ronde keien
Rule: een steentegel uit Gen3Blocks.STONES (vaste lijst per tegelset, met de hand nagekeken) in een groep van hooguit 2x2 op vlakke vloer wordt een koepel (Gen3Mass), geen blok. Nooit zoeken op vorm of kleur: dat pakt rotsranden mee.
Source: Petya 2026-11-03: 'alle steen tiles een (vaak ronde) 3d vorm'; over de automatische lijst: 'het grootste gedeelte ... zijn dat niet'

## Hoogtekaarten

### R-52 Hoogtekaarten lezen: Petya's inkt
Rule: rode pijl op een tegel = de kant waar die tegel omhoog gaat (pijlpunt = hoog); schuine pijl = hoekhelling. Zijbanden van bergen zijn vaak schuin. Kleine rotsjes met pijlen naar het midden = piramide (hoektegels naar de top, top 1). Een verticale streep '|' = het cijfer 1. Een omkaderd vlak = dat hele vlak heeft het getal erin. Een streep door een oud getal = doorgestreept. Tel bij twijfel de wanden: 1 wandtegel = 1 hoogte; oude inkt kan een verschrijving zijn (Mt Pyre plein 16 was 19).
Source: Petya 2026-11-03: "ik hoop dat je er ook van leert" / "meeste suggesties die je had klopten"

## Wilds

### R-53 Town Pokemon stay on and are Gen 1-3
Rule: Option town_pokemon defaults to on. Hoenn towns (3 each), houses and Pokemon Centers (2 each, town pool + home pool) get peaceful Gen 1-3 species from mod/wilds/data/town_pokemon.lua (national dex numbers, small or medium ones only). No Kanto leftovers, none in Trick House rooms. Never switch the option off in the game or the trailer to hide a bad species list: fix the list.
Source: Petya 2026-11-09: "I actually want the town pokemon on! and also to have them be from gen 1-3"
