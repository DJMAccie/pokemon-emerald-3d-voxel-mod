# Lessons (L-nn)

Mistakes that cost a round, and still apply. Per lesson `Cause:`, `Fix:` and optionally `Rules:`. Ids never change (gaps are
retired lessons). Add with `tools/knowledge/learn.py lesson`. Full wording before 2026-11-04: archief/knowledge-2026-11-04/.

### L-05 Scene cells keep the kind under c.shape.kind
Cause: cache cells have no c.kind; a test on it never matches, so before and after look identical.
Fix: read c.shape.kind; identical before/after shots mean the test is wrong, not the fix.

### L-06 A capture run can fall back to 2D without the change being wrong
Cause: transient QA-copy state; dark Flash caves always fall back in QA; a trainer spotting the player or an entry dialog drops all later cases of the run to 2D; a new local named `Objects` in Gen3Scene shadows the NPC module.
Fix: treat a run with unexpected fallbacks as void and rerun; check `active true` counts in run.log; quiet spots, one map per run when in doubt.
Rules: R-23

### L-07 A dark slab beside tall rock on water is its shadow
Cause: the shadow map moves shadows west and north with height (ShadowMap.KX/KZ), so a rim's shadow on water looks like a flat riser.
Fix: look from the far side with the low camera before "fixing" a face.

### L-14 pairs() order is random per run
Cause: LuaJIT randomises pairs() over string-keyed tables per process, so floods and groupings over cells["x:y"] changed from load to load.
Fix: make every flood or grouping order-independent; two dumps of the same code must be identical.

### L-16 zsh and macOS gotchas
Cause: the tool shell is zsh: no export -f, a word starting with `=` expands, unquoted $VAR does not split (use ${=VAR} or an array), an unquoted `--include=*.md` is a glob error; macOS has sed -i '' and no `timeout`; Pillow is in user site-packages.
Fix: quote globs, put parallel workers in a script file, run the image tools with python3 without -I.

### L-19 A tall object appears north of where it stands
Cause: a tall object projects north over the cells behind it on screen (Petalburg Woods: the exit tile stood up south of the player).
Fix: find the drawing cell with a probe (quads above a height in a box) and trust its cells, not the picture.
Rules: R-29

### L-42 A local defined below its caller is a nil global
Cause: a `local function` declared after its caller is a global lookup there (nil at run time); the unit tests never load the draw path, so they pass.
Fix: forward-declare the local above its caller; the smoke test for the draw path is a QA run's log (fallback 0).

### L-43 Measure the layer before fixing the guess; warm QA before comparing
Cause: a cost guess was wrong (allocations in VoxelHull.build, not texture uploads); the first run of a QA copy is ~1.6x slower.
Fix: time the layer in parts before choosing a fix; run before and after the same day with the same probe and discard the first run.
Rules: R-29

### L-44 Bench two Lua modules in separate processes
Cause: two versions of hot code in one LuaJIT process share the trace cache, and machine load swings a reading 2-3x.
Fix: one module per process, three runs each, keep the best.

### L-49 The mod sandbox hides debug, os.getenv and plain require
Cause: lib/ modules run in a sandbox: `debug` is nil (debug.traceback -> scene fallback), os.getenv sees nothing the QA command sets, a plain `require` of a mod module never resolves. Drivers (EM_DRIVER) do have `debug`.
Fix: load mod modules with V.require, use a module flag (M.log=true) for diagnostics, put hooks in a driver or tools/probe_main.lua.

### L-50 dead.py counts by name, so common names look used
Cause: tools/deadcode/dead.py counts any `.update` or `.apply` anywhere as a use of every module's `update`/`apply`; it also counts tests as users, so test-only helpers look alive.
Fix: tools/deadcode/deadq.py counts `M.f` only through aliases of M; grep qualified (`Name\.update`); check tests/ before calling a function dead.
Rules: R-45

### L-51 Too many QA runs or background shells vanish silently
Cause: more than ~4 waiting tools/qa_tryp.sh runs drop out without a run.log; a Bash run_in_background task dies after ~2 min.
Fix: at most 3 runs at once (xargs -P3); start long sweeps with nohup and wait with Monitor.
Rules: R-27

### L-53 Rocks are a per-cell priority chain, not stacked systems
Cause: Gen3Scene picks ONE rock system per cell: cave wall -> Gen3Cave, c.blocks -> Gen3Blocks, else Gen3Mass or Gen3Terrain -> Gen3Rock -> Hills; on pinned maps Blocks takes almost every rock cell.
Fix: count cells per system before merging or removing one (docs/dubbel-werk.md).
Rules: R-46

