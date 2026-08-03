# Ritual Core Map Creation Plugin — Design Document

## Purpose

This document defines how to implement a **Roblox Studio map creation plugin** for Ritual Core.

The plugin is an **authoring-time tool**. It should generate and bake the map inside Studio. It is **not** a gameplay system that runs when the player joins the game.

The current game already has server-owned progression, zones, crystals, pets, combat, teleporting, rebirth, ascension, Ritual Rush, and UI. The map generator should support that system visually. It should not replace the core gameplay loop.

The correct direction is:

- Use Roblox smooth voxel terrain for the large landmass.
- Use simple anchored structures for small objects.
- Keep gameplay authority on the server.
- Generate deterministic random maps from a seed.
- Store generated output in a clearly named folder.
- Add anchors and metadata so future gameplay systems can read positions safely.

---

## Current Game Context

The current implementation already has:

- Five configured zones.
- Five crystals per zone.
- Server-owned crystal combat.
- Server-owned zone unlocks and teleport requests.
- Runtime crystal state.
- Client-local crystal visuals.
- Client-local unlock walls.
- Client-local ascension statue.
- Server-generated world content that is currently only basic bounds markers and the zone one spawn.
- A `WorldService` that creates `Workspace/GeneratedRitualWorld`.
- A `WorldController` that creates client-local preview objects under `Workspace/LocalRitualPreview`.

Important consequence:

The plugin must not generate into `Workspace/GeneratedRitualWorld`, because the current server service destroys and recreates that folder on startup. The plugin should generate into a different folder, for example:

```text
Workspace/RitualMapGenerated
```

Terrain itself lives in `Workspace.Terrain`, so the plugin folder stores props, anchors, debug markers, and generation metadata.

---

## High-Level Decision

Build a **Studio plugin** called:

```text
Ritual Map Generator
```

It should expose a docked Studio widget with:

- Seed field.
- Preset selector.
- Generate terrain button.
- Generate props button.
- Generate all button.
- Clear generated map button.
- Validate map button.
- Export anchors button.
- Debug toggles.

The plugin should use pure shared generator modules as much as possible. The plugin UI should only call those modules.

Recommended source layout:

```text
plugins/
  RitualMapGenerator.plugin.luau

src/shared/MapGen/
  MapGenConfig.luau
  SeededRandom.luau
  Noise.luau
  ZoneLayout.luau
  HeightMap.luau
  BiomeMap.luau
  TerrainPlan.luau
  TerrainWriter.luau
  PathGenerator.luau
  PropCatalog.luau
  PropScatterer.luau
  StructureFactory.luau
  AnchorExporter.luau
  MapValidator.luau
```

The modules under `src/shared/MapGen` should be deterministic and testable. The plugin script should handle Studio-specific work such as toolbar buttons, widget GUI, progress labels, and writing instances into the DataModel.

---

## Roblox API Research Summary

Use these Roblox systems:

### Studio plugin UI

Use `plugin:CreateToolbar(...)`, toolbar buttons, and a dock widget. Roblox plugins are built around the `Plugin` object, and docked Studio UIs are created with `CreateDockWidgetPluginGui` / dock widget APIs.

The plugin UI should be simple. It does not need React. Basic Studio `GuiObject` controls are enough.

### Terrain

Roblox smooth terrain is voxel-based. Terrain cells are based on a four-by-four-by-four stud grid. For large terrain generation, prefer batch voxel writes instead of creating thousands of parts.

Useful APIs:

- `Workspace.Terrain:WriteVoxels(...)`
- `Workspace.Terrain:ReadVoxels(...)`
- `Workspace.Terrain:FillBlock(...)`
- `Workspace.Terrain:FillBall(...)`
- `Workspace.Terrain:FillRegion(...)`
- `Workspace.Terrain:Clear()`, only if intentionally clearing all terrain

Recommendation:

- Use `WriteVoxels` for the base landmass.
- Use `FillBlock`, `FillBall`, or `FillRegion` only for simple edits, clearing, smoothing chunks, caves, water, or fast prototype work.
- Do not represent the whole map as individual parts.

### Noise

Roblox has `math.noise(...)`, which returns Perlin-style coherent noise values. Use it for height maps, biome masks, tree density masks, rock density masks, and detail variation.

Recommended generator pattern:

```lua
local function fbm(x, z, seed, octaves, frequency, persistence, lacunarity)
    local value = 0
    local amplitude = 1
    local totalAmplitude = 0

    for octave = 1, octaves do
        value += math.noise(
            x * frequency,
            z * frequency,
            seed + octave * 31
        ) * amplitude

        totalAmplitude += amplitude
        amplitude *= persistence
        frequency *= lacunarity
    end

    return value / totalAmplitude
end
```

### Object placement

Use `Workspace:Raycast(...)` to place props on the terrain surface.

