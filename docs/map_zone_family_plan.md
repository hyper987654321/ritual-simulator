# Map Zone Family Plan

Source code is still the implementation truth. This document records the current
15-zone visual direction so the plan does not get lost while each family is
implemented and reviewed in Studio.

## Structure

The map is planned as 5 visual families with 3 tiers per family:

| Family | Tier 1 | Tier 2 | Tier 3 |
| --- | --- | --- | --- |
| Nature | Sprout Meadow | Bloom Grove | Elderwood Garden |
| Mines | Stone Quarry | Crystal Mine | Deepcore Vein |
| Ruins | Broken Courtyard | Ancient Sanctum | Relic Terrace |
| Infernal | Ash Flats | Magma Quarry | Hellbone Gate |
| Frost | Snowfield | Glacier Grove | Frozen Spire |

The intent is that a family reuses most props across all three tiers. Higher
tiers should add stronger silhouettes, denser decoration, and more accent color
without becoming a new visual theme.

## Nature Family

Implementation status: first pass implemented in `ZoneConfig.luau`,
`MapGenConfig.luau`, `PropScatterer.luau`, and `PropDefinitions.luau`.

The active configured zone order is now:

| Zone | Family | Tier | Name |
| --- | --- | --- | --- |
| 1 | Nature | 1 | Sprout Meadow |
| 2 | Nature | 2 | Bloom Grove |
| 3 | Nature | 3 | Elderwood Garden |
| 4 | Mines | 1 | Stone Quarry |
| 5 | Mines | 2 | Crystal Mine |
| 6 | Mines | 3 | Deepcore Vein |
| 7 | Ruins | 1 | Broken Courtyard |
| 8 | Ruins | 2 | Ancient Sanctum |
| 9 | Ruins | 3 | Relic Terrace |
| 10 | Infernal | 1 | Ash Flats |
| 11 | Infernal | 2 | Magma Quarry |
| 12 | Infernal | 3 | Hellbone Gate |
| 13 | Frost | 1 | Snowfield |
| 14 | Frost | 2 | Glacier Grove |
| 15 | Frost | 3 | Frozen Spire |

Tier names:

- Tier 1: `Sprout Meadow`
- Tier 2: `Bloom Grove`
- Tier 3: `Elderwood Garden`

Current implemented props:

- `BlockTree`
- `Grass`
- `Bush`
- `FlowerClump`
- `TreeStump`
- `FallenLog`
- `PathPebbles`
- `SignPost`
- `SmallFence`
- `Rock`
- `RockCluster`
- `CrystalGrass`
- `CrystalRock`
- `CrystalCluster`

Nature prop construction notes:

- Current Nature props use centered, math-aligned silhouettes instead of
  per-part random placement.
- Whole props may still rotate/scale from the scatterer, but the internal
  pieces are placed symmetrically so each prop reads clearly from normal game
  camera angles.
- `FlowerClump`: flat layered flower with radial petals, leaves, shadow petals,
  and raised center blocks.
- `TreeStump`: authored low stump with long root runs, buttress panels,
  faceted side panels, raised bark panels, cut-surface edge pieces, and nested
  annual rings.
- `FallenLog`: segmented horizontal log with cap rings, bark strips, and paired
  branch stubs.
- `PathPebbles`: aligned pebble path with paired moss details.
- `SignPost`: centered wooden sign with trim, nails, support braces, and short
  deterministic text.
- `SmallFence`: three-post fence segment with rails, cross braces, nails, and
  small base grass.
- `BlockTree`: bright starter-zone tree with a short warm trunk, small base
  collar, overlapping stepped leaf tiers, a few attached leaf-step blocks, and
  controlled raised studs. The rejected dark roots, exposed support sticks, and
  heavy bark-rib clutter were removed so the canopy reads as one connected
  childish block shape instead of a dark realistic tree.
- `Bush`, `Grass`, `Rock`, `RockCluster`, and `CrystalCluster`: rebuilt as
  clearer block forms with small repeated details rather than random local
  offsets.

Nature tier direction:

- `NatureT1`: readable first-zone set. Trees, grass, bushes, flowers, pebbles,
  basic rocks, rare stump/signpost.
- `NatureT2`: fuller grove set. Adds fallen logs and small fences, raises
  flowers/stumps, keeps rocks secondary.
- `NatureT3`: denser elder garden set. More logs, fences, stumps, crystal
  accents, and heavier tree presence.

