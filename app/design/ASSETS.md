# Game art sources

All runtime art and design references are stored inside this repository.
No runtime asset depends on a user-specific generated-images directory.

## Active period: circa 1900-1910

- `../assets/units/1900/engineer_idle.png`: miner reference / idle fallback.
- `../assets/units/1900/engineer_walk_empty.png`: 8 directions x 8 walk frames, empty large canvas backpack.
- `../assets/units/1900/engineer_walk_loaded.png`: 8 directions x 8 walk frames, large backpack filled with golden gold ore.
- `../assets/units/1900/engineer_mine.png`: 8 directions x 8 mining frames.
- `../assets/units/1900/engineer_repair.png`: 8 directions x 8 wrench-work frames.
- `../assets/buildings/command_center_open.png`: fixed elevated open-factory base.
  Smoke, flywheel, piston, conveyor, water and fire are separate four-phase drawing layers.
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