For example:

- Pick X/Z.
- Raycast downward from high Y.
- If hit terrain or valid surface, place object at hit position.
- Reject steep slopes.
- Reject positions too close to paths, crystals, spawn, unlock walls, ascension statue, or zone boundaries.

### Metadata

Use attributes and tags:

- `Instance:SetAttribute("GeneratedBy", "RitualMapGenerator")`
- `Instance:SetAttribute("Seed", seed)`
- `Instance:SetAttribute("ZoneId", zoneId)`
- `CollectionService:AddTag(instance, "RitualMapGenerated")`
- `CollectionService:AddTag(instance, "RitualMapAnchor")`

Use attributes for metadata values. Use CollectionService tags for finding groups of generated instances.

### Moving models

Use `Model:PivotTo(...)` for placing prefab models. Do not use old `SetPrimaryPartCFrame` patterns unless existing code forces it.


---

## Asset Policy

The map generator should not depend on third-party asset packs.

Default rule:

- Use Roblox built-in primitives, materials, terrain materials, lights, beams, particles, and simple generated Models.
- Use generated Parts, MeshParts only if they are project-owned, and Studio-authored assets that belong to this project.
- Do not pull random models from the Creator Marketplace as required dependencies.
- Do not use third-party trees, rocks, ruins, VFX, meshes, or texture packs unless the team has explicitly reviewed licensing, optimization, and visual consistency.
- If a higher-quality custom asset is needed, create it ourselves and store it as a project asset.

Allowed sources:

| Source | Allowed? | Notes |
|---|---:|---|
| Roblox built-in Parts | Yes | Preferred for first version |
| Roblox terrain materials | Yes | Preferred for landmass |
| Roblox built-in effects | Yes | Use carefully; keep performance simple |
| Project-owned custom models | Yes | Good for later polish |
| Project-owned uploaded textures/icons | Yes | Only if optimized and documented |
| Third-party marketplace assets | Avoid | Not required for generator; only after review |
| Random free asset packs | No | Avoid inconsistent style, hidden scripts, bad collision, licensing issues |

The first version should be fully achievable with generated Roblox primitives:

- block/cylinder tree trunks
- sphere/block canopies
- wedge or block crystals
- block/cylinder ruins
- simple neon rune insets
- anchored lamps and ritual stones

This also makes the generator deterministic, safe to delete/regenerate, and easier for Codex to implement.

---

## Generated Output Structure

The plugin should create this structure:

```text
Workspace
  RitualMapGenerated
    Metadata
    Zones
      Zone_1
        Props
        Structures
        Debug
      Zone_2
        Props
        Structures
        Debug
      Zone_3
        Props
        Structures
        Debug
      Zone_4
        Props
        Structures
        Debug
      Zone_5
        Props
        Structures
        Debug
    Anchors
      Zone_1
        Spawn
        Crystal_1
        Crystal_2
        Crystal_3
        Crystal_4
        Crystal_5
      Zone_2
        UnlockWall
        Crystal_1
        Crystal_2
        Crystal_3
        Crystal_4
        Crystal_5
      Zone_3
        UnlockWall
        Crystal_1
        Crystal_2
        Crystal_3
        Crystal_4
        Crystal_5
      Zone_4
        UnlockWall
        Crystal_1
        Crystal_2
        Crystal_3
        Crystal_4
        Crystal_5
      Zone_5
        UnlockWall
        AscensionStatue
        Crystal_1
        Crystal_2
        Crystal_3
        Crystal_4
        Crystal_5
```

Terrain is not a child of this folder. Terrain exists globally under `Workspace.Terrain`.

The `Metadata` folder should have attributes:

```text
GeneratedBy = "RitualMapGenerator"
Version = "0.1.0"
Seed = number
Preset = string
GeneratedAtUnix = number
ZoneCount = number
```

Every generated prop and marker should be tagged or attributed so the plugin can delete only its own output later.

---

## Design Requirement: Deterministic Randomness

The same seed and same config should generate the same map.

Use:

```lua
local rng = Random.new(seed)
```

Do not use global `math.random` for generation.

All generated randomness should flow through a local deterministic RNG object or a deterministic hash function.

Good helper:

```lua
local function zoneSeed(baseSeed, zoneId, salt)
    return baseSeed * 1000003 + zoneId * 9176 + salt * 131
end
```

Use separate seed streams for:

- terrain height
- biome masks
- tree placement
- rock placement
- structure placement
- crystal anchor variation
- decorative variation

This prevents small changes to tree count from changing the whole terrain.

---

## Map Generation Pipeline

The plugin should generate in this order:

### Step One: Read Zone Config

Use current `ZoneConfig` as the gameplay truth for:

- zone origin
- zone bounds
- zone id
- zone display name
- crystal count
- unlock sequence