Current tier prop sets:

- `NatureT1`
  - Big props: `BlockTree`
  - Props: `Grass`, `Bush`, `FlowerClump`, `PathPebbles`, `Rock`,
    `RockCluster`, `TreeStump`, `SignPost`
  - Crystal decor: `CrystalGrass`, `CrystalRock`, `CrystalCluster`
- `NatureT2`
  - Big props: `BlockTree`
  - Props: `Grass`, `Bush`, `FlowerClump`, `TreeStump`, `FallenLog`,
    `PathPebbles`, `Rock`, `RockCluster`, `SmallFence`, `SignPost`,
    `CrystalCluster`
  - Crystal decor: `CrystalGrass`, `CrystalRock`, `CrystalCluster`
- `NatureT3`
  - Big props: `BlockTree`
  - Props: `Grass`, `Bush`, `FlowerClump`, `TreeStump`, `FallenLog`,
    `PathPebbles`, `RockCluster`, `SmallFence`, `SignPost`, `CrystalCluster`
  - Crystal decor: `CrystalGrass`, `CrystalRock`, `CrystalCluster`

The three Nature tier prop sets currently use `RequiredProps`, so each Nature
zone attempts to place one of every listed small prop before random scatter
fills the rest of the zone. This is for visual review: it makes the listed props
visible across zones 1-3 instead of relying only on weights.

Reference prop workflow:

- Studio-authored or imported examples can be placed under
  `Workspace.ReferenceProps`.
- The map generator plugin has an `Analyze References` button that reads each
  top-level child of `ReferenceProps` as one reference prop.
- The analyzer recurses through nested models/folders and loose parts, so it
  does not depend on clean names like `TreeRoot` or `CanopyLayer`.
- Generic names such as `Part`, `part1`, and `Model` are preserved as metadata
  but not used as the main identity. Exported part ids are deterministic from
  sorted geometry.
- The analyzer also assigns category and complexity hints such as `Tree`,
  `Flower`, `Stone`, `Creature`, `VerySimplistic`, `Defined`, `Advanced`, or
  `ReferenceQuality`. These are heuristics from geometry, colors, part counts,
  small-detail counts, vertical layers, rotated parts, and nesting.
- Mixed reference folders are expected. Simple stones, advanced flowers, trees,
  creatures, snow props, and random models can live together; the exported data
  is meant to help decide which models are useful templates and which are only
  rough references.
- The plugin exports raw data to
  `ReplicatedStorage.GeneratedReferencePropBlueprints`. This is intentionally
  outside the Rojo-managed `Shared.Config` tree so Studio-generated reference
  data is not overwritten by source sync.
- `ReplicatedStorage.GeneratedReferencePropBlueprints.Index` contains the
  compact summary. Each `Reference_*` child module contains one prop's detailed
  part offsets.
- That generated module is reference data only until a prop is deliberately
  converted into `PropDefinitions.luau` or a future blueprint-backed prop
  builder.

Avoid in Nature unless deliberately reviewed later:

- skulls
- cactus
- lava props
- ore-heavy mine props
- ruin pillars
- ritual lamps

## Other Families

Mines are configured as zones 4-6 using `MinesT1`, `MinesT2`, and `MinesT3`.
They currently build from `RockCluster`, `OreVein`, `CrystalCluster`,
`CrystalRock`, and `PathPebbles`. Missing mine-specific props still include
rails, carts, supports, ore boulders, crates, and lanterns.

Ruins are configured as zones 7-9 using `RuinsT1`, `RuinsT2`, and `RuinsT3`.
They currently build from broken stone, lamps, rocks, ore, and crystal accents.
Missing ruin-specific props still include arches, cracked tiles, fallen columns,
statue heads, altars, relic pedestals, and banner posts.

Infernal is configured as zones 10-12 using `InfernalT1`, `InfernalT2`, and
`InfernalT3`. It merges the old volcano/hell direction and currently uses
rocks, ore, crystals, cactus, pillars, lamps, and skulls. Missing infernal props
still include lava cracks, obsidian spikes, bone piles, rib cages, chain posts,
ember vents, and charred trees.

Frost is configured as zones 13-15 using `FrostT1`, `FrostT2`, and `FrostT3`.
It currently builds from pines, icy crystals, snow-colored rocks, and broken
pillar shapes. Missing frost props still include snow mounds, ice shards,
frozen logs, icicle wall chunks, ice arches, and frost lamps.
