# Game art sources

All runtime art and design references are stored inside this repository.
No runtime asset depends on a user-specific generated-images directory.

## Active period: circa 1900-1910

- `../assets/units/1900/engineer_idle.png`: miner reference / idle fallback.
- `../assets/units/1900/engineer_walk_empty.png`: 8 directions x 8 walk frames, empty large canvas backpack.
- `../assets/units/1900/engineer_walk_loaded.png`: 8 directions x 8 walk frames, large backpack filled with golden gold ore.
- `../assets/units/1900/engineer_mine.png`: 8 directions x 8 mining frames.
- `../assets/units/1900/engineer_repair.png`: 8 directions x 8 wrench-work frames.
- `../assets/buildings/command_center_wash_plant_compact_twin.png`: active low cutaway placer-gold factory base (1536x1024), with twin chimneys.
  Smoke, flywheel, piston, incoming conveyor ore and washing water use separate four-phase drawing layers.
  Lower-left conveyor feeds indoor riffle tables, settling basin and water outlet; a rear brick chimney and groundwater pump complete the building.
  `command_center_open.png` preserves the previous factory design.
  The previous whole-building atlas is preserved only as a design experiment.

Direction row order is E, SE, S, SW, W, NW, N, NE in screen coordinates.
The character sheets use equal cells; drawing uses normalized image dimensions.
The factory is an original stylized industrial timber pumping works with cylindrical
smokestack, piston pump, flywheel, water outlet and ore carts. It is not a reconstruction
of one specific historical site. Its logical footprint is 4x3 square tiles; its low wide silhouette is a rendering-only choice.

Period references:
- Smithsonian, miner cap and carbide lamp (circa 1900-1930):
  https://www.si.edu/object/miners-cap-and-carbide-lamp%3Anmah_872639
- Waterworks Museum, early twentieth-century belt/line-shaft pump drive:
  https://www.waterworksmuseum.org.uk/blog/massington-lineshaft

## Preserved for a future modern era

`../assets/units/modern/` contains the previous hardhat/visor/backpack character images.
`units/modern/` preserves the concept and motion study. These files remain versionable,
but are not declared as active Flutter assets and are not loaded by the current game.

## Concepts

`units/1900/engineer_concept.png` and `buildings/command_center_concept.png`
are design references. Generated art is a prototype and should be reviewed at actual
in-game scale before final production use.

## Infantry sprites

`../assets/units/1900/infantry/` contains pistol_walk, pistol_fire, shotgun_walk,
and shotgun_fire PNG sheets. All final atlases have 8 directions. Pistol walk/fire and shotgun fire use 8 frames;
shotgun walk uses 7 frames, configured in both its action spec and atlas slicing.
The navy guard fires one pistol with both hands; the olive guard shoulders a
wood-stock pump shotgun. Camera is fixed overhead parallel projection matching
our shared art camera. `units/1900/infantry/infantry_concepts.png` stores the concept.
These are fictional uniforms inspired by the period, not a reconstruction of a named army.

## Washing factory redesign

Corrected low preview: `../assets/buildings/command_center_wash_plant_compact_twin.png`.
Built-in image edit using the original stone alternative as reference.
Prompt: Preserve the stone factory's horizontal width, foundation footprint, depth,
camera and machinery layout. Lower only wall elevation and roof ridge by about 25 percent,
remove the raised clerestory and vents, and use exactly two rear brick chimneys.
Keep conveyor, sluice, settling tank, pump and flywheel physically proportional.
Maintain the compact original composition without widening the building; transparent
background, warm painted game sprite, no people, labels or smoke.

Third preview: `../assets/buildings/command_center_wash_plant_low_twin.png`.
Built-in image generation, with the stone alternative as reference. Earlier versions
are preserved. The corrected compact twin-chimney version is now active.
Prompt: Lower the stone factory walls and machinery supports by about 35–40 percent;
redesign as a broad squat single-story cutaway factory with shallow teal iron roof,
no clerestory or roof vents, exactly two medium brick chimneys at the rear corners.
Preserve the lower-left incoming conveyor, indoor water sluice and gold riffles,
settling basin, right-side groundwater piston pump and flywheel, copper pipes,
warm circa-1900 game art and elevated southwest-facing orthographic camera.
Transparent background; no people, text or smoke clouds.

Alternative preview: `../assets/buildings/command_center_wash_plant_stone.png`.
The original timber factory is preserved; the compact twin-chimney factory is active. The stone alternative
was generated with the built-in image tool using the timber factory as a style reference.
Prompt: Alternative circa-1900 compact gray stone and muted teal iron cutaway gold
washing factory, matching elevated southwest-facing RTS sprite camera; rear-left brick
chimney, right-side groundwater piston pump and flywheel, lower-left incoming conveyor,
indoor hopper, broad water sluice with gold-trapping riffles and settling tank. Warm
painted game art, transparent background, no people or text. Preserve the first design.

Generated with the built-in image generation tool using the previous factory as a style reference.
Prompt: Compact circa-1900 timber and stone cutaway placer-gold factory, elevated
southwest-facing orthographic game view, transparent background, rear brick chimney,
groundwater piston pump and flywheel, lower-left conveyor feeding an indoor hopper,
blue-water riffle sluices trapping gold, settling basin and water outlet. Match the
existing warm painted game art; no people, text or detached platforms.

## Infantry training barracks concept

`../assets/buildings/barracks_training.png` is a saved design concept for infantry
and shotgun troop production. A right-side stone arch provides a future stable
attachment point for cavalry. Training and stable gameplay are not implemented by this asset.
Built-in image generation prompt: Circa-1900 compact single-story gray stone and
teal-roof infantry training barracks, warm painted elevated southwest orthographic
RTS sprite matching the factory. Open drill courtyard, two wooden shooting targets,
rifle and shotgun racks, ammunition crates and benches, lower-left entrance and
right-side arch for a future stable. No horses yet; transparent background, no text
or people. Keep substantial depth and avoid stretching the building sideways.

## Bottle shooting school

Active training asset: `../assets/buildings/barracks_bottle_range.png`.
Built-in image edit prompt: Preserve the compact stone barracks, teal roof, right
stable attachment arch, warm circa-1900 RTS camera and style. Replace bullseyes with
rough timber shelves holding distinct green and amber glass bottle shooting targets,
add a few broken shards, leave an open courtyard with a small shooting bench, rifle
and shotgun rack and ammunition crates. Transparent background, no people or text.
The unit lab now supports queued infantry and shotgun production from this school.