The generator should not invent gameplay zone sizes separately unless the goal is to update `ZoneConfig`.

Output:

```lua
type ZonePlan = {
    ZoneId: number,
    DisplayName: string,
    Origin: Vector3,
    BoundsCenter: Vector3,
    BoundsSize: Vector3,
    CrystalCount: number,
}
```

### Step Two: Build Macro Layout

Create visual continuity between zones.

The current zones are laid out mostly along the X axis. The map should read as one connected ritual path:

```text
Starter Zone -> Moon Ruins -> Rune Grounds -> Solar Grove -> Ascension Court
```

Generate:

- main path from zone one to zone five
- side paths inside each zone
- open combat arenas for crystals
- decorative landmarks
- safe spawn area
- unlock gate locations
- ascension statue location in zone five

The path should be flattened and visually clear.

### Step Three: Generate Height Map

For each terrain chunk, calculate height at X/Z.

Recommended formula:

```text
height =
  zoneBaseHeight
  + largeNoise * 10
  + mediumNoise * 4
  + detailNoise * 1.5
  - pathFlattening
  - arenaFlattening
```

Use different profiles by zone:

| Zone | Visual theme | Terrain shape |
|---|---|---|
| Zone One | Starter ritual field | gentle grass plateau |
| Zone Two | Moon ruins | colder, uneven stone, shallow craters |
| Zone Three | Rune grounds | angular ridges, rune platforms |
| Zone Four | Solar grove | warmer hills, trees, glowing clearings |
| Zone Five | Ascension court | high ritual platform, symmetrical ruins |

Do not make terrain too steep inside gameplay areas. The player needs to walk, pets need to read visually, crystals need to be reachable, and UI prompts need clear space.

### Step Four: Write Voxel Terrain

Use `Terrain:WriteVoxels(...)` in chunks.

Chunk size recommendation:

```text
64 x 64 studs in X/Z
height range from -32 to +96 studs
resolution 4
```

Each chunk writes:

- material array
- occupancy array

Occupancy idea:

```text
occupancy = 1 below ground surface
occupancy = fractional near surface
occupancy = 0 above ground
```

Material idea:

- grass/dirt for zone one
- slate/rock for zone two
- basalt/rock for zone three
- grass/leafy/ground for zone four
- marble/rock/sandstone feeling for zone five

Do not call `FillBlock` thousands of times to create every column. That is slower and harder to control. `FillBlock` is useful for small correction passes.

### Step Five: Carve/Flatten Gameplay Areas

After base terrain, enforce gameplay readability:

- flatten spawn area
- flatten crystal arenas
- flatten unlock wall areas
- flatten ascension statue area
- flatten main paths
- clear tiny obstacles near interactables

The generator can do this directly in height map before writing voxels. That is better than trying to flatten afterward.

### Step Six: Place Anchors

Place invisible or semi-transparent anchor markers for gameplay positions.

Anchor object recommendation:

```lua
local part = Instance.new("Part")
part.Name = "Crystal_1"
part.Anchored = true
part.CanCollide = false
part.Transparency = 1
part.Size = Vector3.new(2, 2, 2)
part:SetAttribute("AnchorType", "Crystal")
part:SetAttribute("ZoneId", zoneId)
part:SetAttribute("Index", crystalIndex)
```

Important:

Anchors are not gameplay by themselves. They are data for future gameplay code.

Current gameplay still creates crystals from runtime state. To make crystals match the authored map, Codex should later add optional support for generated anchor positions in `CrystalCombat` / zone derived state.

### Step Seven: Scatter Props

Use deterministic sampling.

Recommended placement algorithm:

1. Divide each zone into a grid.
2. For each cell, sample a random candidate point.
3. Reject if outside zone bounds.
4. Reject if too close to paths.
5. Reject if too close to crystals.
6. Reject if too close to spawn or interactables.
7. Raycast down to terrain.
8. Reject if slope too high.
9. Place a prop with deterministic rotation and scale.

This is simpler than full Bridson Poisson disk sampling but good enough for this game.

For more natural results, add density masks:

```text
treeDensity = noise(x, z, seed + treeSalt)
rockDensity = noise(x, z, seed + rockSalt)
ruinDensity = noise(x, z, seed + ruinSalt)
```

Then only place objects when density passes a threshold.

### Step Eight: Build Small Structures

Small objects should be simple anchored models, not voxel terrain.

Good structure types:

- trees
- stumps
- rocks
- rune stones
- broken pillars
- arches
- bridges
- fences
- ritual torches
- crystal clusters
- broken stairs
- small walls
- floating-looking objects are not allowed unless physically connected

Because the game already uses a ritual/crystal/pet visual language, make props chunky, readable, and stylized.

Every generated structure should be:

- anchored
- grouped as a Model
- placed with `PivotTo`
- tagged as generated
- attributed with zone id and prop type
- safe for deletion by plugin