### L-54 A QA shot can catch the whole-area build half done
Cause: qa_tryp shoots ~80 frames after the 3D turns on; the whole area finishes around frame 50-100, so a shot can show only the near part and look like a regression.
Fix: rerun with wait 300 or compare two base runs before calling a missing area a regression; measure with S.streaming (completed/buildMs).
Rules: R-23,R-29

### L-55 Same source can give different LuaJIT bytecode
Cause: luajit -bs output depends on hash order for some files (stadium2 pack.lua, battle_fx_runtime.lua), so 'bytecode equal' cannot prove a comment-only edit.
Fix: prove comment-only edits with git diff -U0 (no changed line outside '--' comments) plus the test suite.
Rules: R-29

### L-56 A pcall-wrapped data load fails silently
Cause: Gen3Relief and Gen3Elevation loaded tables in pcall(V.require,...): a wrong name or path turns the feature off with 0 fallback and no error.
Fix: after moving or renaming a data file, compare QA pixels on maps that use it (two base runs + new); drop the pcall when the file always ships.
Rules: R-29

### L-57 Recipe tables can name tilesets Emerald does not have
Cause: data/gen3_stairs.lua had 55 of 57 recipes for pairs Emerald lacks (player_house, house, *rom_082d*); static greps on module names missed it.
Fix: check every pair name in a table against the native manifest (~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba/native/manifest.lua); mind labels the mod sets itself (InteriorDiorama gives the Abandoned Ship secondary 'rom_082d4d94').
Rules: R-44

### L-58 Another session commits your staged files
Cause: two sessions in one checkout: `git add -A` or `commit -a` takes the other's staged files (also git rm/git mv stage). Happened twice (63e4710, 0cf0897). The mod/ tree may hold another party's uncommitted work.
Fix: stage nothing for later (use rm/mv); commit only your own paths: git commit -m ... -- <paths>; check git status before and never add or install what you did not change.

### L-59 Pinned caves: black holes and domes after pinning
Cause: Gen3Scene caveWall/rock draw branches skip Gen3Blocks.append, and Mass.prepare runs after Blocks.prepare so Mass still drew domes.
Fix: branch (caveWall|rock + c.blocks -> Blocks.append) and mass.blocksOwned on pinned caves.

### L-60 Mod settings live only under MODS, not in the options menu
Cause: engine 0.3.99: the Emerald options menu builds its rows locally, so a mod replacing Rows.build never shows; only the ui.options.rows hook works (the Stadium 2 ROM line).
Fix: look at what Petya sees: MODS -> Emerald 3D Voxel Mod -> options = the mod.options:define schema; read it with a driver (ModManager.show + openOptions, print m.optionRows).

### L-61 Odd-sized maps are padded by one row or column
Cause: native_pack pads an odd side to even by repeating the last row/column, so l.width/l.height can be one more than the art (Granite Cave 1F 42x15 vs 42x16); an exact size check silently skipped 72 of 96 height maps.
Fix: compare per-cell data to the true size and clamp x,y to the last row/column (Gen3Elevation height-map branch, Gen3Blocks.arrowRamps).
Rules: R-29

### L-62 Cave bridges and stairs under a drawn height map
Cause: Victory Road bridge cells (layer 15 plus end caps, collision 43) got ramp arrows and pins and became boxes; Scene.isDeck refused collision 43; cave stair metatile 0x204 (elev 0) was no step. Dark caves also fall back to 2D in QA.
Fix: a layer-15 run plus its end caps stays a deck (no pin, no arrow); isDeck accepts layer 15 with collision 0 or >7; general__cave 0x204 is a step (PAIR_STEP_MIDS); QA drivers take EM_NODARK=1.
Rules: R-13,R-18,R-43

### L-63 QA shots are dark at night and qa_tryp wipes *.png in the outdir
Cause: the game follows the real clock (DayNight.hours); qa_tryp does rm *.png in the outdir.
Fix: daylight: a QA_SRC copy of DayNight.lua with 'do return 12 end'; low camera: a copy of em_views_driver.lua with C.pitch=EM_PITCH; keep reference shots outside the outdir.

