# Ritual Map Generator Plugin

`map.md` is now historical reference only. The active implementation target is a
sectioned, block-built simulator map, not a smooth voxel terrain map.

The current implementation is an authoring-time Roblox Studio plugin. It
generates visual map content only:

- flat stage sections from anchored Parts
- one studded floor block per section with a small number of accent plates
- blocky cliff walls plus taller red visible walls with green caps/drips
- gate openings and bridges between adjacent stages
- taller invisible collision walls around each section, with matching openings
  between adjacent stages
- translucent stage gate visuals between sections; runtime unlock walls still own
  actual locked/unlocked collision
- simple block props, pads, labels, debug markers, metadata, and anchors under
  `Workspace/RitualMapGenerated`
- deterministic output from a numeric seed and preset
- capped stylized block trees with bent trunks, forked branches, cube-cluster
  canopies, grass clumps, rocks, and stage pads
- shared gameplay layout from `ZoneConfig`: larger zone bounds, one teleport
  arrival point per zone, a real player spawn only in Zone 1, and a central
  crystal area used by both runtime crystal placement and generated visual
  anchors
- deterministic prop distribution: trees stay outside the crystal area, while
  smaller rocks and grass can appear inside it
- validation and anchor export tooling

The plugin intentionally does not generate into `Workspace/GeneratedRitualWorld`.
That old runtime test-map folder is deleted on server startup if it exists and
is no longer recreated.

The active preset is:

```text
Block Sections v1
```

The first phase also does not change crystal combat, progression, rewards,
profiles, economy, purchases, pets, or runtime zone unlock behavior. Generated
anchors are data for later integration.

Source layout:

```text
plugins/RitualMapGenerator.plugin.luau
src/shared/MapGen/
```

The plugin is currently standalone because this project does not map a plugin
folder in `default.project.json`. The shared generator modules are mapped through
`ReplicatedStorage/Shared/MapGen` by the existing Rojo project.