---

## Zone Art Direction

### Zone One: Starter Zone

Goal: friendly, readable, open.

Terrain:

- grass
- dirt path
- small hills
- no extreme slopes

Props:

- small trees
- pebble clusters
- small ritual candles
- tiny rune stones
- low fences

Landmark:

- starter ritual circle near spawn

### Zone Two: Moon Ruins

Goal: colder, mysterious, slightly broken.

Terrain:

- rock
- slate
- darker ground
- shallow craters

Props:

- crescent stones
- broken pillars
- moon crystals
- old walls
- cold blue lights

Landmark:

- broken moon arch

### Zone Three: Rune Grounds

Goal: sharper, more magical, rune-heavy.

Terrain:

- stone
- darker ground
- angular plateaus

Props:

- rune tablets
- glyph stones
- square platforms
- embedded crystal lines
- short obelisks

Landmark:

- central rune platform

### Zone Four: Solar Grove

Goal: warm, richer, more alive.

Terrain:

- grass
- warm stone
- golden path accents
- slightly larger hills

Props:

- stylized trees
- sun totems
- yellow/orange crystal clusters
- bright ritual lamps
- broken sun discs

Landmark:

- solar grove altar

### Zone Five: Ascension Court

Goal: final first-world milestone.

Terrain:

- elevated court
- symmetrical ritual ground
- stone/marble feeling
- clean walkable platform

Props:

- tall pillars
- ritual stairs
- banners or slabs
- ascension statue
- large crystal clusters

Landmark:

- ascension court with statue

---

## Simple Structure Recipes

These can be generated as Parts and Models.

### Stylized Tree

```text
Model Tree
  Trunk: Cylinder or block, brown, anchored
  CanopyOne: Ball or blocky sphere, green
  CanopyTwo: Smaller ball, offset but touching
  Root stones: optional small blocks around trunk
```

Rules:

- canopy must touch trunk
- no floating leaves
- random scale per tree
- random rotation
- no collision or low collision for canopy

### Crystal Cluster

```text
Model CrystalCluster
  BaseRock: low rock block
  CrystalA: wedge or elongated part
  CrystalB: smaller attached wedge
  CrystalC: smaller attached wedge
```

Rules:

- every crystal touches base rock or another crystal
- no floating shards
- use zone color palette
- keep it decorative, not confused with attack crystals

### Broken Pillar

```text
Model BrokenPillar
  Base: square block
  ColumnLower: cylinder/block
  ColumnTop: tilted block, still touching lower part or ground
```

Rules:

- should look ancient
- collision can be on for base only
- avoid blocking paths

### Rune Stone

```text
Model RuneStone
  MainStone: vertical block
  RuneInset: tiny neon/bright part on front
  Base: small ground block
```

Rules:

- rune part must be attached visually to stone face
- rotate toward path or arena

---

## Collision Rules

Default:

- terrain collides
- big structures can collide
- small decorative props usually should not collide
- crystal arenas and paths must stay clean
- anchor markers should never collide

Recommended prop collision:

| Prop type | Collision |
|---|---|
| Large wall | true |
| Bridge | true |
| Pillar base | true |
| Tree trunk | optional true |
| Tree canopy | false |
| Small rocks | false |
| Crystal cluster | false |
| Rune tablets | false |
| Tiny grass/details | false |

---

## Map Validation Rules

The plugin should include a `Validate` button.

Validation should check:

- `Workspace/RitualMapGenerated` exists.
- Metadata exists.
- All five zone folders exist.
- Every zone has the required crystal anchors.
- Zone one has spawn anchor.
- Zones two to five have unlock wall anchors.
- Zone five has ascension statue anchor.
- Anchors are inside the configured zone bounds.
- Anchors are not too close to each other.
- Crystal anchors are not on steep slopes.
- Spawn is not inside terrain.
- Path width around spawn and crystals is clear.
- Generated part count is under budget.
- No generated prop has `Anchored = false`.
- No generated prop is outside allowed zone bounds unless explicitly allowed.
- `GeneratedBy` attributes exist on generated instances.

Output validation as a simple list:

```text
PASS: Zone 1 has 5 crystal anchors
PASS: Zone 5 has AscensionStatue anchor
WARN: Zone 3 has 92 decorative props, budget is 80
FAIL: Crystal_4 in Zone 2 is outside zone bounds
```

---

## Recommended Budgets

The map should look detailed but not stupidly heavy.

Initial budget:

| Category | Target |
|---|---:|
| Terrain resolution | 4 studs |
| Terrain chunk size | 64 x 64 studs |
| Props per zone | 40 to 80 |
| Structures per zone | 6 to 14 |
| Total generated part count | below 1,500 |
| Collidable decorative parts | below 250 |
| Crystal anchors per zone | 5 |
| Main path width | 10 to 16 studs |
| Crystal arena radius | 12 to 18 studs |