### L-64 Counting the ink led to errors
Cause: agents took Petya's numbers as sacred even where the walls said otherwise (Route 103 1 vs 3, Mt Pyre 16 vs 19, Safari North 1 vs 5), and read side bands as straight slopes.
Fix: put doubtful spots to Petya as a crop (heights over the screenshot); follow the wall count if he does not know; slanted bands and pyramid rocks follow his arrows.
Rules: R-48

### L-65 QA without tour and camera 7 misses Petya's faults
Cause: Petya plays with tour=true and camera 7; QA ran without tour at level 4, so 2D flashes and missing neighbour maps did not show.
Fix: reproduce with EM_TOUR=1 and level 7 (em_views_driver, em_cross_driver); read modOptions in his options.lua.
Rules: R-23

### L-66 A mod folder must not use assets/generated
Cause: assets/generated is where the engine keeps the player's ROM-derived cache; modkit lint MK301 (and the community mod index CI) fail any mod shipping files there, and any lib file naming that path.
Fix: Ship art under another folder such as assets/water_runtime and run: python3 gen1recomp/tools/modkit.py lint <mod folder> and validate <mod folder> --strict for the mod.

### L-67 A mod's version must equal the release tag's x.y.z
Cause: The launcher updater and the mod index take a mod's latest version from the release tag (v0.1.0-alpha becomes 0.1.0) and compare it with the installed manifest version. 0.1.0-alpha sorts below 0.1.0, and 0.23.0 or 2.4.3 never trail a 0.1.x tag, so updates loop or never come.
Fix: Keep manifest.json, MOD_BUILD in mod/models/main.lua and exports.version in mod/wilds/main.lua at the release x.y.z; put alpha only in the tag and the GitHub prerelease flag; attach the one emerald_3d_voxel_mod-<x.y.z>.zip to the release (tools/build_release.sh).

### L-68 Fortree treehouse 'pillars' were cliff cells, not model strips
Cause: Tiles 0x22C/0x22E/0x234/0x236 beside each hut door classify as kind=cliff, so the scene drew rock-band pillars next to the model; deleting the model's own post strips did not remove them (found with scene.debugRaw via a probe driver)
Fix: Model flag flatten=true in BuildingVoxels.place turns claimed cliff cells into the model's flat shape; keepTrees=true keeps claimed tree cells (leaf-corner tiles) out of the bush-tree pass

### L-69 Fortree palm crown must sit over the trunk and use its own bark
Cause: The crown was centred on its own tile one cell north of the trunk (looked bent backwards) and the trunk sampled whole tile columns, which include the bush art beside the bark
Fix: Gen3Fortree.palmCrown centres on the trunk cell and builds a 2px voxel shell; prism() uses trunk-tile columns 3-13 only, scaled to the trunk width

### L-70 Fortree rope bridges: tile art is two layers, and three scene walls hid it
Cause: Bridge tile 0x256/0x24E is leaf art (under) plus planks/ropes (over layer, ts.overImageData); the scene drew it flat with a 3px slab, a 6px deck band wall and a 32px ground-coloured wall on the canopy cells south of it, and no floor under raised cells (pale backdrop showed under huts). os.getenv is nil inside lib code, so QA flags must be driver-side or edit a QA_SRC copy.
Fix: Gen3Fortree.bridge builds plank + rope boxes, Gen3Fortree.bridgeDrop lowers the leaf plane and the scene skips its over layer, deck band and canopy wall for bridge cells; Gen3Fortree.floor lays grass under raised cells. Scene hunks are in Gen3Scene (committed alone via update-index).

### L-71 Sootopolis ridges were drawn by a per-map masonry list, not the drawn arrows
Cause: Gen3Masonry (hand lists of top/face mids for EM_SOOTOPOLIS_CITY) took ~1000 ridge cells before Gen3Blocks.arrowRamps, so the height map's 45-degree ramps were never built and faces were vertical courses (Petya 2026-11-04: 'the ridges arent read'). Also only 12 of ~28 huts/houses got a model: BuildingVoxels family anchors demanded the door row, window variants (0x211/0x204/0x213, 0x225/0x237) never matched and drew as draped rock.
Fix: Gen3Masonry deleted with its Gen3Scene/Gen3Blocks hooks; BuildingVoxels.LOOSE matches only the roof row (209/20A/20B cone, 20E+25A box, 20D/20E/20F box2) and takes facade art from the cells. Side effect found: once huts left the one 931-cell rock mass, Gen3Blocks.faceMid's mass fallback (mass.blocksFace = face-like tile with most votes) picked ONE stray dark door tile (0x221, 1 vote of 245) for every face of the east masses, so ridges rendered navy with tan swirls (before: 0x210, 2 votes, dark grey). Fix: a fallback winner needs >=3 votes or a tenth of the mass, else the cell's own tan tile is the face (swept 38 QA maps: no other map has such a winner).
Rules: R-38,R-43,R-46,R-48

