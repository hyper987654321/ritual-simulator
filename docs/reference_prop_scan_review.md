# Reference Prop Scan Review

Source code remains the implementation truth. This note records the first
review of the Studio export saved as `GeneratedReferencePropBlueprints.rbxmx`.
The export contains generated reference-analysis data, not production prop
definitions.

## Scan Snapshot

- Props scanned: 76
- BaseParts scanned: 1,257
- Export reviewed: `GeneratedReferencePropBlueprints.rbxmx`
- Studio export root: `ReplicatedStorage.GeneratedReferencePropBlueprints`
- Summary module: `ReplicatedStorage.GeneratedReferencePropBlueprints.Index`

The first scan used early analyzer categories. Some labels are imperfect:
Birch references were labeled as `Stone`, mushrooms as `Stone`, grass as
`Bush`, and the studded fence as `Wood`. The analyzer has been adjusted so a
future scan should classify `Birch`, `Grass`, `Mushroom`, `Fence`, `Portal`,
and `Mountain` more directly.

## Best Template Candidates

These are useful as construction references, not as direct 1:1 generated
scatter props.

| Reference | Name | Category | Parts | Notes |
| --- | --- | --- | ---: | --- |
| `Reference_70` | probably one of the best trees | Tree | 185 | Best tree-quality reference. Very expensive raw count, but useful for canopy massing, layered leaf volumes, and dense edge/detail repetition. |
| `Reference_73` | Lotus Flower | Flower | 135 | Best flower-system reference. Strong radial symmetry, stacked petal layers, and readable centerpiece. Good model for water/nature feature props. |
| `Reference_75` | Red Flower [STUDS] | Flower | 195 | Strong detail density and vertical flower construction, but too expensive raw. Use as a guide for stem + petal layering, not direct copy. |
| `Reference_20` | Pine | Tree | 33 | Good efficient tiered pine reference. Much better runtime target than the 185-part tree. |
| `Reference_54`, `Reference_59`, `Reference_60` | Tree 3 | Tree | 23 each | Efficient stylized tree variants with useful stacked-volume silhouettes. |
| `Reference_58` | Tree2 | Tree | 21 | Large broad-canopy reference. Useful for canopy chunk placement. |
| `Reference_65` | Mountain | Stone | 24 | Good wall/backdrop or zone-edge reference, more useful for terrain chunks than scatter props. |
| `Reference_69` | Portal | Stone | 36 | Useful for later zone gates or landmarks, not Nature scatter. |
| `Reference_66` | Crab (I made it :3) | Creature | 41 | Good proof that creature props need deliberate symmetry and appendage layout. Not a Nature priority. |
| `Reference_67` | Reference_67 | Bush | 16 | Small but useful bush quality target with compact detail density. |

## Nature Takeaways

- Do not copy the 135-195 part flower/tree references directly into random
  scatter. They are too expensive for repeated procedural placement.
- Pull patterns from them:
  - radial layers for flowers and lotus-style water details
  - tiered chunking for trees
  - repeated edge/stud detail in controlled grids
  - clear center/core pieces before adding small decorative pieces
  - larger silhouette changes before tiny details
- The best next Nature upgrades should use a budgeted version of:
  - `Reference_20` for pine/tree tiering
  - `Reference_70` for high-quality block tree massing
  - `Reference_73` for a new lotus/water flower prop
  - `Reference_67` for bush detail density

## Not Good Production Targets Yet

- The 4-part pine/oak/birch references are useful only as rough silhouette
  notes. They are too simple to improve the current Nature set by themselves.
- Most 1-4 part rocks/grass/bushes are too simple as standalone references.
  They can inform small filler props, but not the quality target.
- `Reference_76` Studded Fence is currently too simplistic to replace or guide
  the current fence.

## Implementation Direction

For the next Nature pass, build new procedural helpers instead of copying
generated reference modules:

- `addRadialPetals` for flowers/lotus/water props.
- `addLayeredCanopy` for tree leaf massing.
- `addRootSystem` for trees and stumps.
- `addEdgeStudBands` for controlled detail repetition.

Keep high-quality scatter props around 20-50 parts each unless they are rare
landmark props. Use 100+ part references only as rare set pieces or as design
templates.