These are starting numbers. Studio profiling can adjust them.

---

## Integration With Existing Runtime

### Phase One: Visual Map Only

This is the safest first version.

Plugin generates:

- terrain
- static props
- paths
- landmarks
- invisible anchors
- debug markers

Runtime remains unchanged.

Benefits:

- fast to implement
- low risk
- no balancing changes
- no exploit risk
- no save-data risk

Downside:

- crystals may not perfectly match authored anchors yet

### Phase Two: Gameplay Anchor Support

Add optional gameplay use of generated anchors.

New config module:

```text
src/shared/Config/GeneratedMapAnchorConfig.luau
```

Example:

```lua
return {
    Zones = {
        [1] = {
            Spawn = Vector3.new(...),
            Crystals = {
                Vector3.new(...),
                Vector3.new(...),
                Vector3.new(...),
                Vector3.new(...),
                Vector3.new(...),
            },
        },
    },
}
```

Then update server crystal position generation:

- If anchor config exists for current zone and has enough crystal positions, use those positions.
- Otherwise fall back to existing random/in-bounds placement.

This keeps old behavior safe.

### Phase Three: Replace Local Unlock Wall / Ascension Statue Visuals

Currently unlock walls and ascension statue are client-local visuals. Later, authored map anchors can be used to place those visuals more naturally.

Do not do this in the first plugin pass unless needed.

---

## Clear / Regenerate Safety

The plugin must never delete random developer work.

Clear only:

- instances tagged `RitualMapGenerated`
- instances under `Workspace/RitualMapGenerated`
- terrain inside the plugin's recorded generated region, if the user confirms

Do not call `Workspace.Terrain:Clear()` by default.

Preferred terrain clearing:

- Store generated terrain bounds in metadata.
- Clear only that region with Air.
- Ask confirmation before clearing.

---

## Plugin UI Design

Dock widget layout:

```text
Ritual Map Generator

Seed: [ 123456 ]
Preset: [ Balanced v1 ]

[Generate All]
[Generate Terrain Only]
[Generate Props Only]
[Clear Generated Props]
[Clear Generated Terrain]
[Validate]
[Export Anchors]

Debug:
[ ] Show zone bounds
[ ] Show anchors
[ ] Show rejected prop points
[ ] Show path masks

Output:
- Generated Zone 1 terrain...
- Placed 57 props in Zone 1
- Warning: Zone 3 prop count high
```

Keep the first version ugly but functional. The plugin is a production tool, not player UI.

---

## Codex Implementation Plan

### Task One: Add Design Document

Create:

```text
docs/map_generation_plugin_design.md
```

Put this document there.

### Task Two: Add Pure Generator Modules

Create:

```text
src/shared/MapGen/SeededRandom.luau
src/shared/MapGen/Noise.luau
src/shared/MapGen/MapGenConfig.luau
src/shared/MapGen/ZoneLayout.luau
```

Implement deterministic helpers first.

Acceptance criteria:

- same seed returns same zone plan
- different seed changes decoration placement but not gameplay zone ids
- no plugin API dependency in these modules

### Task Three: Add Plugin Entry

Create:

```text
plugins/RitualMapGenerator.plugin.luau
```

The plugin should:

- create toolbar button
- create dock widget
- have seed input
- have generate/clear/validate buttons
- call shared generator modules

Codex should research the repo's preferred plugin workflow. If Rojo can map plugin files directly, use that. If not, keep the plugin as a standalone Studio plugin script.

### Task Four: Terrain Writer

Create:

```text
src/shared/MapGen/TerrainWriter.luau
```

Implement chunked `WriteVoxels`.

Acceptance criteria:

- generates terrain only inside zone area plus margin
- yields between chunks so Studio does not freeze
- writes grass/rock/material variation
- does not create thousands of terrain column parts

### Task Five: Path And Arena Masks

Create:

```text
src/shared/MapGen/PathGenerator.luau
```

It should output mask functions:

```lua
isOnMainPath(x, z): boolean
distanceToMainPath(x, z): number
isInCrystalArena(x, z): boolean
isInSpawnArea(x, z): boolean
```

Use those masks to flatten terrain and reject props.

### Task Six: Props And Structures

Create:

```text
src/shared/MapGen/PropCatalog.luau
src/shared/MapGen/PropScatterer.luau
src/shared/MapGen/StructureFactory.luau
```

Start with generated simple part structures. Do not depend on imported meshes yet.

Initial prop types:

- tree
- rock cluster
- rune stone
- broken pillar
- crystal cluster
- ritual lamp

Acceptance criteria:

- deterministic placement
- no props inside crystal arenas
- no props on main path
- no unanchored generated parts
- generated models have attributes and tags

### Task Seven: Anchors

Create:

```text
src/shared/MapGen/AnchorExporter.luau
```

Generate invisible anchors inside the plugin folder.

Add optional export to a Luau config text block or file-like ModuleScript:

```text
ReplicatedStorage/Shared/Config/GeneratedMapAnchorConfig
```

In Rojo source terms, Codex may need to create:

```text
src/shared/Config/GeneratedMapAnchorConfig.luau
```

But because a Studio plugin cannot directly write to the local file system in normal Roblox Studio, the plugin should first create a ModuleScript instance in Studio. The developer can copy it into source or Codex can add the generated config manually later.

### Task Eight: Validator

Create:

```text
src/shared/MapGen/MapValidator.luau
```

Validator returns structured results:

```lua
type ValidationResult = {
    Severity: "Pass" | "Warn" | "Fail",
    Code: string,
    Message: string,
    ZoneId: number?,
}
```

Plugin UI prints these results.

### Task Nine: Optional Runtime Anchor Support

Only after visual generation works:

- Add `GeneratedMapAnchorConfig`.
- Update `CrystalCombat` to prefer configured anchors for crystal positions.
- Keep fallback to old random in-bounds generation.
- Add manual validation checklist.

Do not change rewards, pet damage, profile data, or economy.

---

## Suggested Codex Prompt

Use this prompt with Codex:

```text
We need to implement an authoring-time Roblox Studio map generation plugin for Ritual Core.

Read the current source first, especially:
- src/server/Systems/World/WorldService.luau
- src/client/Systems/World/WorldController.luau
- src/shared/Config/ZoneConfig.luau
- src/server/Systems/Ritual/CrystalCombat.luau
- default.project.json

Do not implement runtime procedural map generation.
Do not change progression, rewards, profiles, pet rolling, or economy.

Goal:
Create a Studio plugin that generates a deterministic seed-based map:
- smooth voxel terrain in Workspace.Terrain
- static generated props under Workspace/RitualMapGenerated
- anchors for spawn, crystals, unlock walls, and ascension statue
- validation report
- clear/regenerate safety

Use Roblox Terrain WriteVoxels for base terrain.
Use simple anchored Models/Parts for trees, rocks, rune stones, pillars, lamps, and crystal clusters.
Use Random.new(seed) and math.noise for deterministic procedural variation.
Use attributes and CollectionService tags on generated instances.

First phase should be visual map only.
Second phase can optionally export GeneratedMapAnchorConfig and make CrystalCombat use anchor positions with fallback to current behavior.

Implement in small steps:
1. Add docs/map_generation_plugin_design.md.
2. Add pure modules under src/shared/MapGen.
3. Add plugins/RitualMapGenerator.plugin.luau with toolbar and dock widget.
4. Implement terrain generation.
5. Implement prop generation.
6. Implement anchors.
7. Implement validator.
8. Only then consider optional runtime anchor support.
```

---

## First Version Acceptance Criteria

The first working plugin is done when:

- A Studio toolbar button opens the generator widget.
- User can enter a seed.
- User can click Generate All.
- Terrain appears for all five zones.
- Each zone has a distinct visual theme.
- Main path connects all zones.
- Five crystal anchor markers exist per zone.
- Zone one has a spawn anchor.
- Zones two to five have unlock wall anchors.
- Zone five has ascension statue anchor.
- Props are generated and anchored.
- First version uses Roblox primitives / project-owned generated models only.
- No third-party asset pack is required.
- Plugin can clear its own generated props.
- Plugin does not delete unrelated developer work.
- Validate shows pass/warn/fail output.
- Re-running with the same seed gives the same map.
- Re-running with a different seed gives a different decoration layout.
- Gameplay still works exactly as before.

---

## Main Risks

### Risk: Terrain generation freezes Studio

Mitigation:

- generate in chunks
- yield between chunks
- show progress
- avoid per-stud parts

### Risk: Generated map conflicts with runtime generated world

Mitigation:

- do not use `Workspace/GeneratedRitualWorld`
- use `Workspace/RitualMapGenerated`
- do not touch `WorldService` initially

### Risk: Crystals spawn in ugly places

Mitigation:

- first reserve arenas visually
- later add generated anchor config support

### Risk: Plugin deletes hand-made work

Mitigation:

- only delete tagged/generated instances
- confirm before terrain clearing
- never call full terrain clear by default

### Risk: Too much object detail

Mitigation:

- prop budgets
- validator warnings
- non-colliding small details
- simple models


### Risk: Bad or unsafe third-party assets enter the project

Mitigation:

- do not use third-party packs in the generator baseline
- build simple primitive-based props first
- use only Roblox built-in materials and project-owned assets
- manually review any custom asset before adding it to the generator catalog
- reject imported models with scripts, excessive part counts, bad collision, or unclear licensing



---

## Appendix: `potential_trees.ts`