### L-72 Sootopolis railings lay flat on the rock block's lid
Cause: the railing tiles (0x240-0x243 bar, 0x246/0x247 bar+post corner, 0x262/0x263 post beside the stairs) are cliff cells that Gen3Blocks turns into rock blocks, with the tile art as the lid: a painted strip lying on the ground (Petya 2026-11-04: 'also do the railings'). The art is oblique: bar = top rows 2-5 (depth 4), face rows 6-13 (height 8); post = 6 px wide, top rows 0-4, end face rows 6-14. Posts overshot north when the bar was placed at rows 10-14: the footprint is the TOP rows.
Fix: Gen3Parapet (SPEC per tile) gives the block a plain floor lid (0x2D9, or rock 0x2E1 beside posts), rock faces (0x2E1) and stands bar/post boxes from the tile's own rows on top; hooked in Gen3Blocks.append (par). Not done: the stair-flank posts stay level while the stairs drop 16 px; the gate frame 0x251-0x253 around the pink door is still flat paint.
Rules: R-48

### L-73 Zero-context patches land insertions on the wrong line when others' hunks sit above
Cause: committing only my hunks of a shared file with `git diff -U0` + `git apply --cached --unidiff-zero` uses the WORKING-TREE line numbers; the other party's uncommitted hunks above shift them, so a pure insertion (my `if par then ... end`) landed after `return true` in HEAD's blob (8c93e280 did not compile, fixed in 0ab86896). Deleting hunks were fine because they carry the removed text.
Fix: after every partial stage, compile the STAGED blob (`git show :path > t.lua; luajit -bl t.lua`) before committing, and compile every `git ls-tree HEAD mod/lib` file after; if wrong, build the blob from HEAD in python and `git update-index --cacheinfo`.

### L-74 Sootopolis gate frame is a hanging ring, not paint on the terraces
Cause: The 15 tiles round the cave door (0x251-0x253 top beam, 0x220/0x222 sides, 0x228/0x22A front corners, 0x230/0x232 legs, 0x229 front beam over walkable floor) are one stone cube-frame the art draws in oblique view; the 3D cells are a stepped cliff (48/32/16), so every beam lay flat on a lid of another height (Petya 2026-11-04: 'like a cube around the entrance, it hangs in the air, its now flat').
Fix: Gen3Parapet.GATE: one level ring at the back row's lid height (beams 5x5 px from the art's top rows, side beams over the y16 terrace, lintel bridging the door cell by 0x252 at x30), legs from the floor under the two front corners (0x228/0x22A cells), lids plain floor/rock/pink; the walkable 0x229 cells get the pink floor via Gen3Parapet.floorUV hooked at the uv line of Gen3Scene.build. Art rows were read as a pixel char map, not by eye. The door in the gate is the same two-tile cave entrance (R-50) with roles swapped: 0x221 is the HOLE, 0x25B the ARCH above it; the arch cell now keeps its plateau height (Gen3Parapet.keepsHeight skips Gen3Blocks.lowerArches) and its south face carries the hole (one course) and the arch band, so the notch is one cell deep and the warp tile sits at the hole's foot (Petya 2026-11-04: 'also a cave entrance, a hole and an arch above, two tiles').
Rules: R-48

### L-75 Sootopolis stair posts follow the flight on a sloped shoulder
Cause: The four flights (0x244/0x245, 16 px drop in one cell, two cells at (9,8)-(9,9)) have a post cell on each side (0x262 west, 0x263 east: rock block at the plateau height, hmap cell). The post was a level 5 px stub on that flat block while the stairs dropped beside it (Petya 2026-11-04, 'all three'). Heightmap (hmap) cells never get buildSlopes wedges, so the block stayed flat.
Fix: Gen3Parapet.shoulders (called in Gen3Blocks.prepare after buildRamps) gives each post cell next to a steps cell c.ramp={T,T,foot,foot}; appendRamp takes the rock lid (Parapet.lid compresses the art rows by 0.7071 so a pixel stays a pixel on the 45 degree slope) and rock faces and calls Parapet.append, whose sloped() builds a constant-height wall on the slope (width of the post it continues from the north, end face at the foot). The flight's own treads and the neighbour block's triangle wall (Gen3Blocks.append ramp branch) needed no change.
Rules: R-48

### L-76 Slateport Fan Club: back wall, hip roof on a box, front eave ledge
Cause: The exported model x_slateport_fanclub (quads f,x0,x1,h0,h1,z0,z1,px,py,shade; f 1 S,2 N,3 top,4 E,5 W) built its back and sides by repeating ONE front column of texels by height, so the back carried the window stripe, 1 px slots between 16 px segments, and the plan narrowed like a trapezoid down to the ground (Petya 2026-11-04: 'the back isnt done and the front needs a little ledge thingy').
Fix: Data edit only (no builder code): rectangle walls x1..79, z-39..0 up to the eave (h32); back and rear sides use the plain wall texels (grey base 0-6, navy line 1, yellow wall 7-23, navy 24-25, olive eave band 26-31); the stepped hip steps are clipped to h>=32 and a flat eave shelf (66,10) fills the corners the hip leaves open; the front eave band h25-31 is copied 4 px forward (z4) with a top at h32 and end caps, so the roof overhangs the facade. Texel colours were read from the ortho45 shot, not guessed.
Rules: R-08

### L-77 Slateport sailboats: mast bits are not hull
Cause: Gen3Boat.template classed every non-sail, non-green pixel as hull, so the mast pole and rigging pixels (cols 26-33, rows 5-23, cut off from the hull body by sail pixels) made hull columns 30 px long: deck planks and side walls sticking out of the boat like legs.
Fix: Gen3Boat.template keeps only the hull pixels 4-connected to the lowest hull pixel as T.hull; the rest become T.pole, still drawn as mast boxes. Dump the pixel classes (S/H/.) with a QA_SRC copy that prints them, not by eye.
Rules: R-29

### L-78 Slateport dry-dock boat: the top half lives in the tileset's top layer, and the hull is the art unfolded per column
Cause: The boat is the 3x2 metatiles 0x220-0x222/0x228-0x22A at x21-23,y35-36; the whole upper row is TOP-layer art (bottom layer there is plain grass), but the old kind='extrude' h=9 (Gen3Fence.extrude) read imageData only, so it extruded just the lower row's hull colours into a brown trough whose tan side skirt looked like a mud patch (Petya 2026-11-05: 'oh fix that boat as well'). The art is a 48x32 view from the south: far rim rows 0-2, inner far wall 3-11, floor 12-15, near rim 16-18, near planks 19-28, two props (cols 7-9 rows 18-27, cols 35-37 rows 21-30), a D-shaped stern rail.
Fix: Gen3DryDock (hooked as shape.dock in the extrude branch of Gen3Scene.build) composites bottom+top layer, floods the ground colours in from the border, and per column stacks the art's own rows with the 45 degree rule z=row+height: near planks as the south face (10 rows), 3-row rim ledges flat at the rim, the far wall's inner face (9 rows), the floor 1 px up, hidden floor strip, side quads from a per-column z/height profile, props as boxes; columns shorter than 8 rows (prow tip) are left out. The em_ortho_driver shot of the 3D matches the 2D art pixel for pixel. Dump a tile group as a char map with a QA_SRC probe that prints imageData and overImageData.
Rules: R-08,R-29

### L-79 Interior QA sweeps: ids, active flag, framing
Cause: A map id typed as EM_..._1_F (digit-letter split) does not load, Map.load still logs 'load true' and the shot shows the PREVIOUS map (log line says active false); the day driver names shots by x_y so maps collide; door-spawn shots crop big rooms (Dept Store 2F-5F show a corner) and QA_ZOOM does nothing at level 7.
Fix: Ids are EM_UPPER_SNAKE with the floor glued (..._1F); drop every shot whose [EM view] line says active false; use EM_INDEXED=1; for big rooms put the player at the room centre and shoot yaw 0 and 3.14159.
Rules: R-22,R-23