This is reference code for procedural tree generation. It is intentionally written as TypeScript-style algorithm code because it is easy to reason about and can be translated to Luau or roblox-ts later.

If the project stays pure Luau, Codex should port the same ideas into:

```text
src/shared/MapGen/TreeFactory.luau
```

The important ideas are:

- deterministic seed input
- no third-party assets
- every visual piece physically touches the tree body
- simple generated primitives only
- output is a tree specification that another Roblox-specific writer can turn into Parts

```ts
// potential_trees.ts
// Reference algorithm for Ritual Core procedural trees.
// This is not required runtime code. Port to Luau if the project is not using roblox-ts.

export type Vec3 = {
  x: number;
  y: number;
  z: number;
};

export type TreePartShape =
  | "block"
  | "sphere"
  | "cylinder"
  | "wedge";

export type TreePartSpec = {
  name: string;
  shape: TreePartShape;
  localPosition: Vec3;
  size: Vec3;
  rotationYDegrees: number;
  material: "wood" | "leaf" | "stone" | "crystal" | "rune";
  colorHint: string;
  canCollide: boolean;
};

export type TreeSpec = {
  id: string;
  zoneId: number;
  position: Vec3;
  yawDegrees: number;
  scale: number;
  variant: "starter_oak" | "moon_birch" | "rune_tree" | "solar_tree" | "ascension_cypress";
  parts: TreePartSpec[];
};

export class SeededRandom {
  private state: number;

  constructor(seed: number) {
    this.state = seed >>> 0;
    if (this.state === 0) this.state = 0x12345678;
  }

  next01(): number {
    // Mulberry32-style deterministic RNG.
    this.state += 0x6D2B79F5;
    let t = this.state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }

  range(min: number, max: number): number {
    return min + (max - min) * this.next01();
  }

  integer(min: number, maxInclusive: number): number {
    return Math.floor(this.range(min, maxInclusive + 1));
  }

  pick<T>(items: T[]): T {
    return items[Math.floor(this.next01() * items.length)];
  }
}

function v(x: number, y: number, z: number): Vec3 {
  return { x, y, z };
}

function part(
  name: string,
  shape: TreePartShape,
  localPosition: Vec3,
  size: Vec3,
  material: TreePartSpec["material"],
  colorHint: string,
  canCollide = false,
  rotationYDegrees = 0,
): TreePartSpec {
  return {
    name,
    shape,
    localPosition,
    size,
    material,
    colorHint,
    canCollide,
    rotationYDegrees,
  };
}

export function makeTreeSpec(params: {
  seed: number;
  zoneId: number;
  index: number;
  position: Vec3;
}): TreeSpec {
  const rng = new SeededRandom(params.seed + params.zoneId * 9176 + params.index * 131);
  const scale = rng.range(0.85, 1.25);
  const yaw = rng.range(0, 360);

  const variantByZone: Record<number, TreeSpec["variant"]> = {
    1: "starter_oak",
    2: "moon_birch",
    3: "rune_tree",
    4: "solar_tree",
    5: "ascension_cypress",
  };

  const variant = variantByZone[params.zoneId] ?? "starter_oak";
  const parts: TreePartSpec[] = [];

  if (variant === "starter_oak") {
    parts.push(part("Trunk", "cylinder", v(0, 3, 0), v(1.2, 6, 1.2), "wood", "warm_brown", true));
    parts.push(part("Canopy_Lower", "sphere", v(0, 6.4, 0), v(5.6, 4.2, 5.6), "leaf", "starter_green"));
    parts.push(part("Canopy_Upper", "sphere", v(0.2, 8.5, -0.1), v(4.2, 3.4, 4.2), "leaf", "starter_green_light"));
    parts.push(part("RootRock_A", "block", v(0.9, 0.35, 0.35), v(1.2, 0.7, 0.9), "stone", "soft_gray"));
  }

  if (variant === "moon_birch") {
    parts.push(part("Trunk", "cylinder", v(0, 3.4, 0), v(0.9, 6.8, 0.9), "wood", "pale_moon_bark", true));
    parts.push(part("Canopy_Main", "sphere", v(0, 7.1, 0), v(4.8, 3.8, 4.8), "leaf", "blue_gray_leaf"));
    parts.push(part("Canopy_Side", "sphere", v(1.2, 6.5, 0.2), v(3.0, 2.8, 3.0), "leaf", "blue_gray_leaf_dark"));
    parts.push(part("MoonRune", "block", v(0, 3.8, -0.48), v(0.18, 0.7, 0.08), "rune", "cold_blue_neon"));
  }

  if (variant === "rune_tree") {
    parts.push(part("Trunk", "block", v(0, 3.2, 0), v(1.4, 6.4, 1.4), "wood", "dark_bark", true));
    parts.push(part("Canopy_Block_A", "block", v(0, 6.7, 0), v(5.2, 2.8, 5.2), "leaf", "deep_teal"));
    parts.push(part("Canopy_Block_B", "block", v(-0.8, 8.0, 0.5), v(3.8, 2.4, 3.8), "leaf", "deep_teal_light"));
    parts.push(part("RuneInset_A", "block", v(0, 4.1, -0.74), v(0.2, 1.0, 0.08), "rune", "violet_neon"));
    parts.push(part("RuneInset_B", "block", v(0, 2.6, -0.74), v(0.2, 0.8, 0.08), "rune", "violet_neon"));
  }

  if (variant === "solar_tree") {
    parts.push(part("Trunk", "cylinder", v(0, 3.5, 0), v(1.3, 7.0, 1.3), "wood", "golden_brown", true));
    parts.push(part("Canopy_Main", "sphere", v(0, 7.0, 0), v(5.8, 3.8, 5.8), "leaf", "sunlit_green"));
    parts.push(part("Canopy_Top", "sphere", v(0.1, 9.1, 0.1), v(4.4, 3.0, 4.4), "leaf", "warm_yellow_green"));
    parts.push(part("SunBand", "block", v(0, 4.2, -0.66), v(0.9, 0.22, 0.08), "rune", "gold_neon"));
  }

  if (variant === "ascension_cypress") {
    parts.push(part("Trunk", "cylinder", v(0, 4.2, 0), v(1.0, 8.4, 1.0), "wood", "ancient_dark", true));
    parts.push(part("Canopy_Lower", "sphere", v(0, 6.2, 0), v(3.8, 3.4, 3.8), "leaf", "ascension_blue_green"));
    parts.push(part("Canopy_Mid", "sphere", v(0, 8.4, 0), v(3.0, 3.2, 3.0), "leaf", "ascension_blue_green_light"));
    parts.push(part("Canopy_Top", "sphere", v(0, 10.4, 0), v(2.2, 2.8, 2.2), "leaf", "pale_ritual_green"));
    parts.push(part("BaseStone", "block", v(0, 0.25, 0), v(2.2, 0.5, 2.2), "stone", "marble_gray", true));
  }

  // Small per-tree variation. Keep pieces touching the body.
  const extraRoots = rng.integer(0, 2);
  for (let i = 0; i < extraRoots; i++) {
    const angle = rng.range(0, Math.PI * 2);
    const radius = rng.range(0.65, 1.05);
    parts.push(
      part(
        `Root_${i + 1}`,
        "block",
        v(Math.cos(angle) * radius, 0.25, Math.sin(angle) * radius),
        v(rng.range(0.7, 1.3), 0.5, rng.range(0.35, 0.7)),
        "wood",
        "root_brown",
        false,
        (angle * 180) / Math.PI,
      ),
    );
  }

  return {
    id: `zone_${params.zoneId}_tree_${params.index}`,
    zoneId: params.zoneId,
    position: params.position,
    yawDegrees: yaw,
    scale,
    variant,
    parts,
  };
}

export function makeTreeBatch(params: {
  seed: number;
  zoneId: number;
  positions: Vec3[];
}): TreeSpec[] {
  return params.positions.map((position, index) =>
    makeTreeSpec({
      seed: params.seed,
      zoneId: params.zoneId,
      index: index + 1,
      position,
    }),
  );
}
```

### Luau Porting Notes

When Codex ports this to Luau:

- Replace TypeScript types with Luau table types if desired.
- Replace `SeededRandom` with Roblox `Random.new(seed)` unless an exact portable RNG is needed.
- Convert `TreePartSpec` records into actual Roblox `Part` instances.
- Use `Model:PivotTo(...)` to place the final tree model.
- Set `Anchored = true` on every generated part.
- Use `CollectionService:AddTag(model, "RitualMapGenerated")`.
- Add attributes such as `ZoneId`, `GeneratedBy`, `Seed`, `PropType`, and `TreeVariant`.
- Keep all tree pieces visually connected. Do not generate floating leaves, orbiting stones, or disconnected magical shards.

Example target Luau module name:

```text
src/shared/MapGen/TreeFactory.luau
```

Example target API:

```lua
local TreeFactory = {}

function TreeFactory.createTreeModel(treeSpec)
    -- creates a Model from a tree spec
end

function TreeFactory.generateTreeSpec(seed, zoneId, index, position)
    -- returns a deterministic tree spec table
end

return TreeFactory
```


---

## Final Recommendation

The best path is:

1. Implement the plugin as an offline Studio tool.
2. Generate Roblox voxel terrain for the landmass.
3. Generate simple part/model structures for small details.
4. Keep gameplay systems server-owned and unchanged.
5. Add anchor export later so crystals and interactables can align perfectly with the authored map.

This gives the project a real map without risking the already implemented balancing and progression systems.