### L-80 Merging mods into one: four traps
Cause: Putting three mods in one folder broke in four places: a part's main.lua returns a function, so chunkFor(rel)(mod) only CALLED the chunk and the entry never ran; mod.options:define REPLACES the schema, so the last part wiped the others' option defaults (every get() returned nil and wilds spawned nothing); two parts exported gen3 (world camera vs wilds state) and the second overwrote the first; install/require paths are the folder name, so every mods.<id>.lib require and mod:read path needs the subfolder.
Fix: Call entry function's result; wrap options.define in main.lua to merge rows; give each part its own export key (wilds = S); keep required_imports optional so a missing ROM does not make the whole mod invalid; grep for mod:read/':list(' and 'mods/' paths after moving trees.
Rules: R-38

### L-81 A QA run that cannot write its copy still reports shots
Cause: qa_tryp.sh copies the mod into ~/Library/Application Support/pokemon-love2d-rseqa-pN and swaps in the files under test. If the process cannot write that folder (a sandbox that only allows the repo), rsync/cp fail, the game boots the copy's INSTALLED mod instead, and the summary still prints the shot count and 'fallback 0' -- green numbers for code that was never loaded. The private copy also keeps no .tryp_swapped, so later runs sync a stale tree.
Fix: Read run.log: it must start with '[qa_tryp] identity ... files <the files you named>'; a run whose stderr has 'Operation not permitted' on the QA folder proves nothing. Re-run with full file access (or from outside a sandbox) and confirm the shots changed when the code did.
Rules: R-22

### L-82 Interior back wall: the shell wall belongs at the front of the art-wall panels, measured AFTER furniture and layout
Cause: Indoor wall art = roomWall columns (Gen3TileShape.layout): a 4 px panel at front=(last+1)*16, art on the front face. InteriorDiorama put the shell back wall at z0 or z0+1, i.e. behind the panels: a second wall with floor between (Littleroot houses: windows and stairs on a panel in front of the real wall). A first generic fix counted raw wall tiles from the map; but props (plants, cupboards) sit on wall-row tiles and are no column members, so in Frontier lounges/Tower/Pike/Palace the shell moved in front of the real panels and hid the wall art and the Palace door.
Fix: InteriorDiorama.fitWall(def,cells) runs in Gen3Scene after Furniture.extract + Shapes.layout and moves the shell only when EVERY top-row cell is a wall column with one and the same front (forward only, never over a prop row); Littleroot houses keep their explicit z0+2. Wall pieces (cabinet/fridge/counter/drawers/desk, recipe.wallPiece) get p.wallZ from Gen3Scene and Gen3PixelFurniture seats their back on it when it is within 16 px. Check any wall change with old-vs-new stills of the rooms whose [fit] line moved (tools/trailer.sh, EM_WALLS=1 prints [fit]/[walls]; EM_WALLS=2 grid, 3 per-cell prop/column).
Rules: R-22

### L-83 Dead-code removal broke the battle animation: safeCall calls a method by string
Cause: 160b71e3 removed Instance:playContext from model_api.lua as test-only; StadiumModels calls it as safeCall(actor.instance,'playContext',...), a string name no caller scan sees, and safeCall swallows the missing method. Every context switch failed: after a move the model froze on the clip's last frame, the next move restarted the 184-frame clip, hit/faint/sleep never played (the 'spastic Zigzagoon').
Fix: Before deleting an API method grep its name as a string too (rg "'name'|\"name\""); a safeCall that returns nil hides a missing method, so check with tools/drivers/em_animprobe_driver.lua (per-frame ctx/anim/frame, EM_PROBE_TAPS=150 to run moves). playContext restored, test asserts it.
Rules: R-45

### L-84 Trailer capture runs battle sprites and camera at about 19x speed
Cause: Gen3Battle, StadiumModels and BattleShots advance by love.timer.getDelta(), the real frame time; capturing one frame takes ~0.3 s, so sprite and move animations and camera cuts raced ahead of the game steps (Petya 2026-11-08: the 2D battle sprites feel sped up).
Fix: em_trailer_driver.lua returns 1/60 from getDelta to the battle files; re-record any battle shot made before that, and use shot.recordFrom to fit the 400 s cap.

### L-85 Interior shell and stairs z-fight: coplanar faces from layered boxes
Cause: InteriorDiorama.run drew the wall, base, chair rail, cap and 2 px end posts as boxes sharing the run's end planes and the 3.6 rail depth, and Gen3Stairs.appendWall gave every tread box a front face on the same plane as its riser quad: coplanar same-facing faces z-fight, so the stairs and the end of the left wall flickered in the trailer (Petya 2026-11-08: 'the stairs in may's home flicker, as well as the wall on the left').
Fix: End posts stand .05 past the run and .1 deeper (3.7); tread boxes skip their front face (the riser quad is that face). Find these with EM_ZFIGHT=1 tools/trailer.sh (lists coplanar same-facing overlapping shell quads; first shot must be a throwaway map so the probe is installed before the room builds); only the same-colour window bars may remain.
